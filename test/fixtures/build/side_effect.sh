#!/usr/bin/env bash
set -euo pipefail
SCRIPT_NAME="SideEffect"
# 顶层副作用：如果 build 执行了目标脚本，这个文件就会出现
: > "${SIDE_EFFECT_MARKER:-/tmp/bashlet_build_side_effect}"
