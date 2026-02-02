#!/usr/bin/env bash

import std/bash4
import std/console
import std/ansi
import std/array
import std/map

_SCRIPT_NAME=${0##*/}

help.title() {
	[[ -v _SCRIPT_DESC ]] && console.stderr "$Bold$_SCRIPT_NAME$NC - $Italics$_SCRIPT_DESC$NC" || console.stderr "$Bold$_SCRIPT_NAME$NC"
}

help.usage.oneline() {
	local _has_opts=$1
	local _has_args=$2
	local _usage_line="Usage: $Italics$_SCRIPT_NAME$NC"

	[[ $_has_opts -gt 0 ]] && _usage_line+=" [OPTIONS]"
	[[ $_has_args -gt 0 ]] && _usage_line+=" [ARGUMENTS]"

	console.stderr "$_usage_line"
}

help.usage() {
	local _usage_line="Usage: $Italics$_SCRIPT_NAME"

	[[ -n ${4:-} ]] && _usage_line="${_usage_line} <subcommand>"
	(( ${2:-0} )) && _usage_line="${_usage_line} [OPTIONS]"
	(( ${3:-0} )) && _usage_line="${_usage_line} [ARGUMENTS]"

	console.stderr "$_usage_line$NC"
}

help.section() {
	echo ""
	console.stderr "$Bold$1$NC:"
}

help.section.items() {
	local -n _items_ref="$1"
	local -a _keys=("${!_items_ref[@]}")
	local _max_width=20

	for _key in "${_keys[@]}"; do
		(( ${#_key} > _max_width )) && _max_width=${#_key}
	done
	(( _max_width += 4 ))

	for _key in "${_keys[@]}"; do
		console.align "$_max_width" "  $Bold$_key$NC" "${_items_ref[$_key]}"
	done
}

help.footer() {
	echo ""
	console.stderr "Use '$Italics$_SCRIPT_NAME <subcommand> --help$NC' for subcommand help"
}

help.show() {
	local -n _opts_ref=$1
	local -n _args_ref=$2
	local -n _examples_ref=$3
	local -n _notices_ref=$4

	help.title
	echo ""
	help.usage "" $(( $(map.len _opts_ref) > 0 )) $(( $(map.len _args_ref) > 0 ))

	[[ $(map.len _opts_ref) -gt 0 ]] && help.section "Options" && help.section.items _opts_ref
	[[ $(map.len _args_ref) -gt 0 ]] && help.section "Arguments" && help.section.items _args_ref
	[[ $(map.len _examples_ref) -gt 0 ]] && help.section "Examples" && help.section.items _examples_ref
	[[ $(map.len _notices_ref) -gt 0 ]] && help.section "Notices" && help.section.items _notices_ref

	help.footer
	return 0
}
