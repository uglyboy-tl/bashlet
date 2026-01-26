#!/usr/bin/env bash

import std/bash4.sh
import std/array.sh
import std/map.sh

args.parse() {
  declare -ga _ARGS_OPTS=()
  declare -ga _ARGS_ARGS=()
  declare -gA _ARGS_OPT_ARGS=()

  local end=0 last=""

  for arg in "$@"; do
    if [[ $arg == '--' ]]; then
      end=1
    elif (( !end )) && [[ $arg =~ ^- ]]; then
      if [[ $arg =~ ^-[a-zA-Z]{2,}$ ]]; then
        local i c="${arg:1}"
        for ((i=0; i<${#c}; i++)); do _ARGS_OPTS+=("-${c:i:1}"); done
        last=""
      else
        _ARGS_OPTS+=("$arg")
        last="$arg"
      fi
    else
      _ARGS_ARGS+=("$arg")
      [[ $last ]] && _ARGS_OPT_ARGS["$last"]=$(( ${#_ARGS_ARGS[@]} - 1 )) && last=""
    fi
  done

  args.verify
}

args.verify() {
  local -A seen=()
  for opt in "${_ARGS_OPTS[@]}"; do
    map.contains seen "$opt" && return 1
    seen["$opt"]=1
  done
}

args.has() { array.contains _ARGS_OPTS "$1"; }

args.opt_index() { echo "${_ARGS_OPT_ARGS[$1]:-}"; }

args.arg() { array.get _ARGS_ARGS "$1"; }

args.count() { array.len _ARGS_ARGS; }

args.get() {
  local -r idx=$(args.opt_index "$1")
  [[ $idx ]] && args.arg "$idx"
}
