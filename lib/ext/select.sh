#!/usr/bin/env bash

import std/system
import std/string

FZF_DEFAULT_OPTS="--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC --color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 --color=selected-bg:#45475A --color=border:#6C7086,label:#CDD6F4 --preview-window right:60% --layout=reverse --border --tmux"

select._fzf_single() {
	printf '%s\n' "${@:2}" | fzf --prompt="$1 " --height=10
}

select._fzf_multi() {
	printf '%s\n' "${@:2}" | fzf --prompt="$1 " --height=10 -m --bind 'space:toggle' --bind 'ctrl-a:select-all' --header="✔ Use ↑/↓ to navigate, Space to toggle, Ctrl-A to select all" | paste -sd ' ' -
}

select._native_single() {
	local selected
	local -a options=("${@:2}")
	local -i idx=0
	printf '%s\n' "$1" >&2
	for opt in "${options[@]}"; do
		printf '  [%d] %s\n' "$((idx++))" "$opt" >&2
	done
	printf 'Enter number (0-%d): ' "$((idx - 1))" >&2
	read -r selected
	string.int.check "$selected" && ((selected >= 0 && selected < idx)) && echo "${options[$selected]}" || return 1
}

select._native_multi() {
	local -a options=("${@:2}")
	local -i idx=0
	printf '%s\n' "$1" >&2
	printf '(Enter space-separated numbers, e.g. "0 2 4")\n' >&2
	for opt in "${options[@]}"; do
		printf '  [%d] %s\n' "$((idx++))" "$opt" >&2
	done
	printf 'Enter numbers (0-%d): ' "$((idx - 1))" >&2
	read -r line
	local -a result=()
	for num in $line; do
		string.int.check "$num" && ((num >= 0 && num < idx)) && result+=("${options[$num]}")
	done
	((${#result[@]} > 0)) && printf '%s\n' "${result[*]}" || return 1
}

select.single() { (($# == 1)) && return 1 || system.command.exist "fzf" && ( select._fzf_single "$1" "${@:2}" || true ) || select._native_single "$1" "${@:2}"; }

select.multi() { (($# == 1)) && return 1 || system.command.exist "fzf" && ( select._fzf_multi "$1" "${@:2}" || true ) || select._native_multi "$1" "${@:2}"; }
