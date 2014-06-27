module IESD
  class APP

    # {/Applications/Install OS X.app}[rdoc-ref:IESD::APP::InstallOSX]
    #
    # The installer app for OS X Lion and later.
    # It contains an {InstallESD.dmg}[rdoc-ref:IESD::DMG::InstallESD].
    class InstallOSX

      # The relative path to {InstallESD.dmg}[rdoc-ref:IESD::DMG::InstallESD].
      INSTALLESD_DMG = File.join %w[ Contents SharedSupport InstallESD.dmg ]

      # Return true if the app is Install OS X.app, otherwise false.
      #
      # url - The String path to the app
      def self.validate url
        File.exist? File.join(url, INSTALLESD_DMG)
      end

      def initialize url # :nodoc:
        @url = File.absolute_path url
      end

      # Export to a new DMG.
      #
      # options - The Dictionary of the export options
      def export options
        IESD::DMG::InstallESD.new(File.join @url, INSTALLESD_DMG).export options
      end

      # Return true if the APP is an Install OS X.app, otherwise false.
      def valid?
        IESD::APP::InstallOSX.validate @url
      end
    end
  end
end
