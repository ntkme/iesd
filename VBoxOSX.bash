#!/bin/bash

VBoxOSX () {
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
      n)
        if [ -f "$OPTARG/Contents/MacOS/NullCPUPowerManagement" ]; then
          NCPMK=$OPTARG
        else
          echo "NullCPUPowerManagement not found." >&2
          return 1
        fi
        ;;
      :)
        return 1
        ;;
      h)
        cat << EOF
usage: $0 [-h] [-i InstallESD.dmg] [-n NullCPUPowerManagement.kext] [-o Output.dmg]

OPTIONS:
  -h  Print Help (this message) and exit
  -i  Location of InstallESD.dmg
  -o  Location of output
  -n  Location of NullCPUPowerManagement.kext

EXAMPLE:
  $0 -i ./InstallESD.dmg -n ./NullCPUPowerManagement.kext -o ./Output.dmg
EOF
        return 0
        ;;
    esac
  done

  if [ -z "$Input" ] || [ -z "$Output" ] || [ -z "$NCPMK" ]; then
    cat >&2 << EOF
Arguments not enough.
Run "$0 -h" for help.
EOF
    return 1
  fi

  local Source=$(mktemp -d "/tmp/XXXXXXXX")
  echo "Mounting Mac OS X Install ESD"
  hdiutil attach -nobrowse -mountpoint "$Source" "$Input"
  if [ ! -f "$Source/BaseSystem.dmg" ]; then
    hdiutil detach -quiet "$Source"
    rm -r "$Source"
    echo "BaseSystem.dmg not found in InstallESD.dmg." >&2
    return 1
  fi

  echo
  local TempBS_Dir=$(mktemp -d "/tmp/XXXXXXXX")
  local TempBS=$TempBS_Dir/BaseSystem.dmg
  echo "Creating Temporary Base System in UDRW format"
  hdiutil convert -format UDRW -ov -o "$TempBS" "$Source/BaseSystem.dmg"

  local Size=$(( $(hdiutil resize -limits "$Input" | tail -n 1 | cut -f 1) + $(hdiutil resize -limits "$Source/BaseSystem.dmg" | tail -n 1 | cut -f 1) ))
  echo
  echo "Resizing Temporary Base System to $Size blocks"
  hdiutil resize -sectors "$Size" "$TempBS"

  local Target=$(mktemp -d "/tmp/XXXXXXXX")
  echo
  echo "Mounting Temporary Base System"
  hdiutil attach -nobrowse -mountpoint "$Target" "$TempBS"

  echo
  echo "Copying Kernel"
  cp "$Source/mach_kernel" "$Target/mach_kernel"
  echo "Copying Packages"
  rm -r "$Target/System/Installation/Packages"
  cp -R "$Source/Packages" "$Target/System/Installation/Packages"

  echo
  echo "Unmounting Mac OS X Install ESD"
  hdiutil detach -quiet "$Source"
  rm -r "$Source"

  echo
  echo "Copying NullCPUPowerManagement.kext"
  cp -R "$NCPMK" "$Target/System/Library/Extensions/NullCPUPowerManagement.kext"

  echo
  echo "Unmounting Temporary Base System"
  hdiutil detach -quiet "$Target"
  rm -r "$Target"

  local Format=$(hdiutil imageinfo -format "$Input")
  echo
  echo "Converting Temporary Base System to $Format format"
  hdiutil convert -format "$Format" -o "$Output" "$TempBS"
  rm -r "$TempBS" "$TempBS_Dir"

  echo
  echo -e "\033[1;32mDone\033[0m"
}

VBoxOSX "$@"
