module IESD
  class Extensions
    EXTENSIONS = %w{ System Library Extensions }
    EXTRA_EXTENSIONS = %w{ Library Extensions }

    attr_reader :volume_root, :url

    def initialize volume_root
      @volume_root = volume_root
      @extensions = File.join @volume_root, *EXTENSIONS
      @extra_extensions = File.join @volume_root, *EXTRA_EXTENSIONS
    end

    def uninstall kexts
      if !kexts.empty?
        oh1 "Uninstalling Extensions"
        kexts.each { |kext|
          kext_url = File.join(@extra_extensions, kext)
          if File.exist? kext_url
            system("/usr/bin/env", "rm", "-rf", kext_url)
            puts "Uninstalled: #{kext_url}"
          else
            kext_url = File.join(@extensions, kext)
            system("/usr/bin/env", "rm", "-rf", kext_url)
            puts "Removed: #{kext_url}"
          end
        }
      end
    end

    def install kexts
      if !kexts.empty?
        oh1 "Installing Extensions"
        kexts.each { |kext|
          kext_url = File.join(@extensions, File.basename(kext))
          if File.exist? kext_url
            system("/usr/bin/env", "ditto", kext, kext_url)
            puts "Overwrote: #{kext_url}"
          else
            kext_url = File.join(@extra_extensions, File.basename(kext)) if File.exist? @extra_extensions
            system("/usr/bin/env", "ditto", kext, kext_url)
            puts "Installed: #{kext_url}"
          end
        }
      end
    end
  end
end
