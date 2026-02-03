#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import core/config
	config.reset
}

teardown() {
	config.reset
	rm -f /tmp/test_config_*.toml 2>/dev/null || true
}

@test "config.register - 注册配置项" {
	config.register "key1" "string" "default1"
	[ "${_CONFIG_KEYS[0]}" = "key1" ]
	[ "${_CONFIG_TYPES[key1]}" = "string" ]
	[ "${_CONFIG_DEFAULTS[key1]}" = "default1" ]
}

@test "config.register - 注册多个配置项" {
	config.register "key1" "string" "val1"
	config.register "key2" "int" "100"
	config.register "key3" "bool" "true"
	[ ${#_CONFIG_KEYS[@]} -eq 3 ]
	[ "${_CONFIG_KEYS[0]}" = "key1" ]
	[ "${_CONFIG_KEYS[1]}" = "key2" ]
	[ "${_CONFIG_KEYS[2]}" = "key3" ]
}

@test "config.register - 重复注册不重复添加" {
	config.register "key1" "string" "val1"
	config.register "key1" "int" "999"
	[ ${#_CONFIG_KEYS[@]} -eq 1 ]
	[ "${_CONFIG_TYPES[key1]}" = "string" ]
}

@test "config.register - 默认值设置到 VALUES" {
	config.register "key1" "string" "default_value"
	[ "${_CONFIG_VALUES[key1]}" = "default_value" ]
}

@test "config.register - 空字符串默认值设置到 VALUES" {
	config.register "key1" "string" ""
	[[ -v "_CONFIG_VALUES[key1]" ]]
	[ "${_CONFIG_VALUES[key1]}" = "" ]
}

@test "config.load - 加载已注册的键" {
	config.register "name" "string" ""
	config.register "age" "int" ""
	echo 'name = "John"' > /tmp/test_config_$$.toml
	echo 'age = 25' >> /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[name]}" = "John" ]
	[ "${_CONFIG_VALUES[age]}" = "25" ]
}

@test "config.load - 忽略未注册的键" {
	config.register "registered" "string" ""
	echo 'registered = "yes"' > /tmp/test_config_$$.toml
	echo 'not_registered = "no"' >> /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[registered]}" = "yes" ]
	[[ ! -v "_CONFIG_VALUES[not_registered]" ]]
}

@test "config.load - 覆盖默认值" {
	config.register "key1" "string" "default"
	echo 'key1 = "custom"' > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[key1]}" = "custom" ]
}

@test "config.load - 去除引号" {
	config.register "key1" "string" ""
	echo 'key1 = "quoted_value"' > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[key1]}" = "quoted_value" ]
}

@test "config.load - 去除单引号" {
	config.register "key1" "string" ""
	echo "key1 = 'single_quoted'" > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[key1]}" = "single_quoted" ]
}

@test "config.load - 跳过注释" {
	config.register "key1" "string" ""
	{
		echo "# This is a comment"
		echo "key1 = value"
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[key1]}" = "value" ]
}

@test "config.load - 跳过空行" {
	config.register "key1" "string" ""
	{
		echo ""
		echo "key1 = value"
		echo ""
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[key1]}" = "value" ]
}

@test "config.load - 跳过 section 行" {
	config.register "key1" "string" ""
	{
		echo "[section]"
		echo "key1 = value"
	} > /tmp/test_config_$$.toml
	config.load /tmp/test_config_$$.toml
	[ "${_CONFIG_VALUES[key1]}" = "value" ]
}

@test "config.get - 获取存在的值" {
	config.register "key1" "string" "default"
	[ "$(config.get key1)" = "default" ]
}

@test "config.get - 不存在的键返回错误" {
	! config.get non_existent
}

@test "config.has - 存在的键返回 true" {
	config.register "key1" "string" "value"
	config.has key1
}

@test "config.has - 不存在的键返回 false" {
	! config.has non_existent
}

@test "config.set - 设置已注册键的值" {
	config.register "key1" "string" "initial"
	config.set key1 "updated"
	[ "${_CONFIG_VALUES[key1]}" = "updated" ]
}

@test "config.set - 设置未注册键返回错误" {
	! config.set unregistered "value"
}

@test "config.verify - 所有有默认值的项通过验证" {
	config.register "key1" "string" "default1"
	config.register "key2" "string" "default2"
	config.verify
}

@test "config.verify - 缺少无默认值的项失败" {
	config.register "key1" "string"
	config.register "key2" "string" "default"
	! config.verify
}

@test "config.keys - 返回所有键" {
	config.register "a" "string" ""
	config.register "b" "string" ""
	config.register "c" "string" ""
	result=$(config.keys)
	[[ "$result" == *"a"* ]]
	[[ "$result" == *"b"* ]]
	[[ "$result" == *"c"* ]]
}

@test "config.type - 获取配置项类型" {
	config.register "key1" "int" ""
	[ "$(config.type key1)" = "int" ]
}

@test "config.default - 获取默认值" {
	config.register "key1" "string" "my_default"
	[ "$(config.default key1)" = "my_default" ]
}

@test "config.reset - 清空所有配置" {
	config.register "key1" "string" "val1"
	config.register "key2" "string" "val2"
	config.reset
	[ ${#_CONFIG_KEYS[@]} -eq 0 ]
}

@test "config.desc - 获取配置描述" {
	config.register "key1" "string" "" "This is a description"
	[ "$(config.desc key1)" = "This is a description" ]
}
