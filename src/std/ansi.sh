#!/usr/bin/env bash

alias ansi.Color.IsAvailable = '[ $(tput colors 2>/dev/null || echo 0) -ge 16 ] && [ -t 1 ]'
alias ansi.Powerline.IsAvailable = "UI.Color.IsAvailable && test -z \${NO_UNICODE-} && (echo -e $'\u1F3B7' | grep -v F3B7) &> /dev/null"

ANSI_ESC=$'\033'
ANSI_CSI="${ANSI_ESC}["

# 特殊字符
ANSI_TAB=$'\t'

# 颜色定义
RED="${ANSI_CSI}31m"
GREEN="${ANSI_CSI}32m"
YELLOW="${ANSI_CSI}33m"
BLUE="${ANSI_CSI}34m"
WHITE="${ANSI_CSI}37m"
NC="${ANSI_CSI}0m"

# 样式定义
Bold="${ANSI_CSI}1m"
Dim="${ANSI_CSI}2m"
Italics="${ANSI_CSI}3m"
Underline="${ANSI_CSI}4m"
Blink="${ANSI_CSI}5m"
Invert="${ANSI_CSI}7m"
Invisible="${ANSI_CSI}8m"
NoBold="${ANSI_CSI}21m"
NoDim="${ANSI_CSI}22m"
NoItalics="${ANSI_CSI}23m"
NoUnderline="${ANSI_CSI}24m"
NoBlink="${ANSI_CSI}25m"
NoInvert="${ANSI_CSI}27m"
NoInvisible="${ANSI_CSI}28m"

# 图标定义