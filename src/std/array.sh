#!/usr/bin/env bash

array.len() { eval 'echo ${#'"$1"'[@]}'; }

array.contains() { eval '[[ " ${'"$1"'[*]} " == *"'" $2 "'"* ]]'; }

array.get() {
  local -r arr="$1" idx="$2"
  local len
  len=$(array.len "$arr")
  (( idx >= 0 && idx < len )) && eval 'echo ${'"$arr"'["'"$idx"'"]}' || return 1
}

array.type() {
  local -r arr="$1"
  local decl
  if ! decl="$(declare -p "$arr" 2>/dev/null)"; then
    echo "error: variable '$arr' does not exist" >&2
    return 1
  fi
  case "$decl" in
    "declare -A"*) echo "associative" ;;
    "declare -a"*) echo "indexed" ;;
    *) return 1 ;;
  esac
}

array.has_duplicates() {
  local -r arr="$1"
  local -A seen=()
  local elem i len key
  len=$(array.len "$arr")
  for ((i=0; i<len; i++)); do
    elem=$(eval 'echo ${'"$arr"'['"$i"']}')
    key="${elem:-__EMPTY__}"
    [[ -v "seen[$key]" ]] && return 0
    seen["$key"]=1
  done
  return 1
}
