#!/usr/bin/env bash

import std/markdown
import std/system
import std/fs
import std/console
import core/log

declare -g _REPORT_DIR=""
declare -g _REPORT_SECTION_NUM=1
declare -ga _REPORT_CONTENT=()

report.dir.set() { _REPORT_DIR=$1; }
report.reset() { _REPORT_CONTENT=(); }

# 报告输出函数
report.init() {
  report.reset
  _REPORT_CONTENT+=("$(markdown.front_matter "$1")" "" "$(markdown.h1 "$1")" "")
}

report.section() {
  _REPORT_CONTENT+=("$(markdown.h2 "$_REPORT_SECTION_NUM. $*")" "")
  ((_REPORT_SECTION_NUM++))
}

report.subsection() {
  _REPORT_CONTENT+=("$(markdown.h3 "$1")")
}

report.code() {
  _REPORT_CONTENT+=("$(markdown.code "bash" "$1")" "$(system.command.result "$1")" "")
}

report.table.begin() {
  _REPORT_CONTENT+=("$(markdown.table.header "$@")")
}

report.table.add() {
  _REPORT_CONTENT+=("$(markdown.table.row "$@")")
}

report.table.end() {
  _REPORT_CONTENT+=("")
}

report.export() {
  local report_file=${1:-$_REPORT_DIR/$(date +%Y%m%d_%H%M%S).md}
  fs.write "$report_file" "${_REPORT_CONTENT[@]}"
  chmod 644 "$report_file" 2> /dev/null || true
  printf "%s\n" "$report_file"
}
