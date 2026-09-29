#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import core/config.persist
}

teardown() {
	_CONFIG_REGISTERED=()
	_CONFIG_TYPES=()
	_CONFIG_DESCS=()
	_CONFIG_VALUES=()
	_CONFIG_ARRAY_REGISTERED=()
	_CONFIG_ARRAY_ITEMS=()
	rm -f /tmp/test_*.toml 2> /dev/null || true
}

@test "config.persist.save: basic save and reload" {
	config.register "name" "myapp" "string"
	config.register "version" "1.0.0" "string"
	config.persist.save /tmp/test_save_$$.toml
	_CONFIG_VALUES=()
	config.register "name" "" "string"
	config.register "version" "" "string"
	config.load /tmp/test_save_$$.toml
	[ "$(config.get name)" = "myapp" ]
	[ "$(config.get version)" = "1.0.0" ]
}

@test "config.persist.save: save with sections" {
	config.register "database.host" "localhost" "string"
	config.register "database.port" "3306" "string"
	config.register "cache.enabled" "true" "bool"
	config.persist.save /tmp/test_save_$$.toml
	_CONFIG_VALUES=()
	config.register "database.host" "" "string"
	config.register "database.port" "" "string"
	config.register "cache.enabled" "" "bool"
	config.load /tmp/test_save_$$.toml
	[ "$(config.get database.host)" = "localhost" ]
	[ "$(config.get database.port)" = "3306" ]
	[ "$(config.get cache.enabled)" = "true" ]
}

@test "config.persist.save: save array config" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.array.set "servers" "prod" "port" "8080"
	config.array.set "servers" "dev" "host" "2.2.2.2"
	config.array.set "servers" "dev" "port" "8081"
	config.persist.save /tmp/test_save_$$.toml
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

@test "config.persist.save: skip array field definitions" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.persist.save /tmp/test_save_$$.toml
	grep -q "\[servers\]$" /tmp/test_save_$$.toml && return 1 || true
}

@test "config.persist.save: empty config" {
	config.persist.save /tmp/test_save_$$.toml
	[ -f /tmp/test_save_$$.toml ]
	local content=$(cat /tmp/test_save_$$.toml)
	[ -z "$content" ]
}

# ========== 过滤功能测试 ==========

@test "config.persist.save: filter_keys - save only specified keys" {
	config.register "global.name" "myapp" "string"
	config.register "global.version" "1.0.0" "string"
	config.register "database.host" "localhost" "string"
	config.register "database.port" "3306" "string"

	local -a filter_keys=("global.name" "database.host")
	config.persist.save /tmp/test_filter_keys_$$.toml filter_keys

	# 验证只保存了指定的键
	grep -q '\[global\]' /tmp/test_filter_keys_$$.toml
	grep -q 'name = "myapp"' /tmp/test_filter_keys_$$.toml
	grep -q '\[database\]' /tmp/test_filter_keys_$$.toml
	grep -q 'host = "localhost"' /tmp/test_filter_keys_$$.toml
	! grep -q 'version' /tmp/test_filter_keys_$$.toml
	! grep -q 'port' /tmp/test_filter_keys_$$.toml
}

@test "config.persist.save: filter_keys - with sections" {
	config.register "section1.key1" "value1" "string"
	config.register "section1.key2" "value2" "string"
	config.register "section2.key1" "value3" "string"

	local -a filter_keys=("section1.key1" "section2.key1")
	config.persist.save /tmp/test_filter_sections_$$.toml filter_keys

	# 验证正确的节和键被保存
	grep -q '\[section1\]' /tmp/test_filter_sections_$$.toml
	grep -q 'key1 = "value1"' /tmp/test_filter_sections_$$.toml
	grep -q '\[section2\]' /tmp/test_filter_sections_$$.toml
	grep -q 'key1 = "value3"' /tmp/test_filter_sections_$$.toml
	! grep -q 'key2 = "value2"' /tmp/test_filter_sections_$$.toml
}

@test "config.persist.save: filter_arrays - save only specified array items" {
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
	config.persist.save /tmp/test_filter_arrays_$$.toml "" filter_arrays

	# 验证只保存了指定的数组项
	grep -q '\[servers.prod\]' /tmp/test_filter_arrays_$$.toml
	grep -q 'host = "1.1.1.1"' /tmp/test_filter_arrays_$$.toml
	grep -q 'port = "8080"' /tmp/test_filter_arrays_$$.toml
	grep -q '\[servers.dev\]' /tmp/test_filter_arrays_$$.toml
	grep -q 'host = "2.2.2.2"' /tmp/test_filter_arrays_$$.toml
	grep -q 'port = "8081"' /tmp/test_filter_arrays_$$.toml
	! grep -q 'url = "test"' /tmp/test_filter_arrays_$$.toml
}

@test "config.persist.save: both filters - combine filter_keys and filter_arrays" {
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
	config.persist.save /tmp/test_both_filters_$$.toml filter_keys filter_arrays

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

@test "config.persist.save: filter_arrays - multiple arrays" {
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
	config.persist.save /tmp/test_multi_arrays_$$.toml "" filter_arrays

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

@test "config.persist.save: filter_keys - empty filter array" {
	config.register "key1" "value1" "string"
	config.register "key2" "value2" "string"

	local -a empty_filter=()
	config.persist.save /tmp/test_empty_filter_$$.toml empty_filter

	# 空过滤数组应该过滤掉所有键
	! grep -q 'key1 = "value1"' /tmp/test_empty_filter_$$.toml
	! grep -q 'key2 = "value2"' /tmp/test_empty_filter_$$.toml
}

@test "config.persist.save: filter_arrays - empty filter array" {
	config.array.register "servers" "host" "" "string"
	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.array.set "servers" "dev" "host" "2.2.2.2"

	local -A empty_filter=()
	config.persist.save /tmp/test_empty_array_filter_$$.toml "" empty_filter

	# 空关联数组应该过滤掉所有数组项
	! grep -q '\[servers.prod\]' /tmp/test_empty_array_filter_$$.toml
	! grep -q 'host = "1.1.1.1"' /tmp/test_empty_array_filter_$$.toml
	! grep -q '\[servers.dev\]' /tmp/test_empty_array_filter_$$.toml
	! grep -q 'host = "2.2.2.2"' /tmp/test_empty_array_filter_$$.toml
}

@test "config.persist.save: filter_arrays - skip array field definitions" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	config.array.set "servers" "prod" "host" "1.1.1.1"
	config.array.set "servers" "prod" "port" "8080"

	local -A filter_arrays=([servers]="host")
	config.persist.save /tmp/test_skip_array_fields_$$.toml "" filter_arrays

	# 数组配置项不应该出现在输出中
	! grep -q '\[servers\]' /tmp/test_skip_array_fields_$$.toml
	grep -q '\[servers.prod\]' /tmp/test_skip_array_fields_$$.toml
	! grep -q 'port = "8080"' /tmp/test_both_filters_$$.toml
}

@test "config.persist.save: filter_keys - reload filtered config" {
	config.register "global.name" "myapp" "string"
	config.register "global.version" "1.0.0" "string"
	config.register "database.host" "localhost" "string"
	config.register "database.port" "3306" "string"

	local -a filter_keys=("global.name" "database.host")
	config.persist.save /tmp/test_filter_reload_$$.toml filter_keys

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

# ========== config.persist.update 测试 ==========

@test "config.persist.update: basic update existing key in file" {
	config.register "name" "initial" "string"
	echo 'name = "oldvalue"' > /tmp/test_update_$$.toml
	config.persist.update "name" "newvalue" /tmp/test_update_$$.toml
	[ "${_CONFIG_VALUES[name]}" = "newvalue" ]
	grep -q 'name = "newvalue"' /tmp/test_update_$$.toml
	! grep -q 'name = "oldvalue"' /tmp/test_update_$$.toml
}

@test "config.persist.update: add new key to section" {
	config.register "database.host" "localhost" "string"
	{
		echo "[database]"
		echo 'port = "3306"'
	} > /tmp/test_update_$$.toml
	config.persist.update "database.host" "127.0.0.1" /tmp/test_update_$$.toml
	grep -q 'host = "127.0.0.1"' /tmp/test_update_$$.toml
	grep -q '\[database\]' /tmp/test_update_$$.toml
}

@test "config.persist.update: create new section for new key" {
	config.register "cache.enabled" "true" "bool"
	echo '# Empty config' > /tmp/test_update_$$.toml
	config.persist.update "cache.enabled" "false" /tmp/test_update_$$.toml
	grep -q '\[cache\]' /tmp/test_update_$$.toml
	grep -q 'enabled = "false"' /tmp/test_update_$$.toml
}

@test "config.persist.update: create file if not exists" {
	config.register "name" "myapp" "string"
	rm -f /tmp/test_update_new_$$.toml
	config.persist.update "name" "newapp" /tmp/test_update_new_$$.toml
	[ -f /tmp/test_update_new_$$.toml ]
	grep -q 'name = "newapp"' /tmp/test_update_new_$$.toml
}

@test "config.persist.update: array update basic existing field" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	{
		echo "[servers.prod]"
		echo 'host = "old.host.com"'
		echo 'port = "8080"'
	} > /tmp/test_array_update_$$.toml
	config.persist.update "servers" "prod" "host" "new.host.com" /tmp/test_array_update_$$.toml
	[ "${_CONFIG_VALUES[servers.prod.host]}" = "new.host.com" ]
	grep -q 'host = "new.host.com"' /tmp/test_array_update_$$.toml
	! grep -q 'host = "old.host.com"' /tmp/test_array_update_$$.toml
}

@test "config.persist.update: array add new field to existing item" {
	config.array.register "servers" "host" "" "string"
	config.array.register "servers" "port" "" "string"
	{
		echo "[servers.prod]"
		echo 'host = "1.1.1.1"'
	} > /tmp/test_array_update_$$.toml
	config.persist.update "servers" "prod" "port" "8080" /tmp/test_array_update_$$.toml
	grep -q 'port = "8080"' /tmp/test_array_update_$$.toml
}

@test "config.persist.update: array save full file if section not exists" {
	config.array.register "servers" "host" "" "string"
	{
		echo "# Other config"
	} > /tmp/test_array_update_$$.toml
	config.persist.update "servers" "prod" "host" "1.1.1.1" /tmp/test_array_update_$$.toml
	[ -f /tmp/test_array_update_$$.toml ]
}

@test "config.persist.update: add to new section without corrupting existing sections" {
	config.array.register "sources" "repo" "" "string"
	{
		echo "[sources.existing]"
		echo 'repo = "org/existing"'
		echo ""
		echo "[agents.opencode]"
		echo 'user_dir = "~/.config/opencode/skills"'
	} > /tmp/test_update_bug_$$.toml
	config.persist.update "sources" "NEW" "repo" "org/new" /tmp/test_update_bug_$$.toml
	grep -q 'sources.NEW' /tmp/test_update_bug_$$.toml
	grep -q 'repo = "org/existing"' /tmp/test_update_bug_$$.toml
}

