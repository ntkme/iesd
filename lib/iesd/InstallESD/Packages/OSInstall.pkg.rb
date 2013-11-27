module IESD
  class Packages
    class OSInstall < PKGUtil::PKG
      def postinstall_extensions extensions
        update { |pkg|
          oh1 "Creating Extensions Postinstall Script"
          script = File.join pkg, *%w{ Scripts postinstall_actions kext.tool }
          File.open(script, "a+") { |f|
            f.puts("#!/bin/sh")
            extensions[:remove].each { |kext|
              f.puts("logger -p install.info \"Removing #{kext}\"")
              f.puts("/bin/rm -rf \"$3/System/Library/Extensions/#{kext}\"")
            }
            extensions[:install].each { |kext|
              f.puts("logger -p install.info \"Installing #{File.basename kext}\"")
              f.puts("/usr/bin/ditto \"/System/Library/Extensions/#{File.basename kext}\" \"$3/System/Library/Extensions/#{File.basename kext}\"")
            }
          }
          File.chmod(0755, script)
          puts "Created: #{script}"
        }
      end
    end
  end
end
