#!/usr/bin/env bash

import std/path
import std/system

pass.get() {
	[[ -z $1 || $1 == */* || $1 == *..* ]] && return 1
	local filename="$(path.config_dir)/$1.gpg"
	[[ -f $filename ]] || filename="$(path.local_config_dir)/$1.gpg"
	[[ -f $filename ]] && system.command.exist "gpg" || return 1

	gpg -dq "$filename" 2> /dev/null
}
