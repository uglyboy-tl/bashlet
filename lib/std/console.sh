#!/usr/bin/env bash

import std/string

console.stdout() { printf "%s\n" "$*"; }

console.repeat() {
  local -a line
  local i=1
  while true; do
    [[ $i -gt ${2:-0} ]] && break
    line+=("$1")
    i=$((i + 1))
  done
  printf "%s" "${line[@]}"
}

console.stderr() { printf "%s\n" "$*" >&2; }

console.align() {
	local padding=$(( $1 - $(console.display_width "$2") ))
	(( padding > 0 )) && printf "%s%${padding}s%s\n" "$2" "" "${*:3}" || printf "%s%s\n" "$2" "${*:3}"
} >&2

console.ansi_width() {
	local width=0 i=0 len=${#1} flag=0
	while (( i < len )); do
		local char="${1:$((i++)):1}"
		(( flag )) && { [[ $char =~ [a-zA-Z] ]] && flag=0; continue; }
		[[ $char == $'\x1b' ]] && flag=1 && continue
		((width++))
	done
	echo "$width"
}

console.mixed_width() {
	local width=0 flag=0 i=0
	local hex_bytes=$(printf "%s" "$1" | od -An -tx1 -v | tr -d ' \n')
	local len=${#hex_bytes}
	while (( i < len )); do
		local num=$((0x${hex_bytes:$i:2}))
		i=$((i+2))
		(( flag )) && { (( (num >= 0x41 && num <= 0x5A) || (num >= 0x61 && num <= 0x7A) )) && flag=0; continue; }
		(( num == 0x1b )) && { flag=1; continue; }
		(( num <= 0x7F )) && { ((width++)); continue; }
		(( num >= 0xC2 && num <= 0xDF )) && { ((width++)); i=$((i+2)); continue; }
		(( num >= 0xE0 && num <= 0xEF )) && { ((width+=2)); i=$((i+4)); continue; }
		(( num >= 0xF0 && num <= 0xF7 )) && { ((width+=2)); i=$((i+6)); }
	done
	echo "$width"
}

console.display_width() {
	[[ $1 ]] || { echo "0"; return; }
	! string.is_ascii "$1" && console.mixed_width "$1" && return
	string.has_ansi "$1" && console.ansi_width "$1" || echo "${#1}"
}