#!/bin/bash

InstallESD_dmg_kext_tool () {
  Help=$(cat <<EOF
usage: $0 [-BI] [-i InstallESD.dmg] [-o Output.dmg] [--] [kext ...]
       $0 [-h]

OPTIONS:
  -h  Print Help (this message) and exit
  -i  Location of InstallESD.dmg
  -o  Location of output
  -B  BaseSystem mode (default)
  -I  InstallESD mode

EXAMPLE:
  $0 -i InstallESD.dmg -o Output.dmg NullCPUPowerManagement.kext

EOF)
  Mode=B
  while getopts hi:o:IB opt; do
    case $opt in
      i)
        Input=$OPTARG
        ;;
      o)
        Output=$OPTARG
        ;;
      I)
        Mode=I
        ;;
      B)
        Mode=B
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
    echo "$Help" >&2
    return 1
  fi
  if [ ! -f "$Input" ]; then
    echo "InstallESD.dmg not found." >&2
    return 1
  fi
  if [ -e "$Output" ]; then
    echo "$Output already exists." >&2
    return 1
  fi
  if [ "$Mode" = "I" ] && [ "$#" -eq 0 ]; then
    echo "InstallESD mode requires at least one kext." >&2
    return 1
  fi

  Kexts=( "$@" )
  echo "Checking Kexts"
  for Kext in "${Kexts[@]}"; do
    KextBaseName=$(basename -- "$Kext")
    if [ -d "$Kext" ] && [ "${KextBaseName##*.}" = "kext" ] && [ -f "$Kext/Contents/MacOS/${KextBaseName%.*}" ]; then
      echo "✓ $KextBaseName"
    else
      echo "✗ $Kext" >&2
      return 1
    fi
  done

  Temp=$(mktemp -d "/tmp/InstallESD.dmg.kext.tool.XXXXXXXX")

  InstallESD_DMG=$Input
  InstallESD_DMG_Format=$(hdiutil imageinfo -format "$InstallESD_DMG")
  InstallESD=$Temp/InstallESD
  InstallESD_BaseSystem_DMG=$InstallESD/BaseSystem.dmg
  RW_BaseSystem_DMG=$Temp/RW_BaseSystem.dmg
  RW_BaseSystem=$Temp/RW_BaseSystem
  RW_BaseSystem_kernelcache=$RW_BaseSystem/System/Library/Caches/com.apple.kext.caches/Startup/kernelcache
  RW_InstallESD_DMG=$Temp/RW_InstallESD.dmg
  RW_InstallESD=$Temp/RW_InstallESD
  RW_InstallESD_BaseSystem_DMG=$RW_InstallESD/BaseSystem.dmg
  RW_InstallESD_kernelcache=$RW_InstallESD/kernelcache
  case $Mode in
    B)
      OSInstall_PKG=$RW_BaseSystem/System/Installation/Packages/OSInstall.pkg
      Kernel=$RW_BaseSystem/mach_kernel
      ;;
    I)
      OSInstall_PKG=$RW_InstallESD/Packages/OSInstall.pkg
      Kernel=$RW_InstallESD/mach_kernel
      ;;
  esac
  OSInstall=$Temp/OSInstall
  OSInstall_Script=$OSInstall/Scripts/postinstall_actions/installAdditionalKexts

  echo
  echo "Mounting Install ESD"
  mkdir "$InstallESD"
  hdiutil attach -quiet -nobrowse -noverify -mountpoint "$InstallESD" "$InstallESD_DMG"
  if [ -f "$InstallESD_BaseSystem_DMG" ]; then
    InstallESD_BaseSystem_DMG_Format=$(hdiutil imageinfo -format "$InstallESD_BaseSystem_DMG")
  else
    hdiutil detach -quiet "$InstallESD"
    if [ "$?" -eq 0 ]; then
      echo "BaseSystem.dmg not found in InstallESD.dmg." >&2
    else
      echo "Failed to mount InstallESD.dmg." >&2
    fi
    rm -rf "$Temp"
    return 1
  fi

  echo
  echo "Creating Temporary Base System in UDRW format"
  hdiutil convert -format UDRW -o "$RW_BaseSystem_DMG" "$InstallESD_BaseSystem_DMG"

  if [ "$Mode" = "B" ]; then
    echo
    RW_BaseSystem_Size_Sectors=$(( $(hdiutil resize -limits "$InstallESD_DMG" | tail -n 1 | cut -f 1) + $(hdiutil resize -limits "$InstallESD_BaseSystem_DMG" | tail -n 1 | cut -f 1) ))
    echo "Resizing Temporary Base System to $RW_BaseSystem_Size_Sectors blocks"
    hdiutil resize -sectors "$RW_BaseSystem_Size_Sectors" "$RW_BaseSystem_DMG"
  fi

  echo
  mkdir "$RW_BaseSystem"
  echo "Mounting Temporary Base System"
  hdiutil attach -owners on -nobrowse -mountpoint "$RW_BaseSystem" "$RW_BaseSystem_DMG"

  if [ "$Mode" = "B" ]; then
    echo
    echo "Copying Kernel"
    sudo -p "Please enter %u's password:" cp "$InstallESD/mach_kernel" "$RW_BaseSystem/mach_kernel"

    echo
    echo "Copying Packages"
    sudo -p "Please enter %u's password:" rm "$RW_BaseSystem/System/Installation/Packages"
    sudo -p "Please enter %u's password:" cp -R "$InstallESD/Packages" "$RW_BaseSystem/System/Installation/Packages"
  fi

  echo
  echo "Unmounting Install ESD"
  hdiutil detach -quiet "$InstallESD"
  rm -r "$InstallESD"

  echo
  echo "Copying Kexts"
  for Kext in "${Kexts[@]}"; do
    KextBaseName=$(basename -- "$Kext")
    sudo -p "Please enter %u's password:" cp -R "$Kext" "$RW_BaseSystem/System/Library/Extensions/$KextBaseName" && echo "✓ $KextBaseName"
  done

  if [ "$Mode" = "I" ]; then
    echo
    echo "Creating Temporary Install ESD in UDRW format"
    hdiutil convert -format UDRW -ov -o "$RW_InstallESD_DMG" "$InstallESD_DMG"

    echo
    echo "Mounting Temporary Install ESD"
    mkdir "$RW_InstallESD"
    hdiutil attach -owners on -nobrowse -mountpoint "$RW_InstallESD" "$RW_InstallESD_DMG"
  fi

  echo
  echo "Rebuilding kernelcache"
  sudo -p "Please enter %u's password:" kextcache -v 0 -prelinked-kernel "$RW_BaseSystem_kernelcache" -kernel "$Kernel" -volume-root "$RW_BaseSystem" -- "$RW_BaseSystem/System/Library/Extensions"

  if [ "$Mode" = "I" ]; then
    echo
    echo "Updating kernelcache on Temporary Install ESD"
    sudo -p "Please enter %u's password:" cp "$RW_BaseSystem_kernelcache" "$RW_InstallESD_kernelcache"
  fi

  echo
  echo "Creating OSInstall Script for Kexts"
  pkgutil --expand "$OSInstall_PKG" "$OSInstall"
  touch "$OSInstall_Script" && chmod a+x "$OSInstall_Script"
  echo "#!/bin/sh" > "$OSInstall_Script"
  echo >> "$OSInstall_Script"
  for Kext in "${Kexts[@]}"; do
    KextBaseName=$(basename "$Kext")
    echo "logger -p install.info \"Installing $KextBaseName\"" >> "$OSInstall_Script"
    echo "/bin/cp -R \"/System/Library/Extensions/$KextBaseName\" \"\$3/System/Library/Extensions/$KextBaseName\"" >> "$OSInstall_Script"
    echo >> "$OSInstall_Script"
  done
  echo "exit 0" >> "$OSInstall_Script"
  sudo -p "Please enter %u's password:" pkgutil --flatten "$OSInstall" "$OSInstall_PKG"
  rm -r "$OSInstall"

  echo
  echo "Unmounting Temporary Base System"
  hdiutil detach -quiet "$RW_BaseSystem"
  rm -r "$RW_BaseSystem"

  if [ "$Mode" = "B" ]; then
    echo
    echo "Converting Temporary Base System to $InstallESD_DMG_Format format"
    hdiutil convert -format "$InstallESD_DMG_Format" -o "$Output" "$RW_BaseSystem_DMG"
    rm "$RW_BaseSystem_DMG"
  fi

  if [ "$Mode" = "I" ]; then
    echo
    echo "Convert Temporary Base System to $InstallESD_BaseSystem_DMG_Format format"
    sudo -p "Please enter %u's password:" hdiutil convert -format "$InstallESD_BaseSystem_DMG_Format" -ov -o "$RW_InstallESD_BaseSystem_DMG" "$RW_BaseSystem_DMG"
    sudo -p "Please enter %u's password:" chflags hidden "$RW_InstallESD_BaseSystem_DMG" "$RW_InstallESD_kernelcache"
    rm "$RW_BaseSystem_DMG"

    echo
    echo "Unmounting Temporary Install ESD"
    hdiutil detach -quiet "$RW_InstallESD"
    rm -r "$RW_InstallESD"

    echo
    echo "Converting Temporary Install ESD to $InstallESD_DMG_Format format"
    hdiutil convert -format "$InstallESD_DMG_Format" -o "$Output" "$RW_InstallESD_DMG"
    rm "$RW_InstallESD_DMG"
  fi

  rm -rf "$Temp"

  echo
  echo -e "\xF0\x9F\x8D\xBA  Done"
}

InstallESD_dmg_kext_tool "$@"
