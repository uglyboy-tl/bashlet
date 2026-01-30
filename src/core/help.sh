#!/usr/bin/env bash

import std/bash4
import std/console
import std/ansi
import std/array

_SCRIPT_NAME=$(basename "$0")

help.name.set() {
	_SCRIPT_NAME=$1
}

help.seccription.set() {
	_SCRIPT_DESC=$1
}

help.title() {
	[[ -v _SCRIPT_DESC ]] && console.stderr "$Bold$_SCRIPT_NAME$NC - $Italics$_SCRIPT_DESC$NC" || console.stderr "$Bold$_SCRIPT_NAME$NC"
	echo ""
}

help.usage() {
	local usage_line="$Bold用法$NC: $Italics$1"

	[[ ${4:-false} == true ]] && usage_line="${usage_line} <子命令>"
	[[ ${2:-false} == true ]] && usage_line="${usage_line} [选项]"
	[[ ${3:-false} == true ]] && usage_line="${usage_line} [位置参数]"

	console.stderr "$usage_line$NC"
}

help.section() {
	echo ""
	console.stderr "$Bold$@$NC:"
}

help.section.items() {
	[[ $(array.type "$1") == "indexed" ]] && help.section.items.array $1 || help.section.items.map $1
}

help.section.items.array() {
	local -n items="$1"
	for item in "${items[@]}"; do
		console.stderr "  $Italics$item$NC"
	done
}

help.section.items.map() {
	local -n items="$1"
	local -a keys=("${!items[@]}")
	local max_width=20

	for key in "${keys[@]}"; do
		(( ${#key} > max_width )) && max_width=${#key}
	done
	(( max_width += 8 ))

	for key in "${keys[@]}"; do
		console.align "$max_width" "  $Italics$key$NC" "$Italics${items[$key]}$NC"
	done
}

help.footer() {
	echo "使用 '$(basename "$0") <子命令> --help' 查看子命令帮助"
}

help.show() {
	local -n script_options=$1
	local -n script_args=$2
	local -n script_examples=$3
	local -n script_notices=$4

	help.title
	help.usage "$(basename "$0")" true true
	[[ $(map.len script_options) -gt 0 ]] && help.section "选项" && help.section.items script_options
	[[ $(map.len script_args) -gt 0 ]] && help.section "参数" &&	help.section.items script_args
	[[ $(map.len script_examples) -gt 0 ]] && help.section "示例" && help.section.items script_examples
	[[ $(array.len script_notices) -gt 0 ]] && help.section "注意" && help.section.items script_notices
}