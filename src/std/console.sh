#!/usr/bin/env bash

console.stderr() { printf "%s\n" "$*" >&2; }

console.format() {
	local width=$1 text="$2" desc="$3"

	local clean="$text"
	local -r ESC=$'\x1b'
	while [[ $clean =~ ${ESC}\[([0-9;?]+)m ]]; do
		clean="${clean/${BASH_REMATCH[0]}/}"
	done

	local visible_len=${#clean}
	local padding=$(( width - visible_len ))
	(( padding > 0 )) && printf "%s%${padding}s%s\n" "$2" "" "$3" || printf "%s%s\n" "$2" "$3"
} >&2