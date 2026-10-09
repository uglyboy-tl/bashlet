#!/usr/bin/env bash
[[ $((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1])) -lt 403 ]] && {
	echo "requires Bash 4.3+, current ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}" >&2
	exit 1
} || true

readonly _LIB_DIR="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"

declare -p __loaded_modules &> /dev/null 2>&1 && return 0
declare -ga __loaded_modules=("$_LIB_DIR/std/import.sh")

source() {
	local mod="$1"

	[[ $mod == */* ]] || mod="$PWD/$mod"
	[[ $mod == /* ]] || mod="$(cd "${mod%/*}" && pwd)/${mod##*/}"

	[[ " ${__loaded_modules[*]} " == *" $mod "* ]] && return 0
	. "$mod" || return $?
	__loaded_modules+=("$mod")
}

import() {
	local mod
	for mod in "$@"; do
		[[ $mod == /* ]] || mod="$_LIB_DIR/$mod"
		[[ -f "${mod}.sh" ]] && source "${mod}.sh" || { [[ -f ${mod} ]] && source "$mod"; } || return 1
	done
}

# 只加载调用方脚本所在目录的 .env，不回退当前工作目录：
# 否则在不受信的仓库里执行本脚本，就会 source 对方的 .env（任意 shell 代码）。
# 以裸文件名调用（`bash binup.sh`）时 BASH_SOURCE 没有目录部分，此时脚本目录就是 CWD。
.env() {
	local _d="${BASH_SOURCE[1]:-}"
	# 无调用方文件（交互 shell / bash -c）时不去猜：唯一的候选就是 CWD，那正是要避开的
	[[ -n $_d ]] || return 0
	[[ $_d == */* ]] && _d="${_d%/*}" || _d="."
	[[ -f "$_d/.env" ]] && source "$_d/.env" || true
}
