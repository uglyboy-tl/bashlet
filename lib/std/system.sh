#!/usr/bin/env bash

system.command.exist() { command -v "$1" > /dev/null 2>&1; }
system.command.required() { ! system.command.exist "$1" && log.error "required command not found: $1" && exit 1 || return 0; }

# 是否有图形会话（X11 或 Wayland）
system.gui_supported() { [[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} ]]; }

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
	case "$OSTYPE" in
		darwin*) echo "macos" ;;
		linux*) echo "linux" ;;
		msys* | cygwin*) echo "windows" ;;
		bsd*) echo "bsd" ;;
		solaris*) echo "solaris" ;;
		*) echo "unknown" ;;
	esac
}

# 不做 import 期预计算（原来是 `_SYSTEM_ARCH="$(system.arch)"`）：调用点只有 ext/github，
# 而 26 个 import 者里 24 个从不调用，eager 等于让每个脚本每次启动白付一次 fork（实测 ~2ms）。
# 这里也不做调用期记忆化：调用方都是 `$(system.arch)`，函数内赋值出不了子 shell。
system.arch() {
	local -r arch="$(uname -m)"
	case "$arch" in
		x86_64 | x64 | amd64) echo "amd64" ;;
		aarch64 | arm64) echo "arm64" ;;
		armv7l | armhf) echo "armhf" ;;
		i686 | i386 | i586) echo "i386" ;;
		*) echo "$arch" ;;
	esac
}
