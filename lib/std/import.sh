#!/usr/bin/env bash
[[ $((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1])) -lt 403 ]] && {
	echo "需 Bash 4.3+ 当前 ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}" >&2
	exit 1
} || true

readonly _LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../ && pwd)"

declare -p __loaded_modules &> /dev/null 2>&1 && return 0
declare -ga __loaded_modules=("$_LIB_DIR/std/import.sh")

source() {
	local mod="$1"

	[[ $mod == */* ]] || mod="$PWD/$mod"
	[[ $mod == /* ]] || mod="$(cd "${mod%/*}" && pwd)/${mod##*/}"

	[[ " ${__loaded_modules[*]} " == *" $mod "* ]] && return 0
	. "$1" || return $?
	__loaded_modules+=("$mod")
}

import() {
	local mod
	for mod in "$@"; do
		[[ $mod == /* ]] || mod="$_LIB_DIR/$mod"
		[[ -f "${mod}.sh" ]] && source "${mod}.sh" || { [[ -f ${mod} ]] && source "$mod"; } || return 1
	done
}

.env() { [[ -f .env ]] && source .env || true; [[ -v BASH_SOURCE[1] ]] && [[ -f "${BASH_SOURCE[1]%/*}/.env" ]] && source "${BASH_SOURCE[1]%/*}/.env" || true; }
