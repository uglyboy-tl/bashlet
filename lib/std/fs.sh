#!/usr/bin/env bash

import std/string

fs.file.exists() { [[ -f $1 ]]; }

fs.dir.exists() { [[ -d $1 ]]; }

fs.write() {
  local _f="$1"
  mkdir -p $(dirname "$1")
  shift
  (($# > 0)) && printf "%s\n" "$@" > "$_f" || : > "$_f"
}

fs.find() { local _n=$(awk -v s="${3:-1}" -v p="$2" 'NR>=s && $0~p{print NR; exit}' "$1" 2> /dev/null) && [[ $_n ]] && echo "$_n" || return 1; }

fs.replace() {
  local _repl=$(string.escape.sed "$3")
  [[ -n ${4:-} ]] && sed -i "${4},/$2/{/$2/{s|.*|$_repl|}}" "$1" || sed -i "/$2/{s|.*|$_repl|}" "$1"
}

fs.insert() { sed -i "/$2/a\\$3" "$1" 2> /dev/null; }

fs.rmline() { [[ -n $4 ]] && sed -i "${4},/$2/{/$2/d}" "$1" 2> /dev/null || sed -i "/$2/d" "$1" 2> /dev/null; }

fs.cleanup() { ls -t ${1}* 2> /dev/null | tail -n +$((${2:-3} + 1)) | xargs -r rm -f; } # 保留最新的 n 个文件 (默认 3 个)

fs.mktemp() { mktemp "$@" 2> /dev/null || { log.error "Failed to create temporary file" && return 1; }; }

fs.file.extract() {
  local path=$(realpath "$1") base=$(basename "$1")
  builtin cd "$2" > /dev/null

  case "${base,,}" in
  *.zip | *.war | *.jar | *.ear | *.sublime-package | *.ipa | *.ipsw | *.xpi | *.apk | *.aar | *.whl | *.vsix | *.crx | *.pk3 | *.pk4) unzip -q "$path" ;;
  *.tar.gz | *.tgz) tar -zxf "$path" ;;
  *.tar.bz2 | *.tbz | *.tbz2 | *.tar.bz) tar -jxf "$path" ;;
  *.tar.xz | *.txz) tar -xJf "$path" ;;
  *.tar) tar -xf "$path" ;;
  *.gz) gzip -dc "$path" > "${base%.gz}" ;;
  *.bz2) bzip2 -dc "$path" > "${base%.bz2}" ;;
  *.xz) xz -dc "$path" > "${base%.xz}" ;;
  *)
    chmod +x "$path"
    cp "$path" "${base%%.*}"
    ;;
  esac
}
