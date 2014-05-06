require "shellwords"

module IESD
  class Packages
    class BaseSystemBinaries < PKGUtil::PKG
      def extract_mach_kernel output
        show { |pkg|
          payload = "#{pkg}/Payload"
          cpio = "#{payload}.cpio"
          ohai "Unarchiving #{payload}"
          case `/usr/bin/env file --brief --mime-type #{payload.shellescape}`.chomp
          when "application/x-bzip2"
            system("/usr/bin/env", "mv", payload, "#{cpio}.bz2")
            system("/usr/bin/env", "bunzip2", "#{cpio}.bz2")
          when "application/x-gzip"
            system("/usr/bin/env", "mv", payload, "#{cpio}.gz")
            system("/usr/bin/env", "gunzip", "#{cpio}.gz")
          end
          puts "Unarchived: #{cpio}"
          ohai "Extracting /mach_kernel"
          system("/usr/bin/env cpio -p -d -I #{cpio.shellescape} -- #{payload.shellescape} <<</mach_kernel >/dev/null 2>&1")
          system("/usr/bin/env", "mv", "#{payload}/mach_kernel", output)
          puts "Extracted: #{output}"
        }
      end
    end
  end
end
