module IESD
  class DMG

    # {BaseSystem.dmg}[rdoc-ref:IESD::DMG::BaseSystem]
    #
    # The installer DMG before OS X Lion.
    class BaseSystem < HDIUtil::DMG

      # The relative path to the Packages.
      PACKAGES = File.join %w[ System Installation Packages ]

      # Export to a new DMG.
      #
      # options - The Dictionary of the export options
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

      class Extensions < IESD::Extensions # :nodoc:

        # Update the Extensions.
        #
        # extensions_options - The Dictionary of the extensions options.
        def update extensions_options
          uninstall extensions_options[:uninstall]
          install extensions_options[:install]
          KextCache.update_volume @volume_root if extensions_options[:kextcache] or (extensions_options[:kextcache].nil? and !extensions_options[:up_to_date])
        end
      end
    end
  end
end
