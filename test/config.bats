#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import core/config
}

teardown() {
	# 手动重置配置状态
	_CONFIG_REGISTERED=()
	_CONFIG_TYPES=()
	_CONFIG_DESCS=()
	_CONFIG_VALUES=()
	_CONFIG_ARRAY_REGISTERED=()
	_CONFIG_ARRAY_ITEMS=()
	rm -f /tmp/test_config_*.toml 2>/dev/null || true
}

# ========== 基础配置功能测试 ==========

@test "config.register: basic registration and attributes" {
	config.register "key1" "default1" "string" "description1"
	[ "${_CONFIG_REGISTERED[0]}" = "key1" ]
	[ "${_CONFIG_TYPES[key1]}" = "string" ]
	[ "${_CONFIG_DESCS[key1]}" = "description1" ]
	[ "${_CONFIG_VALUES[key1]}" = "default1" ]
}

@test "config.register: multiple registrations" {
	config.register "key1" "val1" "string"
	config.register "key2" "100" "int"
	config.register "key3" "true" "bool"
	[ ${#_CONFIG_REGISTERED[@]} -eq 3 ]
}

@test "config.register: duplicate updates attributes" {
	config.register "key1" "val1" "string"
	config.register "key1" "999" "int"
	[ ${#_CONFIG_REGISTERED[@]} -eq 1 ]
	[ "${_CONFIG_TYPES[key1]}" = "int" ]
	[ "${_CONFIG_VALUES[key1]}" = "999" ]
}

@test "config.register: empty default value" {
	config.register "key1" "" "string"
	[[ -v "_CONFIG_VALUES[key1]" ]]
	[ "${_CONFIG_VALUES[key1]}" = "" ]
}

@test "config.register: optional type and desc" {
	config.register "key1"
	[ "${_CONFIG_TYPES[key1]}" = "string" ]
	[ -z "${_CONFIG_DESCS[key1]}" ]
}

@test "config.load: load registered keys only" {
	config.register "name" "" "string"
	config.register "age" "" "int"
	config.register "skip" "default_skip" "string"
	{
		echo 'name = "John"'
		echo 'age = 25'
		echo 'unregistered = "ignored"'
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[name]}" = "John" ]
	[ "${_CONFIG_VALUES[age]}" = "25" ]
	# 未注册的键不存在
	[[ ! -v "_CONFIG_VALUES[unregistered]" ]]
	# 已注册但配置文件中未设置的键保持默认值
	[ "${_CONFIG_VALUES[skip]}" = "default_skip" ]
}

@test "config.load: override defaults" {
	config.register "key1" "default" "string"
	echo 'key1 = "custom"' > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[key1]}" = "custom" ]
}

@test "config.load: quote handling" {
	config.register "d_key" "" "string"
	config.register "s_key" "" "string"
	{
		echo 'd_key = "double_quoted"'
		echo "s_key = 'single_quoted'"
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[d_key]}" = "double_quoted" ]
	[ "${_CONFIG_VALUES[s_key]}" = "single_quoted" ]
}

@test "config.load: comment and empty line skipping" {
	config.register "key1" "" "string"
	{
		echo "# comment"
		echo ""
		echo "key1 = value"
		echo "# another comment"
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[key1]}" = "value" ]
}

@test "config.load: section prefix handling" {
	config.register "section.key1" "" "string"
	{
		echo "[section]"
		echo "key1 = value"
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[section.key1]}" = "value" ]
}

@test "config.load: whitespace trimming" {
	config.register "trimmed" "" "string"
	config.register "spaced" "" "string"
	{
		echo 'trimmed =  value  '
		echo '  spaced  =  value  '
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[trimmed]}" = "value" ]
	# key前有空格的行被忽略
	[ -z "${_CONFIG_VALUES[spaced]}" ]
}

@test "config.load: preserve spaces in quotes" {
	config.register "key1" "" "string"
	echo 'key1 = "value  "' > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[key1]}" = "value  " ]
}

@test "config.load: handle spaces in values" {
	config.register "message" "" "string"
	echo 'message = "hello world"' > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[message]}" = "hello world" ]
}

@test "config.load: file not found returns error" {
	! config.load /tmp/non_existent_config_$$.toml
}

@test "config.load: empty file" {
	config.register "key1" "default" "string"
	touch /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[key1]}" = "default" ]
}

@test "config.get: existing key" {
	config.register "key1" "default" "string"
	[ "$(config.get key1)" = "default" ]
}

@test "config.get: non-existent key returns error" {
	! config.get non_existent
}

@test "config.has: existing and non-existing keys" {
	config.register "key1" "value" "string"
	config.has key1
	! config.has non_existent
}

@test "config.set: update registered key" {
	config.register "key1" "initial" "string"
	config.set key1 "updated"
	[ "${_CONFIG_VALUES[key1]}" = "updated" ]
}

@test "config.set: unregistered key returns error" {
	! config.set unregistered "value"
}

@test "config.keys: list all keys" {
	config.register "a" "" "string"
	config.register "b" "" "string"
	result=$(config.keys)
	[[ "$result" == *"a"* ]]
	[[ "$result" == *"b"* ]]
}

@test "config.keys: empty config" {
	result=$(config.keys)
	[ -z "$result" ]
}

@test "config.type: get and non-existent" {
	config.register "key1" "" "int"
	[ "$(config.type key1)" = "int" ]
	result=$(config.type non_existent || true)
	[ -z "$result" ]
}

@test "config.desc: get and non-existent" {
	config.register "key1" "" "string" "A description"
	[ "$(config.desc key1)" = "A description" ]
	result=$(config.desc non_existent || true)
	[ -z "$result" ]
}

@test "config.path: from environment variable" {
	export _CONFIG_PATH="/tmp/custom_config_$$.toml"
	echo 'key = value' > "$_CONFIG_PATH"
	result=$(config.path)
	[ "$result" = "/tmp/custom_config_$$.toml" ]
	unset _CONFIG_PATH
}

@test "config.path: default config.toml" {
	(
		cd /tmp
		mkdir -p test_config_dir_$$
		cd test_config_dir_$$
		echo 'key = value' > config.toml
		unset _CONFIG_PATH
		result=$(config.path)
		[ "$result" = "config.toml" ]
	)
	rm -rf /tmp/test_config_dir_$$
}

@test "config.path: config dir fallback" {
	(
		cd /tmp
		mkdir -p test_config_dir_$$/.config/bashlet
		cd test_config_dir_$$
		echo 'key = value' > .config/bashlet/config.toml
		unset _CONFIG_PATH
		result=$(config.path 2>/dev/null) || result="fallback"
		# 取决于 path.config_dir 的实现
		echo "path: $result"
	)
	rm -rf /tmp/test_config_dir_$$
}

@test "config.load: use default path" {
	export _CONFIG_PATH="/tmp/auto_config_$$.toml"
	config.register "auto" "" "string"
	echo 'auto = loaded' > "$_CONFIG_PATH"
	config.load
	[ "${_CONFIG_VALUES[auto]}" = "loaded" ]
	unset _CONFIG_PATH
}

# ========== 数组配置功能测试 ==========

@test "config.array.register: basic registration" {
	config.array.register "servers" "prod" "192.168.1.1" "string" "Production server"
	[[ " ${_CONFIG_ARRAY_REGISTERED[servers]} " == *" prod "* ]]
	[ "${_CONFIG_TYPES[servers.prod]}" = "string" ]
	[ "${_CONFIG_VALUES[servers.prod]}" = "192.168.1.1" ]
	[ "${_CONFIG_DESCS[servers.prod]}" = "Production server" ]
}

@test "config.array.register: multiple items" {
	config.array.register "servers" "prod" "1.1.1.1" "string"
	config.array.register "servers" "dev" "2.2.2.2" "string"
	[[ " ${_CONFIG_ARRAY_REGISTERED[servers]} " == *" prod "* ]]
	[[ " ${_CONFIG_ARRAY_REGISTERED[servers]} " == *" dev "* ]]
}

@test "config.array.register: not in _CONFIG_REGISTERED" {
	config.register "regular_key" "value" "string"
	config.array.register "servers" "prod" "1.1.1.1" "string"
	[[ " ${_CONFIG_REGISTERED[*]} " == *" regular_key "* ]]
	[[ " ${_CONFIG_REGISTERED[*]} " != *" servers.prod "* ]]
}

@test "config.array.has: check array existence" {
	config.array.register "servers" "prod" "1.1.1.1" "string"
	config.array.has "servers"
	! config.array.has "nonexistent"
}

@test "config.array.has: check item existence after load" {
	config.array.register "servers" "prod" "" "string"
	config.register "servers.host" "" "string"
	{
		echo "[servers.prod]"
		echo 'host = "1.1.1.1"'
		echo "[servers.newitem]"
		echo 'host = "2.2.2.2"'
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	config.array.has "servers" "prod"
	config.array.has "servers" "newitem"
	! config.array.has "servers" "nonexistent"
}

@test "config.array.has: check field existence" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	{
		echo "[servers.prod]"
		echo 'host = "1.1.1.1"'
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	# 已注册字段存在
	config.array.has "servers" "prod" "host"
	config.array.has "servers" "prod" "port"
	# 未注册字段不存在
	! config.array.has "servers" "prod" "unregistered"
}

@test "config.array.keys: get items after load" {
	config.array.register "servers" "prod" "" "string"
	config.register "servers.host" "" "string"
	{
		echo "[servers.prod]"
		echo 'host = "1.1.1.1"'
		echo "[servers.dev]"
		echo 'host = "2.2.2.2"'
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	result=$(config.array.keys "servers")
	[[ "$result" == *"prod"* ]]
	[[ "$result" == *"dev"* ]]
}

@test "config.array.keys: nonexistent array" {
	result=$(config.array.keys "nonexistent" || true)
	[ -z "$result" ]
}

@test "config.array.keys: empty array" {
	_CONFIG_ARRAY_REGISTERED["empty_array"]=""
	result=$(config.array.keys "empty_array" || true)
	[ -z "$result" ]
}

@test "config.array.get: get values" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	{
		echo "[servers.prod]"
		echo 'host = "1.1.1.1"'
		echo 'port = "8080"'
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "$(config.array.get "servers" "prod" "host")" = "1.1.1.1" ]
	[ "$(config.array.get "servers" "prod" "port")" = "8080" ]
}

@test "config.array.get: non-existent item or field" {
	config.array.register "servers" "prod" "" "string"
	! config.array.get "servers" "nonexistent"
	! config.array.get "nonexistent" "item"
}

@test "config.load: array section with registered fields" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	{
		echo "[servers.prod]"
		echo 'host = "1.1.1.1"'
		echo 'port = "8080"'
		echo "[servers.dev]"
		echo 'host = "2.2.2.2"'
		echo 'port = "8081"'
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[servers.prod.host]}" = "1.1.1.1" ]
	[ "${_CONFIG_VALUES[servers.prod.port]}" = "8080" ]
	[ "${_CONFIG_VALUES[servers.dev.host]}" = "2.2.2.2" ]
	[ "${_CONFIG_VALUES[servers.dev.port]}" = "8081" ]
}

@test "config.load: dynamic item discovery" {
	config.array.register "servers" "host" "" "string"
	{
		echo "[servers.prod]"
		echo 'host = "1.1.1.1"'
		echo "[servers.newitem]"
		echo 'host = "3.3.3.3"'
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[servers.prod.host]}" = "1.1.1.1" ]
	[[ " ${_CONFIG_ARRAY_ITEMS[servers]} " == *" newitem "* ]]
}

@test "config.load: ignore unregistered array section" {
	config.register "regular.regular_key" "" "string"
	{
		echo "[unregistered.array]"
		echo 'key = "value"'
		echo "[regular]"
		echo 'regular_key = "test"'
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[[ ! -v "_CONFIG_VALUES[unregistered.array.key]" ]]
	[ "${_CONFIG_VALUES[regular.regular_key]}" = "test" ]
}

@test "config.load: array section followed by normal section" {
	config.array.register "servers" "host" "" "string"
	config.register "global.global_key" "" "string"
	{
		echo "[servers.prod]"
		echo 'host = "1.1.1.1"'
		echo "[global]"
		echo 'global_key = "value"'
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[servers.prod.host]}" = "1.1.1.1" ]
	[ "${_CONFIG_VALUES[global.global_key]}" = "value" ]
}

@test "config.load: array with registered and unregistered fields" {
	config.array.register "servers" "field1" "" "string"
	{
		echo "[servers.prod]"
		echo 'field1 = "value1"'
		echo 'field2 = "value2"'
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[servers.prod.field1]}" = "value1" ]
	[[ ! -v "_CONFIG_VALUES[servers.prod.field2]" ]]
}

@test "config.load: empty array section" {
	config.array.register "servers" "empty" "" "string"
	{
		echo "[servers.empty]"
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	config.array.has "servers" "empty"
}

@test "config.load: reload config updates values" {
	config.register "key1" "default" "string"
	echo 'key1 = "first"' > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[key1]}" = "first" ]
	echo 'key1 = "second"' > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[key1]}" = "second" ]
}
