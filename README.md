iESD
====

Customize OS X InstallESD.

```
Usage: iesd -i <inputfile> -o <outputfile> [options]

Specific options:
    -i, --input file                 Specify the input dmg or app.
    -o, --output file                Specify the output dmg.
    -t, --type type                  Specify the output type.  Type could be BaseSystem or InstallESD.
    -s, --[no-]interactive-shell     Open /bin/bash inside the temporary mount directory.

HDIUtil options:
        --grow sectors               Specify the size of the image to grow in 512-byte sectors.
        --[no-]shrink                Do [not] shrink the output image.

Boot options:
        --[no-]fallback-kernel       Do [not] fallback to mach_kernel when kernelcache fails to boot.

Extensions options:
        --install-extension kext     Add the kext to the list of the extensions to be installed.
        --uninstall-extension kext   Add the kext to the list of the extensions to be uninstalled.
        --[no-]postinstall-extensions
                                     Do [not] patch OSInstall.pkg to postinstall extensions.
        --[no-]update-kernelcache    Do [not] rebuild the startup kernelcache.

Common options:
        --[no-]verbose               Run verbosely
    -h, --help                       Show this message
```
