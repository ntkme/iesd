require "tmpdir"
require_relative "tty"

# +/usr/sbin/pkgutil+
#
# https://developer.apple.com/library/mac/documentation/Darwin/Reference/Manpages/man1/pkgutil.1.html
module PKGUtil

  # Perform read-only actions on the input package.
  #
  # If a block is given the block will be yielded with the path of the package expanded directory, otherwise a shell will be open.
  #
  # input - The String path to the input package.
  def self.read input
    Dir.mktmpdir { |tmp|
      tmp = File.join tmp, File.basename(input)
      expand input, tmp
      if block_given?
        yield tmp
      else
        shell tmp
      end
    }
  end

  # Perform read-write actions on the input package and export as the output package.
  #
  # If a block is given the block will be yielded with the path of the package expanded directory, otherwise a shell will be open.
  #
  # input  - The String path to the input package.
  # output - The String path to the output package.
  def self.write input, output = input
    Dir.mktmpdir { |tmp|
      tmp = File.join tmp, File.basename(input)
      expand input, tmp
      if block_given?
        yield tmp
      else
        shell tmp
      end
      flatten tmp, output
    }
  end

  private

  # Expand a PKG.
  #
  # pkg - The String path to the PKG.
  # dir - The String path to the expand directory.
  def self.expand pkg, dir
    ohai "Expanding #{pkg}"
    system("/usr/bin/env", "pkgutil", "--expand", pkg, dir)
    puts "Expanded: #{dir}"
  end

  # Flatten a PKG.
  #
  # dir - The String path to the flatten directory.
  # pkg - The String path to the PKG.
  def self.flatten dir, pkg
    ohai "Flattening #{dir}"
    system("/usr/bin/env", "pkgutil", "--flatten", dir, pkg)
    puts "Flattened: #{pkg}"
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

module PKGUtil # :nodoc:
  class PKG # :nodoc:

    # The String path to the PKG.
    attr_accessor :url

    # Initialize a new PKG.
    #
    # url - The String path to the PKG.
    def initialize url
      @url = File.absolute_path url
    end

    # Perform read-only actions on the PKG.
    def show &block
      PKGUtil.read(@url, &block)
    end

    # Open a read-write shell in the PKG.
    def edit
      update
    end

    # Perform read-write actions on the PKG.
    def update &block
      PKGUtil.write(@url, &block)
    end
  end
end
