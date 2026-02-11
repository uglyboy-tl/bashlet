#!/usr/bin/env bash

# Base64 编码解码
string.base64.encode() { base64 -w 0 "$1" 2>/dev/null || base64 "$1" 2>/dev/null; }

string.base64.decode() { base64 -d 2>/dev/null || base64 -D 2>/dev/null; }

# 字符串转义
string.escape.regex() { printf '%s' "${1:-}" | sed 's/[].[\\^$*+?{}()|]/\\&/g; s/\//\\\//g'; }

string.escape.sed() { printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/&/\\&/g; s/|/\\|/g'; }

string.trim() {
	local s="${1#"${1%%[![:space:]]*}"}"
	echo "${s%"${s##*[![:space:]]}"}"
}

string.int.check() { [[ "$1" =~ ^-?[0-9]+$ ]]; }

string.natural.check() { [[ "$1" =~ ^[1-9][0-9]*$ ]]; }

string.float.check() { [[ "$1" =~ ^-?[0-9]+\.[0-9]+$ ]]; }

string.is_ascii() { [[ $1 != *[![:ascii:]]* ]]; }

string.has_ansi() { [[ $1 == *$'\x1b'* ]]; }
