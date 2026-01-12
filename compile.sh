#!/usr/bin/env bash

# -------- Script configuration -------- #
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# -------- Script utils -------- #
setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

# msg "This is a ${RED}very important${NOFORMAT} message, but not a script output value!"
msg() {
  echo >&2 -e "${1-}"
}

info() {
  msg "${BLUE}[INFO]${NOFORMAT} ${1-}"
}

setup_colors

# -------- Script verifications -------- #

# -------- Script content -------- #

# STEP 0 – Préparation
step_0() {
  if [ -d "tmp" ]; then
    rm -rf "tmp"
    info "tmp directory removed"
  fi
  mkdir tmp
  info "tmp directory created"
}

# STEP 1 – Compilation shellcode
step_1() {
  find ./ -name "shellcode.nasm"
  nasm -g -w+x shellcode.nasm -o tmp/1-shellcode.bin
}

# STEP 2 – Conversion C-array
# - Convertir tmp/1-shellcode.bin
# - Générer tmp/2-shellcode.bin.c-array
# - Vérifier la cohérence du fichier généré

# STEP 3 – Génération du C final
# - Injecter le C-array dans main.tpl.c
# - Produire tmp/3-main.c
# - Vérifier que le fichier est compilable

# STEP 4 – Compilation PE64
# - Compiler tmp/3-main.c avec x86_64-w64-mingw32-gcc
# - Générer tmp/4-pefile.exe
# - Gérer toutes les erreurs possibles

# STEP 5 – Finalisation
# - Copier tmp/4-pefile.exe vers ./pefile.exe
# - Vérifier la présence du fichier final


main() {
  step_0
  step_1
}

main
