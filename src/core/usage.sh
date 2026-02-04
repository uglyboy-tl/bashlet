#!/usr/bin/env bash

import std/ansi
import std/console
import std/map

_USAGE_SCRIPT_FILENAME=${0##*/}
: ${_USAGE_SCRIPT_NAME:=$_USAGE_SCRIPT_FILENAME}
_USAGE_SCRIPT_DESC=""

usage.name.set() { _USAGE_SCRIPT_NAME="$1"; }

usage.description.set() { [[ -n "$1" ]] && _USAGE_SCRIPT_DESC="$1"; }

usage.title() {
	local _title="$_USAGE_SCRIPT_NAME"
	[[ -n $_ARGS_CURRENT_SUBCOMMAND ]] && _title="$_title - $_ARGS_CURRENT_SUBCOMMAND"
	[[ -n $_USAGE_SCRIPT_DESC ]] && _title="$_title - $_USAGE_SCRIPT_DESC"
	console.stderr "${Bold}${_title}${NC}"
}

usage.usage() {
	local _usage_line="${BRIGHT_BLUE}Usage:${NC} ${BRIGHT_CYAN}$_USAGE_SCRIPT_FILENAME${NC}"
	local subcommand="${_ARGS_CURRENT_SUBCOMMAND:-<subcommand>}"
	(( ${1:-0} )) && _usage_line="${_usage_line} ${BRIGHT_MAGENTA}$subcommand${NC}"
	(( ${2:-0} )) && _usage_line="${_usage_line} ${BRIGHT_YELLOW}[OPTIONS]${NC}"
	(( ${3:-0} )) && _usage_line="${_usage_line} ${BRIGHT_YELLOW}[ARGUMENTS]${NC}"

	console.stderr "$_usage_line"
}

usage.section() {
	echo ""
	console.stderr "${Bold}${BRIGHT_BLUE}$1${NC}:"
}

usage.section.items() {
	local -n _items_ref="$1"
	local -a _keys=("${!_items_ref[@]}")
	local _max_width=20

	for _key in "${_keys[@]}"; do
		(( ${#_key} > _max_width )) && _max_width=${#_key}
	done
	(( _max_width += 4 ))

	for _key in "${_keys[@]}"; do
		console.align "$_max_width" "  ${BRIGHT_CYAN}$_key${NC}" "${_items_ref[$_key]}"
	done
}

usage.footer() {
	[[ ${#_ARGS_SUBCOMMANDS[@]} -eq 0 ]] && return 0
	echo ""
	console.stderr "${BRIGHT_BLACK}Use '${BRIGHT_WHITE}$_USAGE_SCRIPT_FILENAME <subcommand> --help${BRIGHT_BLACK}' for subcommand help${NC}"
}

usage.show() {
	local -n _opts_ref=$1
	local -n _args_ref=$2
	local -n _examples_ref=$3
	local -n _notices_ref=$4
	local -n _cmd_ref="_ARGS_CURRENT_SUBCOMMAND"
	local -n _cmd_desc_ref="_ARGS_SUBCOMMANDS_DESC"

	echo ""
	usage.title
	echo ""
	usage.usage $(( $(map.len _cmd_desc_ref) > 0 )) $(( $(map.len _opts_ref) > 0 )) $(( $(map.len _args_ref) > 0 ))

	[[ -z $_cmd_ref  ]] && [[ $(map.len _cmd_desc_ref) -gt 0 ]] && usage.section "Commands" && usage.section.items _cmd_desc_ref
	[[ $(map.len _opts_ref) -gt 0 ]] && usage.section "Options" && usage.section.items _opts_ref
	[[ $(map.len _args_ref) -gt 0 ]] && usage.section "Arguments" && usage.section.items _args_ref
	[[ $(map.len _examples_ref) -gt 0 ]] && usage.section "Examples" && usage.section.items _examples_ref
	[[ $(map.len _notices_ref) -gt 0 ]] && usage.section "Notices" && usage.section.items _notices_ref

	# 当子命令变量为空时才显示 footer
	[[ -z $_cmd_ref ]] && usage.footer
	return 0
}
