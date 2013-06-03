#!/bin/bash

BaseSystem_dmg_kext_tool () {
  Help=$(cat << EOF
usage: $0 [-i InstallESD.dmg] [-o Output.dmg] [kexts]
       $0 [-h]

OPTIONS:
  -h  Print Help (this message) and exit
  -i  Location of InstallESD.dmg
  -o  Location of output

EXAMPLE:
  $0 -i InstallESD.dmg -o Output.dmg NullCPUPowerManagement.kext
EOF)
  while getopts hi:o:n: opt; do
    case $opt in
      i)
        if [ -f "$OPTARG" ]; then
          Input=$OPTARG
        else
          echo "InstallESD.dmg not found." >&2
          return 1
        fi
        ;;
      o)
        if [ -e "$OPTARG" ]; then
          echo "$OPTARG already exists." >&2
          return 1
        else
          Output=$OPTARG
        fi
        ;;
      h)
        echo "$Help"
        return 0
        ;;
      ?|:)
        echo "$Help"
        return 1
        ;;
    esac
  done

  shift $(($OPTIND - 1))
  if [ -z "$Input" ] || [ -z "$Output" ]; then
    cat >&2 << EOF
Arguments not enough.
Run "$0 -h" for help.
EOF
    return 1
  fi

  Kexts=( "$@" ) Kext
  echo "Checking Kexts"
  for Kext in "${Kexts[@]}"; do
    KextBaseName=$(basename "$Kext")
    if [ -d "$Kext" ] && [ "${KextBaseName##*.}" = "kext" ] && [ -f "$Kext/Contents/MacOS/${KextBaseName%.*}" ]; then
      echo "✓ $KextBaseName"
    else
      echo
      echo "Bad kext: $Kext" >&2
      exit 1
    fi
  done

  echo
  InstallESD_DMG=$Input
  InstallESD=$(mktemp -d "/tmp/XXXXXXXX")
  BaseSystem_DMG=$InstallESD/BaseSystem.dmg
  echo "Mounting Mac OS X Install ESD"
  hdiutil attach -nobrowse -mountpoint "$InstallESD" "$InstallESD_DMG"
  if [ ! -f "$BaseSystem_DMG" ]; then
    hdiutil detach -quiet "$InstallESD" || echo "Failed to mount InstallESD.dmg." >&2
    rm -r "$InstallESD"
    echo "BaseSystem.dmg not found in InstallESD.dmg." >&2
    return 1
  fi

  Temp=$(mktemp -d "/tmp/XXXXXXXX")

  echo
  RW_BaseSystem_DMG=$Temp/BaseSystem.dmg
  echo "Creating Temporary Base System in UDRW format"
  hdiutil convert -format UDRW -o "$RW_BaseSystem_DMG" "$BaseSystem_DMG"

  echo
  RW_BaseSystem_Size_Sectors=$(( $(hdiutil resize -limits "$InstallESD_DMG" | tail -n 1 | cut -f 1) + $(hdiutil resize -limits "$BaseSystem_DMG" | tail -n 1 | cut -f 1) ))
  echo "Resizing Temporary Base System to $RW_BaseSystem_Size_Sectors blocks"
  hdiutil resize -sectors "$RW_BaseSystem_Size_Sectors" "$RW_BaseSystem_DMG"

  echo
  RW_BaseSystem=$(mktemp -d "/tmp/XXXXXXXX")
  echo "Mounting Temporary Base System"
  hdiutil attach -owners on -nobrowse -mountpoint "$RW_BaseSystem" "$RW_BaseSystem_DMG"

  echo
  echo "Copying Kernel"
  sudo -p "Please enter %u's password:" cp "$InstallESD/mach_kernel" "$RW_BaseSystem/mach_kernel"
  echo "Copying Packages"
  sudo -p "Please enter %u's password:" rm "$RW_BaseSystem/System/Installation/Packages"
  sudo -p "Please enter %u's password:" cp -R "$InstallESD/Packages" "$RW_BaseSystem/System/Installation/Packages"

  echo
  echo "Unmounting Mac OS X Install ESD"
  hdiutil detach -quiet "$InstallESD"
  rm -r "$InstallESD"

  if [ "${#Kexts[@]}" -gt 0 ]; then
    echo
    echo "Copying Kexts"
    for Kext in "${Kexts[@]}"; do
      KextBaseName=$(basename "$Kext")
      sudo -p "Please enter %u's password:" cp -R "$Kext" "$RW_BaseSystem/System/Library/Extensions/$KextBaseName" && echo "✓ $KextBaseName"
    done

    echo
    RW_BaseSystem_kernelcache="$RW_BaseSystem/System/Library/Caches/com.apple.kext.caches/Startup/kernelcache"
    echo "Rebuilding kernelcache"
    sudo -p "Please enter %u's password:" kextcache -v 0 -prelinked-kernel "$RW_BaseSystem_kernelcache" -kernel "$RW_BaseSystem/mach_kernel" -volume-root "$RW_BaseSystem" -- "$RW_BaseSystem/System/Library/Extensions"

    echo
    OSInstall_PKG="$RW_BaseSystem/System/Installation/Packages/OSInstall.pkg"
    OSInstall="$Temp/OSInstall"
    InstallAdditionalKexts="$OSInstall/Scripts/postinstall_actions/installAdditionalKexts"
    echo "Patching Install Scripts"
    pkgutil --expand "$OSInstall_PKG" "$OSInstall"
    touch "$InstallAdditionalKexts" && chmod 755 "$InstallAdditionalKexts"
    echo "#!/bin/sh" > "$InstallAdditionalKexts"
    echo >> "$InstallAdditionalKexts"
    for Kext in "${Kexts[@]}"; do
      KextBaseName=$(basename "$Kext")
      echo "logger -p install.info \"Installing $KextBaseName\"" >> "$InstallAdditionalKexts"
      echo "/bin/cp -R \"/System/Library/Extensions/$KextBaseName\" \"\$3/System/Library/Extensions/$KextBaseName\"" >> "$InstallAdditionalKexts"
      echo >> "$InstallAdditionalKexts"
    done
    echo "exit 0" >> "$InstallAdditionalKexts"
    sudo -p "Please enter %u's password:" pkgutil --flatten "$OSInstall" "$OSInstall_PKG"
  fi

  echo
  echo "Unmounting Temporary Base System"
  hdiutil detach -quiet "$RW_BaseSystem"
  rm -r "$RW_BaseSystem"

  echo
  InstallESD_DMG_Format=$(hdiutil imageinfo -format "$InstallESD_DMG")
  echo "Converting Temporary Base System to $InstallESD_DMG_Format format"
  hdiutil convert -format "$InstallESD_DMG_Format" -o "$Output" "$RW_BaseSystem_DMG"
  rm -rf "$Temp"

  echo
  echo -e "\033[1;32mDone\033[0m"
}

BaseSystem_dmg_kext_tool "$@"
