#!/bin/bash

InstallESD_dmg_tool () {
  echo -e "\033[31;4mWarning\033[0m: This tool has been obsoleted. Now it's just an alias for \033[32m$(dirname $0)/bin/iesd\033[0m."
  echo

  Help=$(cat <<EOF
usage: $0 [-B] [-i InstallESD.dmg] [-o Output.dmg] [--] [kext ...]
       $0 [-h]

OPTIONS:
  -h  Print Help (this message) and exit
  -B  Use BaseSystem as container
  -i  Location of InstallESD.dmg
  -o  Location of output

EXAMPLE:
  $0 -i InstallESD.dmg -o Output.dmg -- NullCPUPowerManagement.kext

EOF)
  while getopts hbBi:o:v: opt; do
    case $opt in
      b)
        Bless=1
        ;;
      B)
        BaseSystem=1
        ;;
      i)
        Input_DMG=$OPTARG
        ;;
      o)
        Output_DMG=$OPTARG
        ;;
      v)
        Version=$OPTARG
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
  if [ -z "$Input_DMG" ] || [ -z "$Output_DMG" ]; then
    echo "$Help" >&2
    return 1
  fi
  if [ ! -f "$Input_DMG" ]; then
    echo "InstallESD.dmg not found." >&2
    return 1
  fi
  if [ ! "$(echo "${Input_DMG##*.}" | tr "[:upper:]" "[:lower:]")" = "dmg" ]; then
    echo "Only dmg format is supported." >&2
    return 1
  fi
  if [ ! "$(echo "${Output_DMG##*.}" | tr "[:upper:]" "[:lower:]")" = "dmg" ]; then
    Output_DMG=${Output_DMG}.dmg
  fi
  if [ -e "$Output_DMG" ]; then
    echo "$Output_DMG already exists." >&2
    return 1
  fi

  Command=("$(dirname $0)/bin/iesd")
  [ -n "$Input_DMG" ] && Command+=("-i" "\"$Input_DMG\"")
  [ -n "$Output_DMG" ] && Command+=("-o" "\"$Output_DMG\"")
  [ -n "$BaseSystem" ] && Command+=("-t" "BaseSystem")
  if [ "$#" -ne 0 ]; then
    Kexts=("$@")
    Kexts=("${Kexts[@]/#/\"}")
    Kexts=("${Kexts[@]/%/\"}")
    Command+=("--install-kexts" "$(echo "${Kexts[@]}" | sed -e "s/\" \"/\",\"/g")")
  fi

  echo "Running Task:"
  echo "${Command[@]}"
  echo
  eval "${Command[@]}"
}

InstallESD_dmg_tool "$@"
