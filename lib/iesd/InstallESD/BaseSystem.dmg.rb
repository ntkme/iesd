module IESD
  class DMG
    class BaseSystem < HDIUtil::DMG
      PACKAGES = %w{ System Installation Packages }

      def export options
        case options[:type]
        when :BaseSystem, nil
          Dir.mktmpdir { |tmp|
            HDIUtil.write(@url, (tmpfile = File.join(tmp, File.basename(@url))), options[:hdiutil]) { |volume_root|
              options[:extensions][:up_to_date] = (options[:extensions][:uninstall].empty? and options[:extensions][:install].empty?)
              options[:mach_kernel] = File.exist? File.join(volume_root, "mach_kernel") if options[:mach_kernel].nil?

              yield volume_root if block_given?

              pre_update_extension volume_root, options

              IESD::DMG::BaseSystem::Extensions.new(volume_root).update options[:extensions]

              post_update_extension volume_root, options

              if options[:interactive]
                oh1 "Starting Interactive Shell"
                puts "Environment: BaseSystem"
                HDIUtil.shell volume_root
              end
            }
            system("/usr/bin/env", "mv", tmpfile, options[:output])
          }
        else
          raise "invalid output type"
        end
      end

      private

      def pre_update_extension volume_root, options
        if !File.exist? (mach_kernel = File.join(volume_root, "mach_kernel")) and (options[:mach_kernel] or !options[:extensions][:up_to_date])
          IESD::Packages::BaseSystemBinaries.new(File.join(volume_root, *PACKAGES, "BaseSystemBinaries.pkg")).extract_mach_kernel mach_kernel
          system("/usr/bin/env", "chflags", "hidden", mach_kernel)
        end
      end

      def post_update_extension volume_root, options
        if !options[:extensions][:up_to_date] and options[:extensions][:postinstall]
          IESD::Packages::OSInstall.new(File.join(volume_root, *PACKAGES, "OSInstall.pkg")).postinstall_extensions options[:extensions]
        end
        if !options[:mach_kernel] and File.exist? (mach_kernel = File.join(volume_root, "mach_kernel"))
          system("/usr/bin/env", "rm", mach_kernel)
        end
      end

      class Extensions < IESD::Extensions
        def update extensions
          uninstall extensions[:uninstall]
          install extensions[:install]
          KextCache.update_volume @volume_root if extensions[:kextcache] or (extensions[:kextcache].nil? and !extensions[:up_to_date])
        end
      end
    end
  end
end
