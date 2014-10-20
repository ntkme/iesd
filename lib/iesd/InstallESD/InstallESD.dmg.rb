require "shellwords"

module IESD
  class DMG

    # {InstallESD.dmg}[rdoc-ref:IESD::DMG::InstallESD]
    #
    # The installer DMG for OS X Lion and later.
    # It contains a {BaseSystem.dmg}[rdoc-ref:IESD::DMG::BaseSystem], which is used to install the OS X Recovery.
    class InstallESD < HDIUtil::DMG

      # The relative path to the Packages.
      PACKAGES = File.join %w[ Packages ]

      # Export to a new DMG.
      #
      # options - The Dictionary of the export options
      def export options
        case options[:type]
        when :BaseSystem
          options = {
            :hdiutil => {
              :resize => {
                :grow => 0,
              }
            }
          }.merge(options)
          options[:hdiutil][:resize][:grow] += ( `/usr/bin/env hdiutil resize -limits #{@url.shellescape}`.chomp.split.map { |s| s.to_i } ).first

          show { |installesd|
            IESD::DMG::BaseSystem.new(File.join(installesd, "BaseSystem.dmg")).export(options) { |basesystem|
              installesd_basesystem_dmg = File.join installesd, "BaseSystem.dmg"
              basesystem_basesystem_dmg = File.join basesystem, "BaseSystem.dmg"
              oh1 "Copying #{installesd_basesystem_dmg}"
              system("/usr/bin/env", "ditto", installesd_basesystem_dmg, basesystem_basesystem_dmg)
              puts "Copied: #{basesystem_basesystem_dmg}"

              installesd_basesystem_chunklist = File.join installesd, "BaseSystem.chunklist"
              basesystem_basesystem_chunklist = File.join basesystem, "BaseSystem.chunklist"
              oh1 "Copying #{installesd_basesystem_chunklist}"
              system("/usr/bin/env", "ditto", installesd_basesystem_chunklist, basesystem_basesystem_chunklist)
              puts "Copied: #{basesystem_basesystem_chunklist}"

              installesd_packages = File.join installesd, PACKAGES
              basesystem_packages = File.join basesystem, IESD::DMG::BaseSystem::PACKAGES
              oh1 "Copying #{installesd_packages}"
              system("/usr/bin/env", "rm", basesystem_packages)
              system("/usr/bin/env", "ditto", installesd_packages, basesystem_packages)
              puts "Copied: #{basesystem_packages}"

              installesd_mach_kernel = File.join installesd, "mach_kernel"
              basesystem_mach_kernel = File.join basesystem, "mach_kernel"
              if File.exist? installesd_mach_kernel
                oh1 "Copying #{installesd_mach_kernel}"
                system("/usr/bin/env", "ditto", installesd_mach_kernel, basesystem_mach_kernel)
                system("/usr/bin/env", "chflags", "hidden", basesystem_mach_kernel)
                puts "Copied: #{basesystem_mach_kernel}"
              end
            }
          }
        when :InstallESD, nil
          Dir.mktmpdir { |tmp|
            HDIUtil.write(@url, (tmpfile = File.join(tmp, File.basename(@url))), options[:hdiutil]) { |installesd|
              options[:extensions][:up_to_date] = (options[:extensions][:uninstall].empty? and options[:extensions][:install].empty?)
              options[:mach_kernel] = File.exist? File.join(installesd, "mach_kernel") if options[:mach_kernel].nil?

              yield installesd if block_given?

              pre_update_extension installesd, options

              basesystem_options = options.clone
              basesystem_options[:input] = basesystem_options[:output] = File.join(installesd, "BaseSystem.dmg")
              basesystem_flags = `/usr/bin/env ls -lO #{basesystem_options[:input].shellescape}`.split[4]
              IESD::DMG::InstallESD::BaseSystem.new(File.join(basesystem_options[:input])).export(basesystem_options) { |basesystem|
                installesd_mach_kernel = File.join installesd, "mach_kernel"
                basesystem_mach_kernel = File.join basesystem, "mach_kernel"
                if File.exist? installesd_mach_kernel
                  oh1 "Copying #{installesd_mach_kernel}"
                  system("/usr/bin/env", "ditto", installesd_mach_kernel, basesystem_mach_kernel)
                  system("/usr/bin/env", "chflags", "hidden", basesystem_mach_kernel)
                  puts "Copied: #{basesystem_mach_kernel}"
                end
              }
              system("/usr/bin/env", "chflags", basesystem_flags, basesystem_options[:output]) unless basesystem_flags == "-"

              if File.exist? (kextcache = File.join(installesd, "kernelcache"))
                IESD::DMG::InstallESD::BaseSystem.new(File.join(basesystem_options[:output])).show { |basesystem|
                  oh1 "Updating Kextcache"
                  system("/usr/bin/env", "ditto", File.join(basesystem, *KextCache::KERNELCACHE), kextcache)
                  system("/usr/bin/env", "chflags", "hidden", kextcache)
                  puts "Updated: #{kextcache}"
                }
              end

              post_update_extension installesd, options

              if options[:interactive]
                oh1 "Starting Interactive Shell"
                puts "Environment: InstallESD"
                HDIUtil.shell installesd
              end
            }
            system("/usr/bin/env", "mv", tmpfile, options[:output])
          }
        else
          raise "invalid output type"
        end
      end

      private

      # Perform certain tasks before updating extensions.
      #
      # volume_root - The String path to the volume root
      # options     - The Dictionary of the export options
      def pre_update_extension volume_root, options
        if !File.exist? (mach_kernel = File.join(volume_root, "mach_kernel")) and (options[:mach_kernel] or !options[:extensions][:up_to_date])
          IESD::Packages::BaseSystemBinaries.new(File.join(volume_root, PACKAGES, "BaseSystemBinaries.pkg")).extract_mach_kernel mach_kernel
          system("/usr/bin/env", "chflags", "hidden", mach_kernel)
        end
      end

      # Perform certain tasks after updating extensions.
      #
      # volume_root - The String path to the volume root
      # options     - The Dictionary of the export options
      def post_update_extension volume_root, options
        if !options[:extensions][:up_to_date] and options[:extensions][:postinstall]
          IESD::Packages::OSInstall.new(File.join(volume_root, PACKAGES, "OSInstall.pkg")).postinstall_extensions options[:extensions]
        end
        if !options[:mach_kernel] and File.exist? (mach_kernel = File.join(volume_root, "mach_kernel"))
          system("/usr/bin/env", "rm", mach_kernel)
        end
      end

      class BaseSystem < IESD::DMG::BaseSystem # :nodoc:
        private

        # Perform certain tasks before updating extensions.
        #
        # volume_root - The String path to the volume root
        # options     - The Dictionary of the export options
        def pre_update_extension volume_root, options

        end

        # Perform certain tasks after updating extensions.
        #
        # volume_root - The String path to the volume root
        # options     - The Dictionary of the export options
        def post_update_extension volume_root, options
          if File.exist? (mach_kernel = File.join(volume_root, "mach_kernel"))
            system("/usr/bin/env", "rm", mach_kernel)
          end
        end
      end
    end
  end
end
