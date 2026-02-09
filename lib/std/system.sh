#!/usr/bin/env bash

system.command.exist() { command -v "$1" >/dev/null 2>&1; }
system.command.required() { ! system.command.exist "$1" && log.error "This module required \`$1\` command." && exit 1 || true ; }

system.os() {
  [[ ! -z ${_SYSTEM_OS+x} ]] && echo "$_SYSTEM_OS" && return 0
  local -r os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    darwin)  echo "macos" ;;
    linux)   echo "linux" ;;
    mingw*|msys*|cygwin*) echo "windows" ;;
    *)  echo"unknown" ;;
  esac
  log.debug "OS: $os"
}

system.arch() {
  [[ ! -z ${_SYSTEM_ARCH+x} ]] && echo "$_SYSTEM_ARCH" && return 0
  local -r arch="$(uname -m)"
  case "$arch" in
    x86_64|x64|amd64) echo "amd64" ;;
    aarch64|arm64)    echo "arm64" ;;
    armv7l|armhf)     echo "armhf" ;;
    i686|i386|i586)   echo "i386" ;;
  esac
  log.debug "Arch: $arch"
}

system.os.init() { _SYSTEM_OS="$(system.os)"; }
system.arch.init() { _SYSTEM_ARCH="$(system.arch)"; }