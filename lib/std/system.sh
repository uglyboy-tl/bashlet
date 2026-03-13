#!/usr/bin/env bash

system.command.exist() { command -v "$1" > /dev/null 2>&1; }
system.command.required() { ! system.command.exist "$1" && log.error "This module required \`$1\` command." && exit 1 || return 0; }

system.command.result() {
	local result
	result=$(eval "$1" 2>&1) || {
		# 检查是否是 grep 无匹配（退出码 1）
		local exit_code=$?
		if [[ $exit_code -eq 1 ]] && [[ $1 == *grep* ]]; then
			result=""
		else
			result="（命令执行失败，退出码: $exit_code）"
		fi
	}

	# 如果结果为空，显示提示
	[[ -z $result ]] && result="（无输出）"

	echo "$result"
}

system.os() {
	[[ -n ${_SYSTEM_OS+x} ]] && echo "$_SYSTEM_OS" && return 0
	case "$OSTYPE" in
		darwin*) echo "macos" ;;
		linux*) echo "linux" ;;
		msys* | cygwin*) echo "windows" ;;
		bsd*) echo "bsd" ;;
		solaris*) echo "solaris" ;;
		*) echo"unknown" ;;
	esac
}
_SYSTEM_OS="$(system.os)"

system.arch() {
	[[ -n ${_SYSTEM_ARCH+x} ]] && echo "$_SYSTEM_ARCH" && return 0
	local -r arch="$(uname -m)"
	case "$arch" in
		x86_64 | x64 | amd64) echo "amd64" ;;
		aarch64 | arm64) echo "arm64" ;;
		armv7l | armhf) echo "armhf" ;;
		i686 | i386 | i586) echo "i386" ;;
	esac
}
_SYSTEM_ARCH="$(system.arch)"
