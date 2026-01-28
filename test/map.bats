#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import std/map
}


# map.contains 测试
@test "map.contains - 关联数组包含存在的key" {
	declare -A my_assoc=(["key1"]="value1" ["key2"]="value2" ["key3"]="value3")
	map.contains my_assoc "key1"
}

@test "map.contains - 关联数组包含最后一个key" {
	declare -A my_assoc=(["key1"]="value1" ["key2"]="value2" ["key3"]="value3")
	map.contains my_assoc "key3"
}

@test "map.contains - 关联数组包含中间key" {
	declare -A my_assoc=(["key1"]="value1" ["key2"]="value2" ["key3"]="value3")
	map.contains my_assoc "key2"
}

@test "map.contains - 关联数组不包含不存在的key" {
	declare -A my_assoc=(["key1"]="value1" ["key2"]="value2" ["key3"]="value3")
	! map.contains my_assoc "key4"
}

@test "map.contains - 空关联数组不包含任何key" {
	declare -A empty_assoc=()
	! map.contains empty_assoc "key1"
}

@test "map.contains - 关联数组key为数字字符串" {
	declare -A num_assoc=(["123"]="value1" ["456"]="value2")
	map.contains num_assoc "123"
}

@test "map.contains - 关联数组key包含特殊字符" {
	declare -A special_assoc=(["key*"]="value1" ["key!"]="value2")
	map.contains special_assoc "key*"
}

@test "map.contains - 关联数组key包含空格" {
	declare -A space_assoc=(["key with space"]="value1" ["another key"]="value2")
	map.contains space_assoc "key with space"
}

@test "map.contains - 关联数组key大小写敏感" {
	declare -A my_assoc=(["Key1"]="value1" ["key2"]="value2")
	! map.contains my_assoc "key1"
}


# map.get 测试
@test "map.get - 获取存在的key" {
	declare -A my_assoc=(["key1"]="value1" ["key2"]="value2" ["key3"]="value3")
	[ "$(map.get my_assoc "key1")" = "value1" ]
}

@test "map.get - 获取中间key" {
	declare -A my_assoc=(["key1"]="value1" ["key2"]="value2" ["key3"]="value3")
	[ "$(map.get my_assoc "key2")" = "value2" ]
}

@test "map.get - 获取最后一个key" {
	declare -A my_assoc=(["key1"]="value1" ["key2"]="value2" ["key3"]="value3")
	[ "$(map.get my_assoc "key3")" = "value3" ]
}

@test "map.get - 不存在的key" {
	declare -A my_assoc=(["key1"]="value1" ["key2"]="value2" ["key3"]="value3")
	! map.get my_assoc "key4"
}

@test "map.get - 空关联数组不存在的key" {
	declare -A empty_assoc=()
	! map.get empty_assoc "key1"
}

@test "map.get - key为数字字符串" {
	declare -A num_assoc=(["123"]="value1" ["456"]="value2")
	[ "$(map.get num_assoc "123")" = "value1" ]
}

@test "map.get - key包含特殊字符" {
	declare -A special_assoc=(["key*"]="value1" ["key!"]="value2")
	[ "$(map.get special_assoc "key*")" = "value1" ]
}

@test "map.get - key包含空格" {
	declare -A space_assoc=(["key with space"]="value1" ["another key"]="value2")
	[ "$(map.get space_assoc "key with space")" = "value1" ]
}

@test "map.get - value为空字符串" {
	declare -A my_assoc=(["key1"]="" ["key2"]="value2")
	[ "$(map.get my_assoc "key1")" = "" ]
}

@test "map.get - value包含空格" {
	declare -A space_assoc=(["key1"]="value with space" ["key2"]="another value")
	[ "$(map.get space_assoc "key1")" = "value with space" ]
}

@test "map.get - value包含特殊字符" {
	declare -A special_assoc=(["key1"]="value*" ["key2"]="value!")
	[ "$(map.get special_assoc "key1")" = "value*" ]
}
