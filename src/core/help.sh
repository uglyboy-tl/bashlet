#!/usr/bin/env bash

import std/bash4
import std/console
import std/ansi
import std/array
import std/map

_SCRIPT_NAME=${0##*/}
: ${_SCRIPT_DISPLAY:-$_SCRIPT_NAME}

# 当前子命令（用于帮助显示）
_ARGS_CURRENT_SUBCOMMAND=""

help.title() {
	local _title="$_SCRIPT_DISPLAY"
	[[ -v _SCRIPT_DESC ]] && _title="$_title - $_SCRIPT_DESC"
	console.stderr "${Bold}${_title}${NC}"
}

help.usage.oneline() {
	local _has_opts=$1
	local _has_args=$2
	local _usage_line="${BRIGHT_BLUE}Usage:${NC} ${BRIGHT_CYAN}$_SCRIPT_NAME $_ARGS_CURRENT_SUBCOMMAND${NC}"

	[[ $_has_opts -gt 0 ]] && _usage_line+=" ${BRIGHT_YELLOW}[OPTIONS]${NC}"
	[[ $_has_args -gt 0 ]] && _usage_line+=" ${BRIGHT_YELLOW}[ARGUMENTS]${NC}"

	console.stderr "$_usage_line"
}

help.usage() {
	local _usage_line="${BRIGHT_BLUE}Usage:${NC} ${BRIGHT_CYAN}$_SCRIPT_NAME${NC}"
	local subcommand="${_ARGS_CURRENT_SUBCOMMAND:-<subcommand>}"
	[[ -n ${1:-} ]] && _usage_line="${_usage_line} ${BRIGHT_MAGENTA}$subcommand${NC}"
	(( ${2:-0} )) && _usage_line="${_usage_line} ${BRIGHT_YELLOW}[OPTIONS]${NC}"
	(( ${3:-0} )) && _usage_line="${_usage_line} ${BRIGHT_YELLOW}[ARGUMENTS]${NC}"

	console.stderr "$_usage_line"
}

help.section() {
	echo ""
	console.stderr "${Bold}${BRIGHT_BLUE}$1${NC}:"
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
		console.align "$_max_width" "  ${BRIGHT_CYAN}$_key${NC}" "${_items_ref[$_key]}"
	done
}

help.footer() {
	[[ ${#_ARGS_SUBCOMMANDS[@]} -eq 0 ]] && return 0
	echo ""
	console.stderr "${BRIGHT_BLACK}Use '${BRIGHT_WHITE}$_SCRIPT_NAME <subcommand> --help${BRIGHT_BLACK}' for subcommand help${NC}"
}

help.show() {
	local -n _opts_ref=$1
	local -n _args_ref=$2
	local -n _examples_ref=$3
	local -n _notices_ref=$4

	help.title
	echo ""
	help.usage $(( ${#_ARGS_SUBCOMMANDS[@]} > 0 )) $(( $(map.len _opts_ref) > 0 )) $(( $(map.len _args_ref) > 0 ))

	[[ $(map.len _opts_ref) -gt 0 ]] && help.section "Options" && help.section.items _opts_ref
	[[ $(map.len _args_ref) -gt 0 ]] && help.section "Arguments" && help.section.items _args_ref
	[[ $(map.len _examples_ref) -gt 0 ]] && help.section "Examples" && help.section.items _examples_ref
	[[ $(map.len _notices_ref) -gt 0 ]] && help.section "Notices" && help.section.items _notices_ref

	# 当子命令变量为空时才显示 footer
	[[ -z $_ARGS_CURRENT_SUBCOMMAND ]] && help.footer
	return 0
}
