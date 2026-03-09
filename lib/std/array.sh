#!/usr/bin/env bash

array.len() {
  local -n ref="$1"
  echo "${#ref[@]}"
}

array.contains() {
  local -n ref="$1"
  if (( ${#ref[@]} <= 3 )); then
    [[ " ${ref[*]} " == *" $2 "* ]]
  else
    local -A lookup=()
    for elem in "${ref[@]}"; do
      lookup["$elem"]=1
    done
    [[ -v "lookup[$2]" ]]
  fi
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

array.type() {
  local -r arr="$1"
  local decl
  decl="$(declare -p "$arr" 2> /dev/null)" || return 1
  case "$decl" in
  "declare -A"*) echo "associative" ;;
  "declare -a"*) echo "indexed" ;;
  *) return 1 ;;
  esac
}

array.has_duplicates() {
  local -n ref="$1"
  local -A seen=()
  local elem key
  for elem in "${ref[@]}"; do
    key="${elem:-__EMPTY__}"
    [[ -v "seen[$key]" ]] && return 0
    seen["$key"]=1
  done
  return 1
}
