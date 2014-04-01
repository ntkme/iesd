module KextCache
  KEXTCACHE_DEFAULT_OPTIONS = %w{ -v 0 -no-authentication }

  EXTENSIONS = %w{ System Library Extensions }
  KERNELCACHE = %w{ System Library Caches com.apple.kext.caches Startup kernelcache }
  MKEXT = %w{ System Library Caches com.apple.kext.caches Startup Extensions.mkext }
  MKEXT_PPC = %w{ System Library Extensions.mkext }

  def self.update_volume volume_root
    oh1 "Updating Kextcache"
    if File.exist? (mach_kernel = File.join(volume_root, "mach_kernel"))
      case
      when (File.exist? (url = File.join(volume_root, *KERNELCACHE)))
        system(Utility::KEXTCACHE, *KEXTCACHE_DEFAULT_OPTIONS, "-prelinked-kernel", url, "-kernel", mach_kernel, "-volume-root", volume_root, "--", File.join(volume_root, *EXTENSIONS))
      when (File.exist? (url = File.join(volume_root, *MKEXT)))
        system(Utility::KEXTCACHE, *KEXTCACHE_DEFAULT_OPTIONS, *%w{ -a i386 -a x86_64 }, "-mkext", url, "-kernel", mach_kernel, "-volume-root", volume_root, "--", File.join(volume_root, *EXTENSIONS))
        if File.exist? (mkext_ppc = File.join(volume_root, *MKEXT_PPC))
          system(Utility::DITTO, url, mkext_ppc)
        end
      when (File.exist? (url = File.join(volume_root, *MKEXT_PPC)))
        system(Utility::DITTO, *KEXTCACHE_DEFAULT_OPTIONS, *%w{ -a ppc -a i386 }, "-mkext", url, "-kernel", mach_kernel, "-volume-root", volume_root, "--", File.join(volume_root, *EXTENSIONS))
      else
        puts "kextcache aborted: unknown kernel cache type"
        return
      end
      puts "Updated: #{url}"
    else
      opoo "kextcache aborted: mach_kernel not found"
    end
  end
end
