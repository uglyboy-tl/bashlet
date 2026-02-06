#!/usr/bin/env bash

fs.file.exists() { [[ -f "$1" ]] }

fs.dir.exists() { [[ -d "$1" ]] }

fs.write() { local _f="$1"; shift; (($# > 0)) && printf "%s\n" "$@" > "$_f" || : > "$_f"; }
