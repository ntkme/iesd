module IESD
  class DMG
    class InstallESD < HDIUtil::DMG
      PACKAGES = %w{ Packages }

      def export options
        case options[:type]
        when :root
          resize_limits = `#{Utility::HDIUTIL} resize -limits "#{@url}"`.chomp.split.map { |s| s.to_i }
          show { |installesd|
            IESD::DMG::BaseSystem.new(File.join(installesd, "BaseSystem.dmg")).export(options, resize_limits[0]) { |basesystem|
              installesd_packages = File.join installesd, PACKAGES
              basesystem_packages = File.join basesystem, *IESD::DMG::BaseSystem::PACKAGES
              oh1 "Copying #{installesd_packages}"
              system(Utility::RM, basesystem_packages)
              system(Utility::DITTO, installesd_packages, basesystem_packages)
              puts "Copied: #{basesystem_packages}"

              installesd_mach_kernel = File.join installesd, "mach_kernel"
              basesystem_mach_kernel = File.join basesystem, "mach_kernel"
              if File.exist? installesd_mach_kernel
                oh1 "Copying #{installesd_mach_kernel}"
                system(Utility::DITTO, installesd_mach_kernel, basesystem_mach_kernel)
                system(Utility::CHFLAGS, "hidden", basesystem_mach_kernel)
                puts "Copied: #{basesystem_mach_kernel}"
              end
            }
          }
        when :container, nil
          Dir.mktmpdir { |tmp|
            HDIUtil.write(@url, (tmpfile = File.join(tmp, File.basename(@url)))) { |installesd|
              options[:extensions][:up_to_date] = (options[:extensions][:remove].empty? and options[:extensions][:install].empty?)

              yield installesd if block_given?

              pre_update installesd, options

              basesystem_options = options.clone
              basesystem_options[:input] = basesystem_options[:output] = File.join(installesd, "BaseSystem.dmg")
              basesystem_flags = `#{Utility::LS} -lO "#{basesystem_options[:input]}"`.split[4]
              IESD::DMG::InstallESD::BaseSystem.new(File.join(basesystem_options[:input])).export(basesystem_options) { |basesystem|
                installesd_mach_kernel = File.join installesd, "mach_kernel"
                basesystem_mach_kernel = File.join basesystem, "mach_kernel"
                if File.exist? installesd_mach_kernel
                  oh1 "Copying #{installesd_mach_kernel}"
                  system(Utility::DITTO, installesd_mach_kernel, basesystem_mach_kernel)
                  system(Utility::CHFLAGS, "hidden", basesystem_mach_kernel)
                  puts "Copied: #{basesystem_mach_kernel}"
                end
              }
              system(Utility::CHFLAGS, basesystem_flags, basesystem_options[:output]) unless basesystem_flags == "-"

              IESD::DMG::InstallESD::BaseSystem.new(File.join(basesystem_options[:output])).show { |basesystem|
                oh1 "Updating kextcache"
                system(Utility::DITTO, IESD::DMG::BaseSystem::Extensions.new(basesystem).kextcache.url, (kextcache = File.join(installesd, "kernelcache")))
                system(Utility::CHFLAGS, "hidden", kextcache)
                puts "Updated: #{kextcache}"
              }

              post_update installesd, options
            }
            system(Utility::MV, tmpfile, options[:output])
          }
        end
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
      end

      class BaseSystem < IESD::DMG::BaseSystem
        private

        def pre_update volume_root, options

        end

        def post_update volume_root, options
          if File.exist? (mach_kernel = File.join(volume_root, "mach_kernel"))
            system(Utility::RM, mach_kernel)
          end
        end
      end
    end
  end
end
