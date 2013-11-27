module IESD
  class DMG
    class InstallOSX < HDIUtil::DMG
      def export options
        show { |mountpoint|
          IESD::APP::InstallOSX.new(Dir[File.join(mountpoint, "*.app")][0]).export options
        }
      end
    end
  end
end
