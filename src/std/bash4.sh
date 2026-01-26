#!/usr/bin/env bash

[[ ${BASH_VERSINFO[0]} -lt 4 ]] && echo "需 Bash 4+ 当前 ${BASH_VERSINFO[0]}" >&2 && exit 1 || true