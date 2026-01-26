#!/usr/bin/env bash

map.len() { eval 'echo ${#'"$1"'[@]}'; }

map.contains() { eval '[[ -v '"$1"'["'"$2"'"] ]]'; }

map.get() {
  local -r arr="$1" idx="$2"
  eval '[[ -v '"$arr"'["'"$idx"'"] ]]' && eval 'echo ${'"$arr"'["'"$idx"'"]}' || return 1
}
