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
# - Vérifier l'environnement
# - Supprimer ./tmp si existant
# - Recréer ./tmp proprement

step_0() {
	if [ -d "tmp" ]; then
		rmdir "tmp"
		info "tmp directory removed"
	else
		mkdir tmp
		info "tmp directory created"
	fi
}

main() {
	step_0
}

main
