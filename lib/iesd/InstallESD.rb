module IESD
  def self.new url
    File.extname(url).downcase == ".app" ? IESD::APP.new(url) : IESD::DMG.new(url)
  end

  class APP
    def self.new url
      IESD::APP::InstallOSX.validate(url) ? IESD::APP::InstallOSX.new(url) : nil
    end
  end

  class DMG
    def self.new url
      i = nil
      if HDIUtil::validate url
        HDIUtil::DMG.new(url).show { |mountpoint|
          oh1 "Detecting #{url}"
          case
          when (File.exist? File.join(mountpoint, *%w{ .IABootFiles }))
            i = IESD::DMG::InstallOSX.new url
          when (File.exist? File.join(mountpoint, *%w{ BaseSystem.dmg }))
            i = IESD::DMG::InstallESD.new url
          when (File.exist? File.join(mountpoint, *%w{ System Installation }))
            i = IESD::DMG::BaseSystem.new url
          else
            raise "unknown type"
          end
          puts "Detected: #{i.class.name.split("::").last}"
        }
      end
      i
    end
  end
end

