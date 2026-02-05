#!/usr/bin/env bash

import std/ansi
import std/console

: ${_LOG_USE_EXTRA:=false}
: ${_LOG_LEVEL:=INFO}

declare -gA _LOG_LEVEL_MAP=(
	[DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3
)
declare -gi _LOG_MIN_LEVEL=${_LOG_LEVEL_MAP[$_LOG_LEVEL]}

log.setLevel() {
	local -r level="${1^^}"
	[[ -v "_LOG_LEVEL_MAP[$level]" ]] || return 1
	export _LOG_MIN_LEVEL=${_LOG_LEVEL_MAP[$level]}
	export _LOG_LEVEL="$level"
}

log() {
	local -r level="${1^^}"
	local -r timestamp=$(date +"%m-%d %H:%M:%S ")
	local -r script_name="$(basename "$0")"
	local flag

	case "$level" in
		SUCCESS) flag="$GREEN[$level]$NC" ;;
		INFO) flag="$BLUE[$level]$NC" ;;
		WARN) flag="$YELLOW[$level]$NC" ;;
		ERROR) flag="$RED[$level]$NC" ;;
		DEBUG) flag="$WHITE[$level]$NC" ;;
		*) flag="" ;;
	esac

	[[ -z "$flag" ]] || shift

	local prefix extra=""
	[[ "$_LOG_USE_EXTRA" == true ]] && extra="${BASH_SOURCE[2]##*/}:${BASH_LINENO[0]}"
	[[ -z "$extra" ]] || extra="$WHITE(${extra})$NC"
	prefix="$WHITE$timestamp$NC$flag$extra"
	console.stderr "$prefix $@";
}

log.debug() { (( 0 >= _LOG_MIN_LEVEL )) && log debug "$@"; return 0; }
log.info() { (( 1 >= _LOG_MIN_LEVEL )) && log info "$@"; return 0; }
log.success() { (( 1 >= _LOG_MIN_LEVEL )) && log success "$@"; return 0; }
log.warn() { (( 2 >= _LOG_MIN_LEVEL )) && log warn "$@"; return 0; }
log.error() { (( 3 >= _LOG_MIN_LEVEL )) && log error "$@"; return 0; }
