#!/usr/bin/env bash

markdown.escape() { echo "${1//|/\\|}"; }

markdown.header() {
  local lvl="${1:-1}"
  shift
  local h
  printf -v h "%*s" "$lvl" ""
  printf "%s %s\n" "${h// /#}" "$*"
}

markdown.h1() { markdown.header 1 "$@"; }
markdown.h2() { markdown.header 2 "$@"; }
markdown.h3() { markdown.header 3 "$@"; }
markdown.h4() { markdown.header 4 "$@"; }
markdown.h5() { markdown.header 5 "$@"; }
markdown.h6() { markdown.header 6 "$@"; }

markdown.list() { for arg in "$@"; do printf -- "- %s\n" "$arg"; done; }

markdown.numbered() {
  local n=1
  for arg in "$@"; do
    printf "%d. %s\n" "$n" "$arg"
    ((n++))
  done
}

markdown.todo() { printf -- "- [ ] %s\n" "${1}"; }

markdown.table.header() {
  local count=0
  for header in "$@"; do
    printf "| %s" "$(markdown.escape "$header")"
    ((count++))
  done
  printf "|\n"
  local i
  for ((i = 0; i < count; i++)); do
    printf "|---"
  done
  printf "|\n"
}

markdown.table.row() {
  for value in "$@"; do
    printf "| %s " "$(markdown.escape "${value:--}")"
  done
  printf "|\n"
}

markdown.code() {
  (($# == 2)) && printf "\`\`\`%s\n%s\n\`\`\`\n" "$1" "$2" || printf "\`\`\`\n%s\n\`\`\`\n" "$1"
}

markdown.line() { printf -- "---\n"; }

markdown.link() { printf "[%s](%s)\n" "${1}" "${2}"; }

markdown.quote() { printf "> %s\n" "${1}"; }

markdown.front_matter() {
  printf -- "---\ntitle: %s\ndate: %s\nauthor: %s\n---\n" "$1" "$(date '+%Y-%m-%d %H:%M:%S')" "${SCRIPT_NAME:-bot}"
}
