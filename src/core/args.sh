#!/usr/bin/env bash

import std/bash4
import std/map
import core/log
import core/help

args.new_options() {
	local prefix="_ARGS_${1^^}"
	# TODO: 增加 $1 无空格的判断
	_ARGS_CURRENT_OPTIONS="$prefix"

	eval "declare -ga ${prefix}_OPTIONS"
	eval "declare -gA ${prefix}_OPTIONS_SWITCH"
	eval "declare -gA ${prefix}_OPTIONS_TYPE"
	eval "declare -gA ${prefix}_HELP_OPTIONS"
	eval "declare -gA ${prefix}_HELP_ARGS"
	eval "declare -gA ${prefix}_HELP_EXAMPLES"
	eval "declare -gA ${prefix}_HELP_NOTICES"

	args.add_options "help" "h" "显示帮助信息"
}

args.add_options() {
	# 输入顺序是：`选项，短选项，描述，类型` 或 `arg，参数，描述，类型`
	local type="${4:-}"
	local -r prefix="$_ARGS_CURRENT_OPTIONS"

	: ${type:="NONE"}
	case ${1^^} in
		"ARG") [[ -n "$2" ]] && eval "${prefix}_HELP_ARGS[\"$2\"]=\"${3}\"" && eval "${prefix}_OPTIONS_TYPE[\"$2\"]=\"${type}\"" ;;
		"EXAMPLE") eval "${prefix}_HELP_EXAMPLES[\"$(basename "$0") $2\"]=\"${3}\"" ;;
		"NOTICE") eval "${prefix}_HELP_NOTICES+=(\"${2}\")" ;;
		* )
			# TODO: 考虑是否需要对参数为空的情况进行提示
			eval "${prefix}_OPTIONS_TYPE[\"$1\"]=\"${type}\""
			eval "${prefix}_OPTIONS+=(\"$1\")"

			[[ -n "$2" ]] && {
				eval "${prefix}_OPTIONS_SWITCH[\"$1\"]=\"$2\""
				eval "${prefix}_OPTIONS_SWITCH[\"$2\"]=\"$1\""
				eval "${prefix}_OPTIONS+=(\"$2\")"
			}

			key=""
			[[ -n $2 ]] && key="-$2, "
			key+="--$1"
			[[ ! -z ${4+x} ]] && key+=" $type"
			eval "${prefix}_HELP_OPTIONS[\"${key}\"]=\"${3}\""
			;;
	esac
}

args.add_subcommand() {
	local -r command="$1"
	local -r description="$2"
	local -r handler="$3"
}

args.parse() {
	declare -ga _ARGS_OPTS=();
	declare -ga _ARGS_ARGS=();
	declare -gA _ARGS_OPT_ARGS=();

	local end=0 last=""

	for arg in "$@"; do
		if [[ $arg == '--' ]]; then
			end=1
			last=""
		elif (( !end )) && [[ $arg =~ ^- ]]; then
			if [[ $arg =~ ^-[a-zA-Z]{2,}$ ]]; then
				local i c="${arg:1}"
				for ((i=0; i<${#c}; i++)); do last="-${c:i:1}";_ARGS_OPTS+=("$last"); done
			else
				_ARGS_OPTS+=("$arg")
				last="$arg"
			fi
		else
			_ARGS_ARGS+=("$arg")
			[[ $last ]] && _ARGS_OPT_ARGS["$last"]=$(( ${#_ARGS_ARGS[@]} - 1 )) && last=""
		fi
	done

	return 0
}

args.verify() {
	local -n switch=$(args.options_switch)
	local -n types=$(args.options_type)
	local -n valid_options=$(args.options)
	for o in "${_ARGS_OPTS[@]}"; do
		local opt="${o##*-}"
		array.contains valid_options $opt || { log.error "未知选项: \"$o\""; return 1; }
		local another=${switch[$opt]}
		args.has "-$another" "--$another" && log.error "重复选项" && return 1
		[[ $o =~ ^-[a-zA-Z]$ ]] && opt=$another
		case ${types[$opt]} in
			"NONE") unset _ARGS_OPT_ARGS[$o] ;;
			*) [[ -z ${_ARGS_OPT_ARGS[$o]+x} ]] && log.error "选项 $o 需要参数" && return 1 ;;
		esac
	done
	array.has_duplicates _ARGS_OPTS && log.error "重复选项" && return 1
	declare -ga _ARGS_FINAL_ARGS=("${_ARGS_ARGS[@]}")
	for value in "${_ARGS_OPT_ARGS[@]}"; do
		unset _ARGS_FINAL_ARGS[$value]
	done
}

args.has() {
	local o
	for o in "$@"; do
		array.contains _ARGS_OPTS "$o" && return 0
	done
	return 1
}

args.get() {
	local -r i=$(args.opt_index "$1")
	[[ $i ]] && args.arg "$i"
}

args.args() { echo "_ARGS_FINAL_ARGS"; }

args.count() { array.len _ARGS_ARGS; }

args.arg() { array.get _ARGS_ARGS "$1"; }

args.opt_index() { echo "${_ARGS_OPT_ARGS[$1]:-}"; }

args.options() {
	echo "${_ARGS_CURRENT_OPTIONS}_OPTIONS"
}

args.options_switch() {
	echo "${_ARGS_CURRENT_OPTIONS}_OPTIONS_SWITCH"
}

args.options_type() {
	echo "${_ARGS_CURRENT_OPTIONS}_OPTIONS_TYPE"
}

args.help_options() {
	echo "${_ARGS_CURRENT_OPTIONS}_HELP_OPTIONS"
}

args.help_args() {
	echo "${_ARGS_CURRENT_OPTIONS}_HELP_ARGS"
}

args.help_examples() {
	echo "${_ARGS_CURRENT_OPTIONS}_HELP_EXAMPLES"
}

args.help_notices() {
	echo "${_ARGS_CURRENT_OPTIONS}_HELP_NOTICES"
}

args.show_help() {
	help.show $(args.help_options) $(args.help_args) $(args.help_examples) $(args.help_notices)
}

args.debug_options() {
	log.debug "$(declare -p $(args.options))"
	log.debug "$(declare -p $(args.options_switch))"
	log.debug "$(declare -p $(args.options_type))"
	log.debug "$(declare -p $(args.help_options))"
	log.debug "$(declare -p $(args.help_args))"
	log.debug "$(declare -p $(args.help_examples))"
	log.debug "$(declare -p $(args.help_notices))"
}
