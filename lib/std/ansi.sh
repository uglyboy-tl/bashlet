#!/usr/bin/env bash
# shellcheck disable=SC2034
# 颜色与样式转义码。powerline/Unicode 字形表在 std/ansi.powerline（按需 import，底座不背）。
ANSI_ESC=$'\033'
ANSI_CSI="${ANSI_ESC}["

ansi.Color.IsAvailable() {
	# 非 tty 直接否定，避免无谓的 tput 子进程
	[[ -t 1 ]] || return 1
	local colors
	colors=$(tput colors 2> /dev/null || echo 0)
	[[ $colors -ge 16 ]]
}

ansi.enable.color() {
	BLACK="${ANSI_CSI}30m"
	RED="${ANSI_CSI}31m"
	GREEN="${ANSI_CSI}32m"
	YELLOW="${ANSI_CSI}33m"
	BLUE="${ANSI_CSI}34m"
	MAGENTA="${ANSI_CSI}35m"
	CYAN="${ANSI_CSI}36m"
	WHITE="${ANSI_CSI}37m"

	BRIGHT_BLACK="${ANSI_CSI}90m"
	BRIGHT_RED="${ANSI_CSI}91m"
	BRIGHT_GREEN="${ANSI_CSI}92m"
	BRIGHT_YELLOW="${ANSI_CSI}93m"
	BRIGHT_BLUE="${ANSI_CSI}94m"
	BRIGHT_MAGENTA="${ANSI_CSI}95m"
	BRIGHT_CYAN="${ANSI_CSI}96m"
	BRIGHT_WHITE="${ANSI_CSI}97m"

	NC="${ANSI_CSI}0m"
	NO_COLOR="${ANSI_CSI}0m"
}

ansi.disable.color() {
	BLACK=""
	RED=""
	GREEN=""
	YELLOW=""
	BLUE=""
	MAGENTA=""
	CYAN=""
	WHITE=""

	BRIGHT_BLACK=""
	BRIGHT_RED=""
	BRIGHT_GREEN=""
	BRIGHT_YELLOW=""
	BRIGHT_BLUE=""
	BRIGHT_MAGENTA=""
	BRIGHT_CYAN=""
	BRIGHT_WHITE=""

	NC=""
	NO_COLOR=""
}

ansi.enable.style() {
	Bold="${ANSI_CSI}1m"
	Dim="${ANSI_CSI}2m"
	Italics="${ANSI_CSI}3m"
	Underline="${ANSI_CSI}4m"
	Blink="${ANSI_CSI}5m"
	Reverse="${ANSI_CSI}7m"
	Hidden="${ANSI_CSI}8m"
	Strike="${ANSI_CSI}9m"

	NoBold="${ANSI_CSI}21m"
	NoDim="${ANSI_CSI}22m"
	NoItalics="${ANSI_CSI}23m"
	NoUnderline="${ANSI_CSI}24m"
	NoBlink="${ANSI_CSI}25m"
	NoReverse="${ANSI_CSI}27m"
	NoHidden="${ANSI_CSI}28m"
	NoStrike="${ANSI_CSI}29m"
}

ansi.disable.style() {
	Bold=""
	Dim=""
	Italics=""
	Underline=""
	Blink=""
	Reverse=""
	Hidden=""
	Strike=""

	NoBold=""
	NoDim=""
	NoItalics=""
	NoUnderline=""
	NoBlink=""
	NoReverse=""
	NoHidden=""
	NoStrike=""
}

ansi.enable() {
	[[ -n ${_ANSI_FORCE_DISABLE-} ]] && ansi.disable && return 0
	ansi.Color.IsAvailable && ansi.enable.color && ansi.enable.style || { ansi.disable.color && ansi.disable.style; }
}

ansi.disable() {
	ansi.disable.color
	ansi.disable.style
}

ansi.enable
