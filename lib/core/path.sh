#!/usr/bin/env bash
# path.sh - 提供脚本专用的各类路径

: ${XDG_CONFIG_HOME:=$HOME/.config}
: ${XDG_DATA_HOME:=$HOME/.local/share}
: ${XDG_STATE_HOME:=$HOME/.local/state}
: ${XDG_CACHE_HOME:=$HOME/.cache}

path.script_name() {
	echo "${SCRIPT_NAME,,}"
}

path.config_dir() {
	: ${SCRIPT_CONFIG_DIR:=$XDG_CONFIG_HOME/$(path.script_name)}
	echo "$SCRIPT_CONFIG_DIR"
}

path.data_dir() {
	: ${SCRIPT_DATA_DIR:=$XDG_DATA_HOME/$(path.script_name)}
	echo "$SCRIPT_DATA_DIR"
}

path.state_dir() {
	: ${SCRIPT_STATE_DIR:=$XDG_STATE_HOME/$(path.script_name)}
	echo "$SCRIPT_STATE_DIR"
}

path.cache_dir() {
	: ${SCRIPT_CACHE_DIR:=$XDG_CACHE_HOME/$(path.script_name)}
	echo "$SCRIPT_CACHE_DIR"
}

path.log_dir() {
	: ${SCRIPT_LOG_DIR:=$(path.state_dir)/log}
	echo "$SCRIPT_LOG_DIR"
}
