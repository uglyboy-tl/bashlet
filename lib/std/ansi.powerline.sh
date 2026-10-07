#!/usr/bin/env bash
# shellcheck disable=SC2034
# powerline/Unicode 字形表。与 std/ansi 分开的原因：底座（core/log、core/usage）只需要颜色与样式，
# 把字形表拉给每个脚本等于让所有产物白背 ~1.3KB；需要 POWERLINE_* 的脚本显式 import 本模块。
import std/ansi

ansi.Powerline.IsAvailable() {
	[[ -n ${NO_UNICODE-} ]] && return 1
	# locale 环境已表明 UTF-8 时免去 locale|grep 两个子进程
	local lc="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
	[[ $lc == *UTF-8* || $lc == *utf8* ]] && return 0
	locale -k LC_CTYPE 2> /dev/null | grep -q 'UTF-8'
}

ansi.enable.powerline() {
	POWERLINE_SEPARATOR=$'\ue0b0'
	POWERLINE_SEPARATOR_THIN=$'\ue0b1'
	POWERLINE_SEPARATOR_LEFT=$'\ue0b2'
	POWERLINE_SEPARATOR_LEFT_THIN=$'\ue0b3'
	POWERLINE_BRANCH=$'\ue0a0'
	POWERLINE_LINE=$'\ue0a1'
	POWERLINE_READONLY=$'\ue0a2'

	POWERLINE_POINTING_ARROW=$'\u27a1'
	POWERLINE_ARROW_RIGHT=$'\u25b6'
	POWERLINE_ARROW_LEFT=$'\u25c0'
	POWERLINE_ARROW_DOWN=$'\u2b07'
	POWERLINE_ARROW_RIGHT_DOWN=$'\u2b0a'
	POWERLINE_PLUS_MINUS=$'\u00b1'
	POWERLINE_REFERS_TO=$'\u27a6'
	POWERLINE_OK=$'\u2714'
	POWERLINE_FAIL=$'\u2718'
	POWERLINE_WARN=$'\u26a0'
	POWERLINE_COG=$'\u2699'
	POWERLINE_HEART=$'\u2764'
	POWERLINE_STAR=$'\u2605'
}

ansi.disable.powerline() {
	POWERLINE_SEPARATOR=">"
	POWERLINE_SEPARATOR_THIN=">"
	POWERLINE_SEPARATOR_LEFT="<"
	POWERLINE_SEPARATOR_LEFT_THIN="<"
	POWERLINE_BRANCH="|}"
	POWERLINE_LINE="LN"
	POWERLINE_READONLY="RO"

	POWERLINE_POINTING_ARROW="~"
	POWERLINE_ARROW_RIGHT="->"
	POWERLINE_ARROW_LEFT="<-"
	POWERLINE_ARROW_DOWN="_"
	POWERLINE_ARROW_RIGHT_DOWN=">"
	POWERLINE_PLUS_MINUS="+-"
	POWERLINE_REFERS_TO="*"
	POWERLINE_OK="+"
	POWERLINE_FAIL="x"
	POWERLINE_WARN="!"
	POWERLINE_COG="{*}"
	POWERLINE_HEART="<3"
	POWERLINE_STAR="*"
}

# import 期就绪，与 std/ansi 的颜色/样式一样：不支持或显式禁止时降级成 ASCII 回退
if [[ -z ${_ANSI_FORCE_DISABLE-} ]] && ansi.Powerline.IsAvailable; then
	ansi.enable.powerline
else
	ansi.disable.powerline
fi
