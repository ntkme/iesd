require_relative "tty"

# +/usr/sbin/kextcache+
#
# https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/kextcache.8.html
module KextCache

  # The default options for kextcache.
  DEFAULT_OPTIONS = %w[ -v 0 -no-authentication ]

  # The relative path to kernel.
  #
  # Available on OS X Yosemite and later.
  KERNEL = File.join %w[ System Library Kernels kernel ]

  # The relative path to mach_kernel.
  #
  # Available on OS X Mavericks and earlier.
  MACH_KERNEL = File.join %w[ mach_kernel ]

  # The relative path to Extensions.
  EXTENSIONS = File.join %w[ System Library Extensions ]

  # The relative path to Extra Extensions.
  #
  # Available on OS X Mavericks and later.
  EXTRA_EXTENSIONS = File.join %w[ Library Extensions ]

  # The relative path to kernelcache.
  #
  # Available on OS X Lion and later.
  KERNELCACHE = File.join %w[ System Library Caches com.apple.kext.caches Startup kernelcache ]

  # The relative path to Extensions.mkext.
  #
  # Available on OS X Snow Leopard.
  MKEXT = File.join %w[ System Library Caches com.apple.kext.caches Startup Extensions.mkext ]

  # The relative path to Extensions.mkext on PowerPC Macs.
  #
  # Available on OS X Leopard and eailer.
  MKEXT_PPC = File.join %w[ System Library Extensions.mkext ]

  # Update the kernelcache on a volume.
  #
  # volume_root - The String path to the volume root.
  def self.update_volume volume_root
    oh1 "Updating Kextcache"
    if File.exist? (mach_kernel = File.join(volume_root, KERNEL)) or File.exist? (mach_kernel = File.join(volume_root, MACH_KERNEL))
      extensions_path = [File.join(volume_root, EXTENSIONS)]
      extensions_path.push(File.join(volume_root, EXTRA_EXTENSIONS)) if File.exist? File.join(volume_root, EXTRA_EXTENSIONS)
      case
      when (File.exist? (url = File.join(volume_root, KERNELCACHE)))
        system("/usr/bin/env", "kextcache", *DEFAULT_OPTIONS, "-prelinked-kernel", url, "-kernel", mach_kernel, "-volume-root", volume_root, "--", *extensions_path)
      when (File.exist? (url = File.join(volume_root, MKEXT)))
        system("/usr/bin/env", "kextcache", *DEFAULT_OPTIONS, *%w[ -a i386 -a x86_64 ], "-mkext", url, "-kernel", mach_kernel, "-volume-root", volume_root, "--", *extensions_path)
        if File.exist? (mkext_ppc = File.join(volume_root, MKEXT_PPC))
          system("/usr/bin/env", "ditto", url, mkext_ppc)
        end
      when (File.exist? (url = File.join(volume_root, MKEXT_PPC)))
        system("/usr/bin/env", "kextcache", *DEFAULT_OPTIONS, *%w[ -a ppc -a i386 ], "-mkext", url, "-kernel", mach_kernel, "-volume-root", volume_root, "--", *extensions_path)
      else
        puts "kextcache aborted: unknown kernel cache type"
        return
      end
      puts "Updated: #{url}"
    else
      opoo "kextcache aborted: mach_kernel not found"
    end
  end
end
