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

fail() {
  msg "${RED}[ERROR]${NOFORMAT} ${1-}"
  exit 1
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
  if [ ! -f "shellcode.nasm" ]; then
    fail "shellcode.nasm not found"
  fi
  if ! command -v nasm &>/dev/null; then
    fail "nasm not installed"
  fi
  nasm -g -w+x shellcode.nasm -o tmp/1-shellcode.bin
  info "shellcode compiled -> tmp/1-shellcode.bin"
}

# STEP 2 – Conversion C-array
# - Convertir tmp/1-shellcode.bin
# - Générer tmp/2-shellcode.bin.c-array
# - Vérifier la cohérence du fichier généré
step_2() {
  if [ ! -f "tmp/1-shellcode.bin" ]; then
    fail "tmp/1-shellcode.bin not found"
  fi
  if ! command -v xxd &>/dev/null; then
    fail "xxd not installed"
  fi
  xxd -i tmp/1-shellcode.bin >tmp/2-shellcode.bin.c-array
  if [ ! -s "tmp/2-shellcode.bin.c-array" ]; then
    fail "tmp/2-shellcode.bin.c-array is empty"
  fi
  info "C-array generated -> tmp/2-shellcode.bin.c-array"
}

# STEP 3 – Génération du C final
# - Injecter le C-array dans main.tpl.c
# - Produire tmp/3-main.c
# - Vérifier que le fichier est compilable
step_3() {
  if [ ! -f "main.tpl.c" ]; then
    fail "main.tpl.c not found"
  fi
  if [ ! -f "tmp/2-shellcode.bin.c-array" ]; then
    fail "tmp/2-shellcode.bin.c-array not found"
  fi

  bytecode_size=$(wc -c <tmp/1-shellcode.bin | tr -d ' ')
  if [ "${bytecode_size}" -le 0 ]; then
    fail "invalid shellcode size"
  fi

  bytecode=$(awk '
    BEGIN { inside = 0; count = 0 }
    /{/ { inside = 1; next }
    /};/ { exit }
    inside {
      gsub(/,/, "", $0)
      for (i = 1; i <= NF; i++) {
        if (count > 0) printf ", "
        printf "%s", $i
        count++
      }
    }
    END { print "" }
  ' tmp/2-shellcode.bin.c-array)

  if [ -z "${bytecode}" ]; then
    fail "failed to extract shellcode bytes"
  fi

  sed \
    -e "s/SET_SIZE/${bytecode_size}/g" \
    -e "s/SET_BYTECODE/${bytecode}/g" \
    main.tpl.c >tmp/3-main.c

  if [ ! -s "tmp/3-main.c" ]; then
    fail "tmp/3-main.c is empty"
  fi
  info "C wrapper generated -> tmp/3-main.c"
}

# STEP 4 – Compilation PE64
# - Compiler tmp/3-main.c avec x86_64-w64-mingw32-gcc
# - Générer tmp/4-pefile.exe
# - Gérer toutes les erreurs possibles
step_4() {
  if ! command -v x86_64-w64-mingw32-gcc &>/dev/null; then
    fail "x86_64-w64-mingw32-gcc not installed"
  fi
  if [ ! -f "tmp/3-main.c" ]; then
    fail "tmp/3-main.c not found"
  fi
  x86_64-w64-mingw32-gcc -Os -s tmp/3-main.c -o tmp/4-pefile.exe
  if [ ! -s "tmp/4-pefile.exe" ]; then
    fail "tmp/4-pefile.exe not generated"
  fi
  info "PE compiled -> tmp/4-pefile.exe"
}

# STEP 5 – Finalisation
# - Copier tmp/4-pefile.exe vers ./pefile.exe
# - Vérifier la présence du fichier final
step_5() {
  if [ ! -f "tmp/4-pefile.exe" ]; then
    fail "tmp/4-pefile.exe not found"
  fi
  cp tmp/4-pefile.exe ./pefile.exe
  if [ ! -s "pefile.exe" ]; then
    fail "pefile.exe not generated"
  fi
  info "final artifact -> ./pefile.exe"
}

main() {
  step_0
  step_1
  step_2
  step_3
  step_4
  step_5
}

main
