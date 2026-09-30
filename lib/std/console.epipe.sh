#!/usr/bin/env bash

import std/path

# 非交互场景下的输出安全（借鉴 dotfiles/settings 的 epipe_init）：
# 从快捷键守护进程/无终端环境启动时，stdout 可能是 socket 或无读方的管道，
# 直接写会因 EPIPE 在 set -e 下中断整个脚本。本模块：
#   1. 忽略 SIGPIPE（trap '' PIPE）；
#   2. stdout 是管道/socket（无终端）时，把 stdout/stderr 追加到日志文件。
# 显式重定向到普通文件（`> file`）或设 CONSOLE_EPIPE_KEEP_STDOUT=1 时不处理。
# 交互结果若经命令替换返回，不受重定向影响。
#
# 用法（脚本顶部，变量定义之后）：
#   console.epipe.init                # 默认: $(path.log_dir)/<脚本名>.log
#   console.epipe.init /path/to.log   # 指定日志文件
console.epipe.init() {
	trap '' PIPE
	[[ -t 1 ]] && return 0
	[[ -n ${CONSOLE_EPIPE_KEEP_STDOUT:-} ]] && return 0
	# 显式重定向到普通文件（`> file`）时尊重调用方，不劫持
	[[ -f /dev/stdout ]] && return 0
	local log="${1:-$(path.log_dir)/${0##*/}.log}"
	[[ $log == */* ]] && mkdir -p "${log%/*}"
	exec >> "$log" 2>&1
}
