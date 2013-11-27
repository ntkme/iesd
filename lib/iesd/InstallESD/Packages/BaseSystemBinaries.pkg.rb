module IESD
  class Packages
    class BaseSystemBinaries < PKGUtil::PKG
      def extract_mach_kernel output
        show { |pkg|
          payload = "#{pkg}/Payload"
          cpio = "#{payload}.cpio"
          ohai "Unarchiving #{payload}"
          case `#{Utility::FILE} --brief --mime-type #{payload}`.chomp
          when "application/x-bzip2"
            system(Utility::MV, payload, "#{cpio}.bz2")
            system(Utility::BUNZIP2, "#{cpio}.bz2")
          when "application/x-gzip"
            system(Utility::MV, payload, "#{cpio}.gz")
            system(Utility::GUNZIP, "#{cpio}.gz")
          end
          puts "Unarchived: #{cpio}"
          ohai "Extracting /mach_kernel"
          system("#{Utility::CPIO} -p -d -I \"#{cpio}\" -- \"#{payload}\" <<</mach_kernel >/dev/null 2>&1")
          system(Utility::MV, "#{payload}/mach_kernel", output)
          puts "Extracted: #{output}"
        }
      end
    end
  end
end
