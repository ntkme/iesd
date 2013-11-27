module IESD
  class Extensions
    EXTENSIONS = %w{ System Library Extensions }

    attr_reader :volume_root, :url, :kextcache

    def initialize volume_root
      @volume_root = volume_root
      @url = File.join @volume_root, *EXTENSIONS
      @kextcache = IESD::Extensions::KextCache.new self
    end

    def remove kexts
      if !kexts.empty?
        oh1 "Removing Extensions"
        kexts.each { |kext|
          system(Utility::RM, "-rf", File.join(@url, kext))
          puts "Removed: #{File.join(@url, kext)}"
        }
      end
    end

    def install kexts
      if !kexts.empty?
        oh1 "Installing Extensions"
        kexts.each { |kext|
          system(Utility::DITTO, kext, File.join(@url, File.basename(kext)))
          puts "Installed: #{File.join(@url, File.basename(kext))}"
        }
      end
    end

    class KextCache
      KEXTCACHE_DEFAULT_OPTIONS = %w{ -v 0 -no-authentication }
      KERNELCACHE = %w{ System Library Caches com.apple.kext.caches Startup kernelcache }
      MKEXT = %w{ System Library Caches com.apple.kext.caches Startup Extensions.mkext }
      MKEXT_PPC = %w{ System Library Extensions.mkext }

      attr_reader :volume_root, :url, :type

      def initialize extensions
        @extensions = extensions
        @volume_root = extensions.volume_root

        case
        when (File.exist? (@url = File.join(@volume_root, *KERNELCACHE)))
          @type = :kernelcache
        when (File.exist? (@url = File.join(@volume_root, *MKEXT)))
          @type = :mkext
        when (File.exist? (@url = File.join(@volume_root, *MKEXT_PPC)))
          @type = :mkext_ppc
        else
          @url = nil
        end
      end

      def update
        if File.exist? (mach_kernel = File.join(@volume_root, "mach_kernel"))
          oh1 "Updating Kextcache"
          case @type
          when :kernelcache
            system(Utility::KEXTCACHE, *KEXTCACHE_DEFAULT_OPTIONS, "-prelinked-kernel", @url, "-kernel", mach_kernel, "-volume-root", @volume_root, "--", @extensions.url)
          when :mkext
            system(Utility::KEXTCACHE, *KEXTCACHE_DEFAULT_OPTIONS, *%w{ -a i386 -a x86_64 }, "-mkext", @url, "-kernel", mach_kernel, "-volume-root", @volume_root, "--", @extensions.url)
            if File.exist? (mkext_ppc = File.join(@volume_root, *MKEXT_PPC))
              system(Utility::DITTO, @url, mkext_ppc)
            end
          when :mkext_ppc
            system(Utility::DITTO, *KEXTCACHE_DEFAULT_OPTIONS, *%w{ -a ppc -a i386 }, "-mkext", @url, "-kernel", mach_kernel, "-volume-root", @volume_root, "--", extensions.url)
          end
          puts "Updated: #{@url}"
        else
          opoo "kextcache aborted because mach_kernel is not available"
        end
      end
    end
  end
end
