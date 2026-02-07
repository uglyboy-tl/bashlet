#!/usr/bin/env bash

fs.file.exists() { [[ -f "$1" ]]; }

fs.dir.exists() { [[ -d "$1" ]]; }

fs.write() {
	local _f="$1"
	shift
	(($# > 0)) && printf "%s\n" "$@" >"$_f" || : >"$_f"
}

fs.grep() {
	grep -q "$2" "$1" 2>/dev/null || return 1
}

fs.replace() {
	sed -i "0,/$2/s/$2/$3/" "$1" 2>/dev/null
}

fs.insert() {
	sed -i "/$2/a\\$3" "$1" 2>/dev/null
}
