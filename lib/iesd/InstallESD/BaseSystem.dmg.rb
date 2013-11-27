module IESD
  class DMG
    class BaseSystem < HDIUtil::DMG
      PACKAGES = %w{ System Installation Packages }

      def export options, add_sectors = 0
        Dir.mktmpdir { |tmp|
          HDIUtil.write(@url, (tmpfile = File.join(tmp, File.basename(@url))), add_sectors) { |volume_root|
            options[:extensions][:up_to_date] = (options[:extensions][:remove].empty? and options[:extensions][:install].empty?)

            yield volume_root if block_given?

            pre_update volume_root, options

            IESD::DMG::BaseSystem::Extensions.new(volume_root).update options[:extensions]

            post_update volume_root, options
          }
          system(Utility::MV, tmpfile, options[:output])
        }
      end

      private

      def pre_update volume_root, options
        if !File.exist? (mach_kernel = File.join(volume_root, "mach_kernel")) and (options[:mach_kernel] or !options[:extensions][:up_to_date])
          IESD::Packages::BaseSystemBinaries.new(File.join(volume_root, *PACKAGES, "BaseSystemBinaries.pkg")).extract_mach_kernel mach_kernel
          system(Utility::CHFLAGS, "hidden", mach_kernel)
        end
      end

      def post_update volume_root, options
        if !options[:extensions][:up_to_date] and options[:extensions][:postinstall]
          IESD::Packages::OSInstall.new(File.join(volume_root, *PACKAGES, "OSInstall.pkg")).postinstall_extensions options[:extensions]
        end
        if options[:mach_kernel] === false and File.exist? (mach_kernel = File.join(volume_root, "mach_kernel"))
          system(Utility::RM, mach_kernel)
        end
      end

      class Extensions < IESD::Extensions
        def update extensions
          remove extensions[:remove]
          install extensions[:install]
          @kextcache.update if extensions[:kextcache] or (extensions[:kextcache].nil? and !extensions[:up_to_date])
        end
      end
    end
  end
end
