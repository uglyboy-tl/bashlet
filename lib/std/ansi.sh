#!/usr/bin/env bash
# shellcheck disable=SC2034
ANSI_ESC=$'\033'
ANSI_CSI="${ANSI_ESC}["

ansi.Color.IsAvailable() {
  local colors
  colors=$(tput colors 2> /dev/null || echo 0)
  [[ $colors -ge 16 ]] && [[ -t 1 ]]
}

ansi.Powerline.IsAvailable() {
  [[ -z ${NO_UNICODE-} ]] && locale -k LC_CTYPE 2> /dev/null | grep -q 'UTF-8'
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

ansi.enable() {
  [[ -n ${_ANSI_FORCE_DISABLE-} ]] && ansi.disable && return 0
  ansi.Color.IsAvailable && ansi.enable.color && ansi.enable.style || { ansi.disable.color && ansi.disable.style; }
  ansi.Powerline.IsAvailable && ansi.enable.powerline || ansi.disable.powerline
}

ansi.disable() {
  ansi.disable.color
  ansi.disable.style
  ansi.disable.powerline
}

ansi.is.initialized() {
  [[ -n ${ANSI_ESC} ]]
}

ansi.enable
