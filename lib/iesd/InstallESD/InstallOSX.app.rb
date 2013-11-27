module IESD
  class APP
    class InstallOSX
      INSTALLESD_DMG = %w{Contents SharedSupport InstallESD.dmg}

      def self.validate url
        File.exist? File.join(url, *INSTALLESD_DMG)
      end

      def initialize url
        @url = File.absolute_path url
      end

      def export options
        IESD::DMG::InstallESD.new(File.join @url, *INSTALLESD_DMG).export options
      end

      def valid?
        IESD::APP::InstallOSX.validate @url
      end
    end
  end
end
