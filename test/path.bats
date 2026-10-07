#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	# 先清掉可能的 memo 与覆盖，再用可控的 XDG 路径导入
	unset SCRIPT_CONFIG_DIR SCRIPT_DATA_DIR SCRIPT_STATE_DIR SCRIPT_CACHE_DIR SCRIPT_LOG_DIR SCRIPT_LOCAL_CONFIG_DIR
	export XDG_CONFIG_HOME="/tmp/xdg-config"
	export XDG_DATA_HOME="/tmp/xdg-data"
	export XDG_STATE_HOME="/tmp/xdg-state"
	export XDG_CACHE_HOME="/tmp/xdg-cache"
	import std/path
}

teardown() {
	unset SCRIPT_CONFIG_DIR SCRIPT_DATA_DIR SCRIPT_STATE_DIR SCRIPT_CACHE_DIR SCRIPT_LOG_DIR SCRIPT_LOCAL_CONFIG_DIR
}

# ========== path.script_name ==========

@test "path.script_name - 小写化 SCRIPT_NAME" {
	SCRIPT_NAME="MyApp"
	run path.script_name
	[ "$status" -eq 0 ]
	[ "$output" = "myapp" ]
}

# ========== 默认 XDG 路径 ==========

@test "path.config_dir - 默认 XDG_CONFIG_HOME/<name>" {
	SCRIPT_NAME="myapp"
	run path.config_dir
	[ "$output" = "$XDG_CONFIG_HOME/myapp" ]
}

@test "path.data_dir - 默认 XDG_DATA_HOME/<name>" {
	SCRIPT_NAME="myapp"
	run path.data_dir
	[ "$output" = "$XDG_DATA_HOME/myapp" ]
}

@test "path.state_dir - 默认 XDG_STATE_HOME/<name>" {
	SCRIPT_NAME="myapp"
	run path.state_dir
	[ "$output" = "$XDG_STATE_HOME/myapp" ]
}

@test "path.cache_dir - 默认 XDG_CACHE_HOME/<name>" {
	SCRIPT_NAME="myapp"
	run path.cache_dir
	[ "$output" = "$XDG_CACHE_HOME/myapp" ]
}

@test "path.log_dir - 默认 <state_dir>/logs" {
	SCRIPT_NAME="myapp"
	run path.log_dir
	[ "$output" = "$XDG_STATE_HOME/myapp/logs" ]
}

# ========== 覆盖变量优先 ==========

@test "path.config_dir - 尊重 SCRIPT_CONFIG_DIR" {
	export SCRIPT_CONFIG_DIR="/custom/config"
	run path.config_dir
	[ "$output" = "/custom/config" ]
}

@test "path.data_dir - 尊重 SCRIPT_DATA_DIR" {
	export SCRIPT_DATA_DIR="/custom/data"
	run path.data_dir
	[ "$output" = "/custom/data" ]
}

@test "path.state_dir - 尊重 SCRIPT_STATE_DIR" {
	export SCRIPT_STATE_DIR="/custom/state"
	run path.state_dir
	[ "$output" = "/custom/state" ]
}

@test "path.cache_dir - 尊重 SCRIPT_CACHE_DIR" {
	export SCRIPT_CACHE_DIR="/custom/cache"
	run path.cache_dir
	[ "$output" = "/custom/cache" ]
}

@test "path.log_dir - 尊重 SCRIPT_LOG_DIR" {
	export SCRIPT_LOG_DIR="/custom/logs"
	run path.log_dir
	[ "$output" = "/custom/logs" ]
}
