#!/usr/bin/env bash

import std/bash4
import std/console
import std/ansi

: ${_LOG_USE_EXTRA:=false}

log() {
	local -r level="${1^^}"
	local -r timestamp=$(date +"%m-%d %H:%M:%S ")
	local -r script_name="$(basename "$0")"

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
	[[ "$_LOG_USE_EXTRA" = true ]] && extra="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}"
	[[ -z "$extra" ]] || extra="$WHITE(${extra})$NC"
	prefix="$WHITE$timestamp$NC$flag$extra"
	console.stderr "$prefix $@";
}

log.debug() { log debug $@; }
log.info() { log info $@; }
log.warn() { log warn $@; }
log.error() { log error $@; }
log.success() { log success $@; }
