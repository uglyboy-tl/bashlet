#!/usr/bin/env bash

import std/array
import std/map
import core/log
import core/usage

declare -gA _ARGS_SUBCOMMANDS=()
declare -gA _ARGS_SUBCOMMANDS_DESC=()
declare -ga _ARGS_OPTIONS=()
declare -gA _ARGS_OPTIONS_SWITCH=()
declare -gA _ARGS_OPTIONS_TYPE=()
declare -g _ARGS_CURRENT_SUBCOMMAND=""
declare -gA _ARGS_HELP_OPTIONS=()
declare -gA _ARGS_HELP_ARGS=()
declare -gA _ARGS_HELP_EXAMPLES=()
declare -gA _ARGS_HELP_NOTICES=()

args.name() { usage.name.set "$1"; }

args.description() { usage.description.set "$1" || return 1; }

args.init() {
	_ARGS_OPTIONS=()
	declare -gA _ARGS_OPTIONS_SWITCH=()
	declare -gA _ARGS_OPTIONS_TYPE=()
	declare -gA _ARGS_HELP_OPTIONS=()
	declare -gA _ARGS_HELP_ARGS=()
	declare -gA _ARGS_HELP_EXAMPLES=()
	declare -gA _ARGS_HELP_NOTICES=()
	usage.description.set "${1:-}" || { [[ -n $_ARGS_CURRENT_SUBCOMMAND ]] && usage.description.set "${_ARGS_SUBCOMMANDS_DESC[$_ARGS_CURRENT_SUBCOMMAND]}"; }
	args.add_options "help" "h" "显示帮助信息"
}

args.add_options() {
	local type="${4:-}" key subcommand
	: "${type:="NONE"}"
	[[ -n $_ARGS_CURRENT_SUBCOMMAND ]] && subcommand=" $_ARGS_CURRENT_SUBCOMMAND" || subcommand=""
	case ${1^^} in
		"ARG") [[ -n $2 ]] && _ARGS_HELP_ARGS["$2"]="${3}" && _ARGS_OPTIONS_TYPE["$2"]="${type}" ;;
		"EXAMPLE") _ARGS_HELP_EXAMPLES["$(basename "$0")$subcommand $2"]="${3}" ;;
		"NOTICE") _ARGS_HELP_NOTICES+=(["${2}"]="") ;;
		*)
			_ARGS_OPTIONS_TYPE["$1"]="${type}"
			_ARGS_OPTIONS+=("$1")
			[[ -n $2 ]] && {
				_ARGS_OPTIONS_SWITCH["$1"]="$2"
				_ARGS_OPTIONS_SWITCH["$2"]="$1"
				_ARGS_OPTIONS+=("$2")
			}
			key=""
			[[ -n $2 ]] && key="-$2, "
			key+="--$1"
			[[ -n ${4+x} ]] && key+=" $type"
			_ARGS_HELP_OPTIONS["${key}"]="${3}"
			;;
	esac
}

args.add_subcommand() {
	[[ -n $_ARGS_CURRENT_SUBCOMMAND ]] && return 0
	_ARGS_SUBCOMMANDS["$1"]="$3"
	_ARGS_SUBCOMMANDS_DESC["$1"]="$2"
}

args.dispatch() {
	local cmd="${1:-}"
	[[ -v "_ARGS_SUBCOMMANDS[$cmd]" ]] && {
		local handler="${_ARGS_SUBCOMMANDS[$cmd]}"
		_ARGS_CURRENT_SUBCOMMAND="$cmd"
		shift
		"$handler" "$@"
		exit $?
	}
	return 1
}

args.process() {
	[[ -z $_ARGS_CURRENT_SUBCOMMAND ]] && args.dispatch "$@" && exit 0
	args.parse "$@"
	args.verify || {
		args.show_help
		exit 1
	}
	args.has "-h" "--help" && args.show_help && exit 0 || true
}

args.parse() {
	declare -ga _ARGS_OPTS=()
	declare -ga _ARGS_ARGS=()
	declare -gA _ARGS_OPT_ARGS=()

	local end=0 last=""
	for arg in "$@"; do
		if [[ $arg == '--' ]]; then
			end=1
			last=""
		elif ((!end)) && [[ $arg =~ ^- ]]; then
			if [[ $arg =~ ^-[a-zA-Z]{2,}$ ]]; then
				local c="${arg:1}"
				for ((i = 0; i < ${#c}; i++)); do
					last="-${c:i:1}"
					_ARGS_OPTS+=("$last")
				done
			else
				_ARGS_OPTS+=("$arg")
				last="$arg"
			fi
		else
			_ARGS_ARGS+=("$arg")
			[[ $last ]] && _ARGS_OPT_ARGS["$last"]=$((${#_ARGS_ARGS[@]} - 1)) && last=""
		fi
	done
	return 0
}

args.verify() {
	for option in "${_ARGS_OPTS[@]}"; do
		local opt="${option##*-}" another
		array.contains _ARGS_OPTIONS "$opt" || {
			log.error "未知选项: \"$option\""
			return 1
		}
		array.contains _ARGS_OPTIONS_SWITCH "$opt" && {
			another=${_ARGS_OPTIONS_SWITCH[$opt]}
			args.has "-$another" "--$another" && log.error "重复选项" && return 1
			[[ $option =~ ^-[a-zA-Z]$ ]] && opt=$another
		}
		case ${_ARGS_OPTIONS_TYPE[$opt]} in
			"NONE") unset "_ARGS_OPT_ARGS[$option]" 2> /dev/null || true ;;
			*) [[ -z ${_ARGS_OPT_ARGS[$option]+x} ]] && log.error "选项 $option 需要参数" && return 1 ;;
		esac
	done
	array.has_duplicates _ARGS_OPTS && log.error "重复选项" && return 1
	local -a _ARGS_TEMP_ARGS=("${_ARGS_ARGS[@]}")
	for value in "${_ARGS_OPT_ARGS[@]}"; do
		unset "_ARGS_TEMP_ARGS[$value]"
	done
	declare -ga _ARGS_FINAL_ARGS=("${_ARGS_TEMP_ARGS[@]}")
	[[ $(map.len _ARGS_HELP_ARGS) -eq 0 ]] && [[ $(array.len _ARGS_FINAL_ARGS) -gt 0 ]] && log.error "位置参数错误" && return 1 || true
}

args.has() {
	for o in "$@"; do
		array.contains _ARGS_OPTS "$o" && return 0
	done
	return 1
}

args.get() {
	for o in "$@"; do
		i=$(args.opt.arg_index "$o")
		if [[ $i ]]; then
			args.arg "$i"
			return 0
		fi
	done
	return 1
}

args.args() { echo "_ARGS_FINAL_ARGS"; }

args.arg() { array.get _ARGS_ARGS "$1"; }

args.opt.arg_index() { echo "${_ARGS_OPT_ARGS[$1]:-}"; }

args.show_help() {
	usage.show _ARGS_HELP_OPTIONS _ARGS_HELP_ARGS _ARGS_HELP_EXAMPLES _ARGS_HELP_NOTICES
}
