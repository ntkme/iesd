require "tmpdir"

module Utility
  BUNZIP2 = "/usr/bin/bunzip2"
  CHFLAGS = "/usr/bin/chflags"
  CPIO = "/usr/bin/cpio"
  DITTO = "/usr/bin/ditto"
  FILE = "/usr/bin/file"
  GUNZIP = "/usr/bin/gunzip"
  HDIUTIL = "/usr/bin/hdiutil"
  KEXTCACHE = "/usr/sbin/kextcache"
  LS = "/bin/ls"
  MV = "/bin/mv"
  PKGUTIL = "/usr/sbin/pkgutil"
  RM = "/bin/rm"
end

Dir[File.join(File.dirname(__FILE__), "utility", "*.rb")].each { |rb| require rb }
