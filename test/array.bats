#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import std/array
}

# array.len 测试
@test "array.len - 索引数组长度" {
	declare -a my_array=("a" "b" "c" "d" "e")
	[ "$(array.len my_array)" = "5" ]
}

@test "array.len - 空索引数组" {
	declare -a empty_array=()
	[ "$(array.len empty_array)" = "0" ]
}

@test "array.len - 关联数组长度" {
	declare -A my_assoc=(["key1"]="value1" ["key2"]="value2" ["key3"]="value3")
	[ "$(array.len my_assoc)" = "3" ]
}

@test "array.len - 空关联数组" {
	declare -A empty_assoc=()
	[ "$(array.len empty_assoc)" = "0" ]
}

@test "array.len - 动态添加元素后长度正确" {
	declare -a dyn_array=()
	dyn_array+=("first")
	dyn_array+=("second")
	dyn_array+=("third")
	[ "$(array.len dyn_array)" = "3" ]
}

# array.type 测试
@test "array.type - 索引数组类型判定" {
	declare -a my_array=("foo" "bar" "baz")
	[ "$(array.type my_array)" = "indexed" ]
}

@test "array.type - 关联数组类型判定" {
	declare -A my_assoc=(["key1"]="value1" ["key2"]="value2")
	[ "$(array.type my_assoc)" = "associative" ]
}

@test "array.type - 空索引数组类型判定" {
	declare -a empty_array=()
	[ "$(array.type empty_array)" = "indexed" ]
}

@test "array.type - 空关联数组类型判定" {
	declare -A empty_assoc=()
	[ "$(array.type empty_assoc)" = "associative" ]
}

@test "array.type - 普通字符串变量不是数组" {
	local my_var="hello"
	! array.type my_var
}

@test "array.type - 整数变量不是数组" {
	local my_num=42
	! array.type my_num
}

@test "array.type - 不存在的变量" {
	! array.type nonexistent_var
}

@test "array.type - 只读变量不是数组" {
	local -r readonly_var="test"
	! array.type readonly_var
}

@test "array.type - 导出的环境变量不是数组" {
	export TEST_ENV_VAR="value"
	! array.type TEST_ENV_VAR
	unset TEST_ENV_VAR
}

# array.contains 测试
@test "array.contains - 包含存在的元素" {
	declare -a my_array=("foo" "bar" "baz")
	array.contains my_array "foo"
}

@test "array.contains - 第一个元素" {
	declare -a my_array=("foo" "bar" "baz")
	array.contains my_array "foo"
}

@test "array.contains - 最后一个元素" {
	declare -a my_array=("foo" "bar" "baz")
	array.contains my_array "baz"
}

@test "array.contains - 中间元素" {
	declare -a my_array=("foo" "bar" "baz")
	array.contains my_array "bar"
}

@test "array.contains - 不包含不存在的元素" {
	declare -a my_array=("foo" "bar" "baz")
	! array.contains my_array "qux"
}

@test "array.contains - 空数组" {
	declare -a empty_array=()
	! array.contains empty_array "foo"
}

@test "array.contains - 单元素数组且匹配" {
	declare -a single_array=("foo")
	array.contains single_array "foo"
}

@test "array.contains - 单元素数组且不匹配" {
	declare -a single_array=("foo")
	! array.contains single_array "bar"
}

@test "array.contains - 部分匹配不应该成功" {
	declare -a my_array=("foo" "bar" "baz")
	! array.contains my_array "ba"
}

@test "array.contains - 特殊字符元素" {
	declare -a special_array=("foo*" "bar" "baz")
	array.contains special_array "foo*"
}

@test "array.contains - 包含空元素" {
	declare -a my_array=("foo" "" "bar")
	array.contains my_array "foo"
}

@test "array.contains - 查找空元素" {
	declare -a my_array=("foo" "" "bar")
	array.contains my_array ""
}

@test "array.contains - 不应该找到空元素" {
	declare -a my_array=("foo" "bar" "baz")
	! array.contains my_array ""
}

@test "array.contains - 数字元素" {
	declare -a num_array=("123" "456" "789")
	array.contains num_array "123"
}

@test "array.contains - 包含空格的元素" {
	declare -a space_array=("foo bar" "baz" "qux")
	array.contains space_array "foo bar"
}

@test "array.contains - 大小写敏感" {
	declare -a my_array=("foo" "bar" "baz")
	! array.contains my_array "Foo"
}

# array.get 测试
@test "array.get - 获取第一个元素" {
	declare -a my_array=("foo" "bar" "baz")
	[ "$(array.get my_array 0)" = "foo" ]
}

@test "array.get - 获取中间元素" {
	declare -a my_array=("foo" "bar" "baz")
	[ "$(array.get my_array 1)" = "bar" ]
}

@test "array.get - 获取最后一个元素" {
	declare -a my_array=("foo" "bar" "baz")
	[ "$(array.get my_array 2)" = "baz" ]
}

@test "array.get - 负索引越界" {
	declare -a my_array=("foo" "bar" "baz")
	! array.get my_array -1
}

@test "array.get - 索引超过长度" {
	declare -a my_array=("foo" "bar" "baz")
	! array.get my_array 3
}

@test "array.get - 大索引越界" {
	declare -a my_array=("foo" "bar" "baz")
	! array.get my_array 100
}

@test "array.get - 空数组越界" {
	declare -a empty_array=()
	! array.get empty_array 0
}

@test "array.get - 单元素数组" {
	declare -a single_array=("only")
	[ "$(array.get single_array 0)" = "only" ]
}

@test "array.get - 单元素数组越界" {
	declare -a single_array=("only")
	! array.get single_array 1
}

@test "array.get - 元素为空字符串" {
	declare -a my_array=("foo" "" "bar")
	[ "$(array.get my_array 1)" = "" ]
}

@test "array.get - 元素包含空格" {
	declare -a space_array=("foo bar" "baz qux")
	[ "$(array.get space_array 0)" = "foo bar" ]
}

@test "array.get - 元素包含特殊字符" {
	declare -a special_array=("foo*" "bar!")
	[ "$(array.get special_array 0)" = "foo*" ]
}
