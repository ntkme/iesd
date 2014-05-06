module IESD
  class Packages
    class OSInstall < PKGUtil::PKG
      def postinstall_extensions extensions
        update { |pkg|
          oh1 "Creating Extensions Postinstall Script"
          script = File.join pkg, *%w{ Scripts postinstall_actions kext.tool }
          File.open(script, "a+") { |f|
            f.puts("#!/bin/sh")
            extensions[:uninstall].each { |kext|
              f.puts(%Q{logger -p install.info "Uninstalling #{kext}"})
              f.puts(%Q{/bin/test -e "$3%{extra_extensions_kext}" && /bin/rm -rf "$3%{extra_extensions_kext}" || /bin/rm -rf "$3%{extensions_kext}"} % {
                :extensions_kext => "/System/Library/Extensions/#{kext}",
                :extra_extensions_kext => "/Library/Extensions/#{kext}"
              })
            }
            extensions[:install].each { |kext|
              f.puts(%Q{logger -p install.info "Installing #{File.basename kext}"})
              f.puts(%Q{/bin/test -e "%{extensions_kext}" && /usr/bin/ditto "%{extensions_kext}" "$3%{extensions_kext}" || /usr/bin/ditto "%{extra_extensions_kext}" "$3%{extra_extensions_kext}"} % {
                :extensions_kext => "/System/Library/Extensions/#{File.basename kext}",
                :extra_extensions_kext => "/Library/Extensions/#{File.basename kext}"
              })
            }
          }
          File.chmod(0755, script)
          puts "Created: #{script}"
        }
      end
    end
  end
end
