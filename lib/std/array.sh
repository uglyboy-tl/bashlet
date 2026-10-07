#!/usr/bin/env bash

array.len() {
	local -n ref="$1"
	echo "${#ref[@]}"
}

array.contains() {
	local -n ref="$1"
	local elem
	for elem in "${ref[@]}"; do
		[[ $elem == "$2" ]] && return 0
	done
	return 1
}

array.append() {
	local -n array_ref="$1"
	shift
	array_ref+=("$@")
}

array.get() {
	local -n ref="$1"
	local len=${#ref[@]}
	(($2 >= 0 && $2 < len)) && echo "${ref[$2]}" || return 1
}

array.has_duplicates() {
	local -n ref="$1"
	local -A seen=()
	local elem
	for elem in "${ref[@]}"; do
		# 键统一加前缀 k：bash 不允许空串作关联数组下标（s[""]=1 直接报「数组下标不正确」），
		# 前缀既避开空下标，也不会与字面量 "__EMPTY__" 撞键
		[[ -v "seen[k$elem]" ]] && return 0
		seen["k$elem"]=1
	done
	return 1
}
