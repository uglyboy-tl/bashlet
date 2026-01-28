#!/usr/bin/env bash

map.len() {
	local -n ref="$1"
	echo "${#ref[@]}"
}

map.contains() {
	local -n ref="$1"
	[[ -v "ref[$2]" ]]
}

map.get() {
	local -n ref="$1"
	[[ -v "ref[$2]" ]] && echo "${ref[$2]}" || return 1
}
