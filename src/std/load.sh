#!/usr/bin/env bash
readonly _LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../ && pwd)"

declare -p __loaded_modules &>/dev/null 2>&1 && return 0
declare -gA __loaded_modules=("$_LIB_DIR/std/load.sh")

source() {
    local mod="$1"

    [[ "$mod" == */* ]] || mod="$PWD/$mod"
    [[ "$mod" == /* ]] || mod="$(cd "${mod%/*}" && pwd)/${mod##*/}"

    [[ -n "${__loaded_modules[$mod]+x}" ]] && return 0
    . "$1" || return $?
    __loaded_modules["$mod"]=1
}

load() {
    local mod="$1"
    [[ "$mod" == /* ]] || mod="$_LIB_DIR/$mod"
    source "$mod"
}