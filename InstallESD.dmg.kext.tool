#!/bin/bash

InstallESD_dmg_kext_tool () {
  local opt
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
      :)
        return 1
        ;;
      h)
        cat << EOF
usage: $0 [-i InstallESD.dmg] [-o Output.dmg] [kexts]
       $0 [-h]

OPTIONS:
  -h  Print Help (this message) and exit
  -i  Location of InstallESD.dmg
  -o  Location of output

EXAMPLE:
  $0 -i InstallESD.dmg -o Output.dmg NullCPUPowerManagement.kext
EOF
        return 0
        ;;
    esac
  done

  shift $(($OPTIND - 1))
  if [ -z "$Input" ] || [ -z "$Output" ] || [ "$#" -eq 0 ]; then
    cat >&2 << EOF
Arguments not enough.
Run "$0 -h" for help.
EOF
    return 1
  fi

  local Kexts=( "$@" ) Kext
  echo "Checking Kexts"
  for Kext in "${Kexts[@]}"; do
    local KextBaseName=$(basename "$Kext")
    if [ -d "$Kext" ] && [ "${KextBaseName##*.}" = "kext" ] && [ -f "$Kext/Contents/MacOS/${KextBaseName%.*}" ]; then
      echo "✓ $KextBaseName"
    else
      echo
      echo "Bad kext: $Kext" >&2
      exit 1
    fi
  done

  local InstallESD_DMG=$Input
  local InstallESD=$(mktemp -d "/tmp/XXXXXXXX")
  local BaseSystem_DMG=$InstallESD/BaseSystem.dmg
  hdiutil attach -quiet -nobrowse -noverify -mountpoint "$InstallESD" "$InstallESD_DMG"
  if [ ! -f "$BaseSystem_DMG" ]; then
    hdiutil detach -quiet "$InstallESD"
    rm -r "$InstallESD"
    echo "BaseSystem.dmg not found in InstallESD.dmg." >&2
    return 1
  fi
  hdiutil detach -quiet "$InstallESD"
  rm -r "$InstallESD"

  local Temp=$(mktemp -d "/tmp/XXXXXXXX")

  echo
  local RW_InstallESD_DMG=$Temp/InstallESD.dmg
  echo "Creating Temporary Install ESD in UDRW format"
  hdiutil convert -format UDRW -ov -o "$RW_InstallESD_DMG" "$InstallESD_DMG"

  echo
  local RW_InstallESD=$(mktemp -d "/tmp/XXXXXXXX")
  echo "Mounting Temporary Install ESD"
  hdiutil attach -owners on -nobrowse -mountpoint "$RW_InstallESD" "$RW_InstallESD_DMG"

  echo
  local BaseSystem_DMG=$RW_InstallESD/BaseSystem.dmg
  local RW_BaseSystem_DMG=$Temp/BaseSystem.dmg
  echo "Creating Temporary Base System in UDRW format"
  hdiutil convert -format UDRW -o "$RW_BaseSystem_DMG" "$BaseSystem_DMG"

  echo
  local RW_BaseSystem=$(mktemp -d "/tmp/XXXXXXXX")
  echo "Mounting Temporary Base System"
  hdiutil attach -owners on -nobrowse -mountpoint "$RW_BaseSystem" "$RW_BaseSystem_DMG"

  echo
  echo "Copying Kexts"
  for Kext in "${Kexts[@]}"; do
    local KextBaseName=$(basename "$Kext")
    sudo -p "Please enter %u's password:" cp -R "$Kext" "$RW_BaseSystem/System/Library/Extensions/$(basename "$Kext")" && echo "✓ $KextBaseName"
  done

  echo
  local RW_BaseSystem_kernelcache="$RW_BaseSystem/System/Library/Caches/com.apple.kext.caches/Startup/kernelcache"
  local RW_InstallESD_kernelcache="$RW_InstallESD/kernelcache"
  echo "Rebuilding kernelcache"
  sudo -p "Please enter %u's password:" kextcache -v 0 -prelinked-kernel "$RW_BaseSystem_kernelcache" -kernel "$RW_InstallESD/mach_kernel" -volume-root "$RW_BaseSystem" -- "$RW_BaseSystem/System/Library/Extensions"
  sudo -p "Please enter %u's password:" cp "$RW_BaseSystem_kernelcache" "$RW_InstallESD_kernelcache"

  echo
  echo "Unmounting Temporary Base System"
  hdiutil detach -quiet "$RW_BaseSystem"
  rm -r "$RW_BaseSystem"

  echo
  local BaseSystem_DMG_Format=$(hdiutil imageinfo -format "$BaseSystem_DMG")
  echo "Convert Temporary Base System to $BaseSystem_DMG_Format format"
  sudo -p "Please enter %u's password:" hdiutil convert -format "$BaseSystem_DMG_Format" -ov -o "$BaseSystem_DMG" "$RW_BaseSystem_DMG"
  sudo -p "Please enter %u's password:" chflags hidden "$BaseSystem_DMG" "$RW_InstallESD_kernelcache"
  rm "$RW_BaseSystem_DMG"

  echo
  echo "Unmounting Temporary Install ESD"
  hdiutil detach -quiet "$RW_InstallESD"
  rm -r "$RW_InstallESD"

  echo
  local InstallESD_DMG_Format=$(hdiutil imageinfo -format "$InstallESD_DMG")
  echo "Converting Temporary Install ESD to $InstallESD_DMG_Format format"
  hdiutil convert -format "$InstallESD_DMG_Format" -o "$Output" "$RW_InstallESD_DMG"
  rm -rf "$Temp"

  echo
  echo -e "\033[1;32mDone\033[0m"
}

InstallESD_dmg_kext_tool "$@"
