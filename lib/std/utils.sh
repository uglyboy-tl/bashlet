#!/usr/bin/env bash

utils.func.exist() { declare -f -- "$1" >/dev/null 2>&1; }

utils.func.run() {
  utils.func.exist $1 && { "$1" "${@:2}"; return $?; }
  return 0
}