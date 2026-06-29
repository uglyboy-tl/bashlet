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
	rm -f /tmp/test_config_*.toml 2> /dev/null || true
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
	[[ $result == *"a"* ]]
	[[ $result == *"b"* ]]
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
		result=$(config.path 2> /dev/null) || result="fallback"
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

@test "config.array.add: basic add" {
	config.array.add "servers" "prod"
	[[ " ${_CONFIG_ARRAY_ITEMS[servers]} " == *" prod "* ]]
}

@test "config.array.add: allows duplicate adds" {
	config.array.add "servers" "prod"
	config.array.add "servers" "prod"
	[[ " ${_CONFIG_ARRAY_ITEMS[servers]} " == *" prod "* ]]
}

@test "config.array.add: multiple items" {
	config.array.add "servers" "prod"
	config.array.add "servers" "dev"
	config.array.add "servers" "staging"
	[[ " ${_CONFIG_ARRAY_ITEMS[servers]} " == *" prod "* ]]
	[[ " ${_CONFIG_ARRAY_ITEMS[servers]} " == *" dev "* ]]
	[[ " ${_CONFIG_ARRAY_ITEMS[servers]} " == *" staging "* ]]
}

@test "config.array.set: set fields and auto create item" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	[[ " ${_CONFIG_ARRAY_ITEMS[servers]:-} " != *" prod "* ]]
	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.array.set "servers" "prod" "port" "8080"
	[ "${_CONFIG_VALUES[servers.prod.host]}" = "1.1.1.1" ]
	[ "${_CONFIG_VALUES[servers.prod.port]}" = "8080" ]
	[[ " ${_CONFIG_ARRAY_ITEMS[servers]} " == *" prod "* ]]
}

@test "config.array.set: update existing value" {
	config.array.register "servers" "host" "" "string"
	config.array.set "servers" "prod" "host" "1.1.1.1"
	[ "${_CONFIG_VALUES[servers.prod.host]}" = "1.1.1.1" ]
	config.array.set "servers" "prod" "host" "2.2.2.2"
	[ "${_CONFIG_VALUES[servers.prod.host]}" = "2.2.2.2" ]
}

@test "config.array.set: multiple items with same field" {
	config.array.register "servers" "host" "" "string"
	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.array.set "servers" "dev" "host" "2.2.2.2"
	[ "${_CONFIG_VALUES[servers.prod.host]}" = "1.1.1.1" ]
	[ "${_CONFIG_VALUES[servers.dev.host]}" = "2.2.2.2" ]
}

@test "config.array.set: unregistered array returns error" {
	! config.array.set "nonexistent" "prod" "host" "1.1.1.1"
}

@test "config.array.set: unregistered field returns error" {
	config.array.register "servers" "host" "" "string"
	! config.array.set "servers" "prod" "unregistered_field" "value"
}

@test "config.array.set: empty value is allowed" {
	config.array.register "servers" "host" "" "string"
	config.array.set "servers" "prod" "host" ""
	[ "${_CONFIG_VALUES[servers.prod.host]}" = "" ]
}

@test "config.array.set: item with dot in name" {
	config.array.register "servers" "host" "" "string"
	config.array.set "servers" "v1.0" "host" "1.1.1.1"
	[ "${_CONFIG_VALUES[servers.v1.0.host]}" = "1.1.1.1" ]
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

@test "config.array.items: get items after load" {
	config.array.register "servers" "prod" "" "string"
	config.register "servers.host" "" "string"
	{
		echo "[servers.prod]"
		echo 'host = "1.1.1.1"'
		echo "[servers.dev]"
		echo 'host = "2.2.2.2"'
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	result=$(config.array.items "servers")
	[[ $result == *"prod"* ]]
	[[ $result == *"dev"* ]]
}

@test "config.array.items: nonexistent array" {
	result=$(config.array.items "nonexistent" || true)
	[ -z "$result" ]
}

@test "config.array.items: empty array" {
	_CONFIG_ARRAY_REGISTERED["empty_array"]=""
	result=$(config.array.items "empty_array" || true)
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

@test "config.save: basic save and reload" {
	config.register "name" "myapp" "string"
	config.register "version" "1.0.0" "string"
	config.save /tmp/test_save_$$.toml
	_CONFIG_VALUES=()
	config.register "name" "" "string"
	config.register "version" "" "string"
	config.load /tmp/test_save_$$.toml
	[ "$(config.get name)" = "myapp" ]
	[ "$(config.get version)" = "1.0.0" ]
}

@test "config.save: save with sections" {
	config.register "database.host" "localhost" "string"
	config.register "database.port" "3306" "string"
	config.register "cache.enabled" "true" "bool"
	config.save /tmp/test_save_$$.toml
	_CONFIG_VALUES=()
	config.register "database.host" "" "string"
	config.register "database.port" "" "string"
	config.register "cache.enabled" "" "bool"
	config.load /tmp/test_save_$$.toml
	[ "$(config.get database.host)" = "localhost" ]
	[ "$(config.get database.port)" = "3306" ]
	[ "$(config.get cache.enabled)" = "true" ]
}

@test "config.save: save array config" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.array.set "servers" "prod" "port" "8080"
	config.array.set "servers" "dev" "host" "2.2.2.2"
	config.array.set "servers" "dev" "port" "8081"
	config.save /tmp/test_save_$$.toml
	_CONFIG_VALUES=()
	_CONFIG_ARRAY_ITEMS=()
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	config.load /tmp/test_save_$$.toml
	[ "$(config.array.get servers prod host)" = "1.1.1.1" ]
	[ "$(config.array.get servers prod port)" = "8080" ]
	[ "$(config.array.get servers dev host)" = "2.2.2.2" ]
	[ "$(config.array.get servers dev port)" = "8081" ]
}

@test "config.save: skip array field definitions" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.save /tmp/test_save_$$.toml
	grep -q "\[servers\]$" /tmp/test_save_$$.toml && return 1 || true
}

@test "config.save: empty config" {
	config.save /tmp/test_save_$$.toml
	[ -f /tmp/test_save_$$.toml ]
	local content=$(cat /tmp/test_save_$$.toml)
	[ -z "$content" ]
}

# ========== 过滤功能测试 ==========

@test "config.save: filter_keys - save only specified keys" {
	config.register "global.name" "myapp" "string"
	config.register "global.version" "1.0.0" "string"
	config.register "database.host" "localhost" "string"
	config.register "database.port" "3306" "string"

	local -a filter_keys=("global.name" "database.host")
	config.save /tmp/test_filter_keys_$$.toml filter_keys

	# 验证只保存了指定的键
	grep -q '\[global\]' /tmp/test_filter_keys_$$.toml
	grep -q 'name = "myapp"' /tmp/test_filter_keys_$$.toml
	grep -q '\[database\]' /tmp/test_filter_keys_$$.toml
	grep -q 'host = "localhost"' /tmp/test_filter_keys_$$.toml
	! grep -q 'version' /tmp/test_filter_keys_$$.toml
	! grep -q 'port' /tmp/test_filter_keys_$$.toml
}

@test "config.save: filter_keys - with sections" {
	config.register "section1.key1" "value1" "string"
	config.register "section1.key2" "value2" "string"
	config.register "section2.key1" "value3" "string"

	local -a filter_keys=("section1.key1" "section2.key1")
	config.save /tmp/test_filter_sections_$$.toml filter_keys

	# 验证正确的节和键被保存
	grep -q '\[section1\]' /tmp/test_filter_sections_$$.toml
	grep -q 'key1 = "value1"' /tmp/test_filter_sections_$$.toml
	grep -q '\[section2\]' /tmp/test_filter_sections_$$.toml
	grep -q 'key1 = "value3"' /tmp/test_filter_sections_$$.toml
	! grep -q 'key2 = "value2"' /tmp/test_filter_sections_$$.toml
}

@test "config.save: filter_arrays - save only specified array items" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	config.array.register "servers" "url" "" "string"
	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.array.set "servers" "prod" "port" "8080"
	config.array.set "servers" "prod" "url" "test"
	config.array.set "servers" "dev" "host" "2.2.2.2"
	config.array.set "servers" "dev" "port" "8081"
	config.array.set "servers" "dev" "url" "test"

	local -A filter_arrays=([servers]="host port")
	config.save /tmp/test_filter_arrays_$$.toml "" filter_arrays

	# 验证只保存了指定的数组项
	grep -q '\[servers.prod\]' /tmp/test_filter_arrays_$$.toml
	grep -q 'host = "1.1.1.1"' /tmp/test_filter_arrays_$$.toml
	grep -q 'port = "8080"' /tmp/test_filter_arrays_$$.toml
	grep -q '\[servers.dev\]' /tmp/test_filter_arrays_$$.toml
	grep -q 'host = "2.2.2.2"' /tmp/test_filter_arrays_$$.toml
	grep -q 'port = "8081"' /tmp/test_filter_arrays_$$.toml
	! grep -q 'url = "test"' /tmp/test_filter_arrays_$$.toml
}

@test "config.save: both filters - combine filter_keys and filter_arrays" {
	config.register "global.name" "myapp" "string"
	config.register "global.version" "1.0.0" "string"
	config.register "database.host" "localhost" "string"

	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.array.set "servers" "prod" "port" "8080"
	config.array.set "servers" "dev" "host" "2.2.2.2"
	config.array.set "servers" "dev" "port" "8081"

	local -a filter_keys=("global.name" "database.host")
	local -A filter_arrays=([servers]="host")
	config.save /tmp/test_both_filters_$$.toml filter_keys filter_arrays

	# 验证普通键过滤
	grep -q '\[global\]' /tmp/test_both_filters_$$.toml
	grep -q 'name = "myapp"' /tmp/test_both_filters_$$.toml
	grep -q '\[database\]' /tmp/test_both_filters_$$.toml
	grep -q 'host = "localhost"' /tmp/test_both_filters_$$.toml
	! grep -q 'global.version' /tmp/test_both_filters_$$.toml

	# 验证数组过滤
	grep -q '\[servers.prod\]' /tmp/test_both_filters_$$.toml
	grep -q '\[servers.dev\]' /tmp/test_both_filters_$$.toml
	grep -q 'host = "1.1.1.1"' /tmp/test_both_filters_$$.toml
	! grep -q 'port = "8080"' /tmp/test_both_filters_$$.toml
	! grep -q 'port = "8081"' /tmp/test_both_filters_$$.toml
}

@test "config.save: filter_arrays - multiple arrays" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	config.array.register "clients" "name" "" "string"

	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.array.set "servers" "prod" "port" "8080"
	config.array.set "servers" "dev" "host" "2.2.2.2"
	config.array.set "servers" "dev" "port" "8081"
	config.array.set "clients" "client1" "name" "Alice"
	config.array.set "clients" "client2" "name" "Bob"
	config.array.set "clients" "client3" "name" "Charlie"

	local -A filter_arrays=([servers]="host" [clients]="name")
	config.save /tmp/test_multi_arrays_$$.toml "" filter_arrays

	# 验证多个数组的过滤
	grep -q '\[servers.prod\]' /tmp/test_multi_arrays_$$.toml
	grep -q 'host = "1.1.1.1"' /tmp/test_multi_arrays_$$.toml
	! grep -q 'port = "8080"' /tmp/test_both_filters_$$.toml
	grep -q '\[servers.dev\]' /tmp/test_multi_arrays_$$.toml
	grep -q 'host = "2.2.2.2"' /tmp/test_multi_arrays_$$.toml
	! grep -q 'port = "8081"' /tmp/test_both_filters_$$.toml

	grep -q '\[clients.client1\]' /tmp/test_multi_arrays_$$.toml
	grep -q 'name = "Alice"' /tmp/test_multi_arrays_$$.toml
	grep -q '\[clients.client2\]' /tmp/test_multi_arrays_$$.toml
	grep -q 'name = "Bob"' /tmp/test_multi_arrays_$$.toml
	grep -q '\[clients.client3\]' /tmp/test_multi_arrays_$$.toml
	grep -q 'name = "Charlie"' /tmp/test_multi_arrays_$$.toml
}

@test "config.save: filter_keys - empty filter array" {
	config.register "key1" "value1" "string"
	config.register "key2" "value2" "string"

	local -a empty_filter=()
	config.save /tmp/test_empty_filter_$$.toml empty_filter

	# 空过滤数组应该过滤掉所有键
	! grep -q 'key1 = "value1"' /tmp/test_empty_filter_$$.toml
	! grep -q 'key2 = "value2"' /tmp/test_empty_filter_$$.toml
}

@test "config.save: filter_arrays - empty filter array" {
	config.array.register "servers" "host" "" "string"
	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.array.set "servers" "dev" "host" "2.2.2.2"

	local -A empty_filter=()
	config.save /tmp/test_empty_array_filter_$$.toml "" empty_filter

	# 空关联数组应该过滤掉所有数组项
	! grep -q '\[servers.prod\]' /tmp/test_empty_array_filter_$$.toml
	! grep -q 'host = "1.1.1.1"' /tmp/test_empty_array_filter_$$.toml
	! grep -q '\[servers.dev\]' /tmp/test_empty_array_filter_$$.toml
	! grep -q 'host = "2.2.2.2"' /tmp/test_empty_array_filter_$$.toml
}

@test "config.save: filter_arrays - skip array field definitions" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.array.set "servers" "prod" "port" "8080"

	local -A filter_arrays=([servers]="host")
	config.save /tmp/test_skip_array_fields_$$.toml "" filter_arrays

	# 数组配置项不应该出现在输出中
	! grep -q '\[servers\]' /tmp/test_skip_array_fields_$$.toml
	grep -q '\[servers.prod\]' /tmp/test_skip_array_fields_$$.toml
	! grep -q 'port = "8080"' /tmp/test_both_filters_$$.toml
}

@test "config.save: filter_keys - reload filtered config" {
	config.register "global.name" "myapp" "string"
	config.register "global.version" "1.0.0" "string"
	config.register "database.host" "localhost" "string"
	config.register "database.port" "3306" "string"

	local -a filter_keys=("global.name" "database.host")
	config.save /tmp/test_filter_reload_$$.toml filter_keys

	# 重置配置状态
	_CONFIG_VALUES=()
	_CONFIG_REGISTERED=()

	# 重新注册相同的键
	config.register "global.name" "" "string"
	config.register "global.version" "" "string"
	config.register "database.host" "" "string"
	config.register "database.port" "" "string"

	# 加载过滤后的配置
	config.load /tmp/test_filter_reload_$$.toml

	# 验证过滤后的配置可以正确加载
	[ "$(config.get global.name)" = "myapp" ]
	[ "$(config.get database.host)" = "localhost" ]
	# 未保存的键应该保持默认值（空）
	[ -z "$(config.get global.version 2> /dev/null || true)" ]
	[ -z "$(config.get database.port 2> /dev/null || true)" ]
}

# ========== config.update 测试 ==========

@test "config.update: basic update existing key in file" {
	config.register "name" "initial" "string"
	echo 'name = "oldvalue"' > /tmp/test_update_$$.toml
	config.update "name" "newvalue" /tmp/test_update_$$.toml
	[ "${_CONFIG_VALUES[name]}" = "newvalue" ]
	grep -q 'name = "newvalue"' /tmp/test_update_$$.toml
	! grep -q 'name = "oldvalue"' /tmp/test_update_$$.toml
}

@test "config.update: add new key to section" {
	config.register "database.host" "localhost" "string"
	{
		echo "[database]"
		echo 'port = "3306"'
	} > /tmp/test_update_$$.toml
	config.update "database.host" "127.0.0.1" /tmp/test_update_$$.toml
	grep -q 'host = "127.0.0.1"' /tmp/test_update_$$.toml
	grep -q '\[database\]' /tmp/test_update_$$.toml
}

@test "config.update: create new section for new key" {
	config.register "cache.enabled" "true" "bool"
	echo '# Empty config' > /tmp/test_update_$$.toml
	config.update "cache.enabled" "false" /tmp/test_update_$$.toml
	grep -q '\[cache\]' /tmp/test_update_$$.toml
	grep -q 'enabled = "false"' /tmp/test_update_$$.toml
}

@test "config.update: create file if not exists" {
	config.register "name" "myapp" "string"
	rm -f /tmp/test_update_new_$$.toml
	config.update "name" "newapp" /tmp/test_update_new_$$.toml
	[ -f /tmp/test_update_new_$$.toml ]
	grep -q 'name = "newapp"' /tmp/test_update_new_$$.toml
}

@test "config.update: array update basic existing field" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	{
		echo "[servers.prod]"
		echo 'host = "old.host.com"'
		echo 'port = "8080"'
	} > /tmp/test_array_update_$$.toml
	config.update "servers" "prod" "host" "new.host.com" /tmp/test_array_update_$$.toml
	[ "${_CONFIG_VALUES[servers.prod.host]}" = "new.host.com" ]
	grep -q 'host = "new.host.com"' /tmp/test_array_update_$$.toml
	! grep -q 'host = "old.host.com"' /tmp/test_array_update_$$.toml
}

@test "config.update: array add new field to existing item" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	{
		echo "[servers.prod]"
		echo 'host = "1.1.1.1"'
	} > /tmp/test_array_update_$$.toml
	config.update "servers" "prod" "port" "8080" /tmp/test_array_update_$$.toml
	grep -q 'port = "8080"' /tmp/test_array_update_$$.toml
}

@test "config.update: array save full file if section not exists" {
	config.array.register "servers" "host" "" "string"
	{
		echo "# Other config"
	} > /tmp/test_array_update_$$.toml
	config.update "servers" "prod" "host" "1.1.1.1" /tmp/test_array_update_$$.toml
	[ -f /tmp/test_array_update_$$.toml ]
}

# ========== 宽松模式 (loose mode) 测试 ==========

@test "config.loose: enable loose mode" {
	config.loose
	[ "$_CONFIG_STRICT_MODE" -eq 0 ]
}

@test "config.load loose: load unregistered keys" {
	config.loose
	{
		echo 'unregistered_key = "value1"'
		echo 'another_key = "value2"'
	} > /tmp/test_loose_$$.toml
	config.load /tmp/test_loose_$$.toml
	[ "${_CONFIG_VALUES[unregistered_key]}" = "value1" ]
	[ "${_CONFIG_VALUES[another_key]}" = "value2" ]
}

@test "config.load loose: load unregistered array sections" {
	config.loose
	{
		echo "[servers.prod]"
		echo 'host = "1.1.1.1"'
		echo 'port = "8080"'
		echo "[servers.dev]"
		echo 'host = "2.2.2.2"'
	} > /tmp/test_loose_array_$$.toml
	config.load /tmp/test_loose_array_$$.toml
	[[ " ${_CONFIG_ARRAY_ITEMS[servers]} " == *" prod "* ]]
	[[ " ${_CONFIG_ARRAY_ITEMS[servers]} " == *" dev "* ]]
	[ "${_CONFIG_VALUES[servers.prod.host]}" = "1.1.1.1" ]
	[ "${_CONFIG_VALUES[servers.prod.port]}" = "8080" ]
	[ "${_CONFIG_VALUES[servers.dev.host]}" = "2.2.2.2" ]
}

@test "config.load loose: mixed with registered keys" {
	config.register "registered_key" "default" "string"
	config.loose
	{
		echo 'registered_key = "updated"'
		echo 'unregistered_key = "value"'
	} > /tmp/test_loose_mixed_$$.toml
	config.load /tmp/test_loose_mixed_$$.toml
	[ "${_CONFIG_VALUES[registered_key]}" = "updated" ]
	[ "${_CONFIG_VALUES[unregistered_key]}" = "value" ]
}

@test "config.load strict: ignore unregistered keys by default" {
	config.register "registered_key" "default" "string"
	# _CONFIG_STRICT_MODE defaults to 1 (strict)
	{
		echo 'registered_key = "updated"'
		echo 'unregistered_key = "ignored"'
	} > /tmp/test_strict_$$.toml
	config.load /tmp/test_strict_$$.toml
	[ "${_CONFIG_VALUES[registered_key]}" = "updated" ]
	[[ ! -v "_CONFIG_VALUES[unregistered_key]" ]]
}

@test "config.load loose: key name with special characters" {
	config.loose
	{
		echo 'key-with-dash = "value1"'
		echo 'key_with_underscore = "value2"'
		echo 'key.with.dots = "value3"'
	} > /tmp/test_loose_special_$$.toml
	config.load /tmp/test_loose_special_$$.toml
	[ "${_CONFIG_VALUES[key-with-dash]}" = "value1" ]
	[ "${_CONFIG_VALUES[key_with_underscore]}" = "value2" ]
	[ "${_CONFIG_VALUES[key.with.dots]}" = "value3" ]
}

# ========== config.sections 测试 ==========

@test "config.sections: basic section extraction" {
	config.register "section1.key1" "value1" "string"
	config.register "section1.key2" "value2" "string"
	config.register "section2.key1" "value3" "string"
	config.register "top_level" "value4" "string"

	result=$(config.sections)
	[[ $result == *"section1"* ]]
	[[ $result == *"section2"* ]]
	[[ $result != *"top_level"* ]]
}

@test "config.sections: with prefix filter" {
	config.register "parent.child1.key1" "value1" "string"
	config.register "parent.child1.key2" "value2" "string"
	config.register "parent.child2.key1" "value3" "string"
	config.register "other.section.key" "value4" "string"

	result=$(config.sections "parent")
	[[ $result == *"child1"* ]]
	[[ $result == *"child2"* ]]
	[[ $result != *"other"* ]]
	[[ $result != *"section"* ]]
}

@test "config.sections: empty prefix returns all sections" {
	config.register "a.b" "1" "string"
	config.register "x.y.z" "2" "string"

	result=$(config.sections "")
	[[ $result == *"a"* ]]
	[[ $result == *"x"* ]]
}

@test "config.sections: no sections returns empty" {
	config.register "top1" "value1" "string"
	config.register "top2" "value2" "string"

	result=$(config.sections)
	[ -z "$result" ]
}

@test "config.sections: nested sections" {
	config.register "level1.level2.level3.key" "value" "string"
	config.register "level1.other.key" "value2" "string"

	result=$(config.sections "level1")
	[[ $result == *"level2"* ]]
	[[ $result == *"other"* ]]
	[[ $result != *"level1"* ]]

	result2=$(config.sections "level1.level2")
	[[ $result2 == *"level3"* ]]
	[[ $result2 != *"level2"* ]]
}
