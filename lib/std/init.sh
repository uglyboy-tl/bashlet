#!/usr/bin/env bash
[[ $(( BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] )) -lt 403 ]] && { echo "需 Bash 4.3+ 当前 ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}" >&2; exit 1; } || true
.env || true
: ${SCRIPT_NAME:="Demo"}