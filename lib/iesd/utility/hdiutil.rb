require "shellwords"
require "tmpdir"
require_relative "tty"

# +/usr/bin/hdiutil+
#
# https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/hdiutil.1.html
module HDIUtil

  # The default options for +hdiutil+.
  DEFAULT_OPTIONS = %w[ -quiet ]

  # The default options for <code>hdiutil attach</code>.
  DEFAULT_MOUNT_OPTIONS = %w[ -nobrowse -noverify ]
  DEFAULT_MOUNT_OPTIONS.concat(%w[ -owners on ]) if Process.uid == 0

  # Perform read-only actions on the input image.
  #
  # If a block is given the block will be yielded with the path of the mount point directory, otherwise a shell will be open.
  #
  # input - The String path to the input image.
  def self.read input
    Dir.mktmpdir { |mountpoint|
      attach input, mountpoint, [*DEFAULT_OPTIONS, *DEFAULT_MOUNT_OPTIONS]
      if block_given?
        yield mountpoint
      else
        shell mountpoint
      end
      detach input, mountpoint, [*DEFAULT_OPTIONS]
    }
  end

  # Perform read-write actions on the input image and export as the output image.
  #
  # If a block is given the block will be yielded with the path of the mount point directory, otherwise a shell will be open.
  #
  # input   - The String path to the input image.
  # output  - The String path to the output image.
  # options - The Dictionary of hdiutil options.
  def self.write input, output, options = {}
    options = {
      :resize => {
        :grow => 0,
        :shrink => false
      }
    }.merge(options)

    Dir.mktmpdir { |tmp|
      shadow = File.join(tmp, "#{File.basename input}.shadow")
      shadow_options = ["-shadow", shadow]
      format_options = ["-format", `/usr/bin/env hdiutil imageinfo -format #{input.shellescape}`.chomp]
      Dir.mktmpdir(nil, tmp) { |mountpoint|
        resize_limits = `/usr/bin/env hdiutil resize -limits -shadow #{shadow.shellescape} #{input.shellescape}`.chomp.split.map { |s| s.to_i }
        sectors = (resize_limits[1] + options[:resize][:grow]).to_s
        system("/usr/bin/env", "hdiutil", "resize", "-growonly", "-sectors", sectors, *shadow_options, input)
        attach input, mountpoint, [*DEFAULT_OPTIONS, *DEFAULT_MOUNT_OPTIONS, *shadow_options]
        if block_given?
          yield mountpoint
        else
          shell mountpoint
        end
        detach input, mountpoint, [*DEFAULT_OPTIONS]
        system("/usr/bin/env", "hdiutil", "resize", "-shrinkonly", "-sectors", "min", *shadow_options, input) if options[:resize][:shrink]
      }
      oh1 "Merging #{shadow}"
      system("/usr/bin/env", "hdiutil", "convert", *DEFAULT_OPTIONS, *format_options, *shadow_options, "-o", output, input)
      puts "Merged: #{output}"
    }
  end

  # Returns true if the image is valid, false otherwise.
  #
  # url - The String path to the image.
  def self.validate url
    Kernel.system(%Q[/usr/bin/env hdiutil imageinfo #{url.shellescape} >/dev/null 2>&1])
  end

  private

  # Mount a DMG.
  #
  # dmg        - The String path to the DMG.
  # mountpoint - The String path to the mount directory.
  # arguments  - The Array of the hdiutil attach options.
  def self.attach dmg, mountpoint, arguments = []
    ohai "Mounting #{dmg}"
    system("/usr/bin/env", "hdiutil", "attach", *arguments, "-mountpoint", mountpoint, dmg)
    puts "Mounted: #{mountpoint}"
  end

  # Unmount a DMG.
  #
  # dmg        - The String path to the DMG.
  # mountpoint - The String path to the unmount directory.
  # arguments  - The Array of the hdiutil detach options.
  def self.detach dmg, mountpoint, arguments = []
    ohai "Unmounting #{dmg}"
    system("/usr/bin/env", "hdiutil", "detach", *arguments, mountpoint)
    puts "Unmounted: #{mountpoint}"
  end

  # Open a shell in the directory.
  #
  # dir - The String path to the directory.
  def self.shell dir
    Dir.chdir(dir) {
      ohai ENV['SHELL']
      Kernel.system ENV, ENV['SHELL']
    }
  end
end

module HDIUtil # :nodoc:
  class DMG # :nodoc:

    # The String path to the DMG.
    attr_accessor :url

    # Initialize a new DMG.
    #
    # url - The String path to the DMG.
    def initialize url
      @url = File.absolute_path url
    end

    # Perform read-only actions on the DMG.
    def show &block
      HDIUtil.read(@url, &block)
    end

    # Open a read-write shell in the DMG.
    def edit
      update
    end

    # Perform read-write actions on the DMG.
    def update &block
      Dir.mktmpdir { |tmp|
        flags = `/usr/bin/env ls -lO #{@url.shellescape}`.split[4]
        HDIUtil.write(@url, (tmpfile = File.join(tmp, File.basename(@url))), &block)
        system("/usr/bin/env", "mv", tmpfile, @url)
        system("/usr/bin/env", "chflags", flags, @url) unless flags == "-"
      }
    end

    # Returns true if the DMG is a valid image, false otherwise.
    def valid?
      HDIUtil.validate @url
    end
  end
end
