module IESD
  class Extensions
    EXTENSIONS = %w{ System Library Extensions }

    attr_reader :volume_root, :url

    def initialize volume_root
      @volume_root = volume_root
      @url = File.join @volume_root, *EXTENSIONS
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
  end
end
