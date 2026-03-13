#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import std/string

}
# ============ Base64 编码解码测试 ============

@test "string.base64.encode() 编码普通文本" {
	# 创建临时文件
	local temp_file=$(mktemp)
	echo -n "hello world" > "$temp_file"

	# 编码
	encoded=$(string.base64.encode "$temp_file")

	# 验证编码结果
	[ "$encoded" = "aGVsbG8gd29ybGQ=" ]

	rm -f "$temp_file"
}

@test "string.base64.encode() 编码包含特殊字符的文本" {
	local temp_file=$(mktemp)
	printf '"quotes" and \n newlines\t' > "$temp_file"

	encoded=$(string.base64.encode "$temp_file")

	# 验证编码结果不为空且只包含 base64 字符
	[ -n "$encoded" ]
	[[ $encoded =~ ^[A-Za-z0-9+/=]+$ ]]

	rm -f "$temp_file"
}

@test "string.base64.encode() 编码二进制数据" {
	local temp_file=$(mktemp)
	# 生成包含所有字节值的二进制数据
	printf '\x00\x01\x02\xff\xfe\xfd' > "$temp_file"

	encoded=$(string.base64.encode "$temp_file")

	# 验证编码结果
	[ -n "$encoded" ]
	[[ $encoded =~ ^[A-Za-z0-9+/=]+$ ]]

	rm -f "$temp_file"
}

@test "string.base64.decode() 解码普通文本" {
	# 解码
	decoded=$(echo "aGVsbG8gd29ybGQ=" | string.base64.decode)

	# 验证解码结果
	[ "$decoded" = "hello world" ]
}

@test "string.base64.decode() 解码包含特殊字符的文本" {
	# 原始文本包含引号和换行
	local original='"quotes" and
 newlines	'
	local encoded="InF1b3RlcyIgYW5kCiBuZXdsaW5lcwk="

	decoded=$(echo "$encoded" | string.base64.decode)

	[ "$decoded" = "$original" ]
}

@test "string.base64.encode() 和 string.base64.decode() 编码解码一致性" {
	local temp_file=$(mktemp)
	local test_data='Complex data: {"key": "value", "number": 123, "bool": true}'

	echo -n "$test_data" > "$temp_file"

	# 编码然后解码
	encoded=$(string.base64.encode "$temp_file")
	decoded=$(echo "$encoded" | string.base64.decode)

	# 验证数据完整性
	[ "$decoded" = "$test_data" ]

	rm -f "$temp_file"
}

@test "string.base64.encode() 和 string.base64.decode() 处理二进制数据一致性" {
	local temp_file=$(mktemp)
	# 生成包含各种字节值的二进制数据
	local binary_data=$(printf '\x00\x01\x02\x03\x7f\x80\xff\xfe\xfd\xfc')

	printf '%s' "$binary_data" > "$temp_file"

	# 编码然后解码
	encoded=$(string.base64.encode "$temp_file")
	decoded=$(echo "$encoded" | string.base64.decode)

	# 验证二进制数据完整性
	[ "$decoded" = "$binary_data" ]

	rm -f "$temp_file"
}

# ============ string.escape.sed 测试 ============

@test "string.escape.sed - 普通字符串保持不变" {
	run string.escape.sed "hello world"
	[ "$status" -eq 0 ]
	[ "$output" = "hello world" ]
}

@test "string.escape.sed - 转义 & 字符" {
	run string.escape.sed "foo&bar"
	[ "$status" -eq 0 ]
	[ "$output" = "foo\&bar" ]
}

@test "string.escape.sed - 转义 | 字符" {
	run string.escape.sed "a|b|c"
	[ "$status" -eq 0 ]
	[ "$output" = "a\|b\|c" ]
}

@test "string.escape.sed - 转义反斜杠" {
	run string.escape.sed 'C:\Windows'
	[ "$status" -eq 0 ]
	[ "$output" = 'C:\\Windows' ]
}

@test "string.escape.sed - 混合特殊字符" {
	run string.escape.sed 'C:\Windows&a|b'
	[ "$status" -eq 0 ]
	[ "$output" = "C:\\\\Windows\&a\|b" ]
}

@test "string.escape.sed - 空字符串返回空" {
	run string.escape.sed ""
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

# ============ string.escape.regex 测试 ============

@test "string.escape.regex - 转义方括号" {
	run string.escape.regex "[test]"
	[ "$status" -eq 0 ]
	[ "$output" = "\[test\]" ]
}

@test "string.escape.regex - 转义斜杠" {
	run string.escape.regex "/usr/local/bin"
	[ "$status" -eq 0 ]
	[ "$output" = "\/usr\/local\/bin" ]
}

@test "string.escape.regex - 转义点号" {
	run string.escape.regex "file.txt"
	[ "$status" -eq 0 ]
	[ "$output" = "file\.txt" ]
}

@test "string.escape.regex - 转义星号" {
	run string.escape.regex "*.*"
	[ "$status" -eq 0 ]
	[ "$output" = "\*\.\*" ]
}

@test "string.escape.regex - 转义问号" {
	run string.escape.regex "?"
	[ "$status" -eq 0 ]
	[ "$output" = "\?" ]
}

@test "string.escape.regex - 转义加号" {
	run string.escape.regex "a+b"
	[ "$status" -eq 0 ]
	[ "$output" = "a\+b" ]
}

@test "string.escape.regex - 转义圆括号" {
	run string.escape.regex "(group)"
	[ "$status" -eq 0 ]
	[ "$output" = "\(group\)" ]
}

@test "string.escape.regex - 转义花括号" {
	run string.escape.regex "{1,3}"
	[ "$status" -eq 0 ]
	[ "$output" = "\{1,3\}" ]
}

@test "string.escape.regex - 转义脱字符" {
	run string.escape.regex "^start"
	[ "$status" -eq 0 ]
	[ "$output" = "\^start" ]
}

@test "string.escape.regex - 转义美元符" {
	run string.escape.regex "end$"
	[ "$status" -eq 0 ]
	[ "$output" = "end\\$" ]
}

@test "string.escape.regex - 转义管道符" {
	run string.escape.regex "a|b"
	[ "$status" -eq 0 ]
	[ "$output" = "a\|b" ]
}

@test "string.escape.regex - 转义反斜杠" {
	run string.escape.regex '\n'
	[ "$status" -eq 0 ]
	[ "$output" = '\\n' ]
}

@test "string.escape.regex - 普通字符串不变" {
	run string.escape.regex "hello world"
	[ "$status" -eq 0 ]
	[ "$output" = "hello world" ]
}

@test "string.escape.regex - 空字符串返回空" {
	run string.escape.regex ""
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "string.escape.regex - 混合特殊字符" {
	run string.escape.regex "[a-z]+.*"
	[ "$status" -eq 0 ]
	[ "$output" = "\[a-z\]\+\.\*" ]
}

# ============ string.trim 测试 ============

@test "string.trim - 去除两端空格" {
	run string.trim "  hello world  "
	[ "$status" -eq 0 ]
	[ "$output" = "hello world" ]
}

@test "string.trim - 去除两端tab" {
	run string.trim $'\thello world\t'
	[ "$status" -eq 0 ]
	[ "$output" = "hello world" ]
}

@test "string.trim - 去除混合空白字符" {
	run string.trim $'  \t hello world \n '
	[ "$status" -eq 0 ]
	[ "$output" = "hello world" ]
}

@test "string.trim - 保留中间空白字符" {
	run string.trim "  hello   world  "
	[ "$status" -eq 0 ]
	[ "$output" = "hello   world" ]
}

@test "string.trim - 无空白字符保持不变" {
	run string.trim "hello"
	[ "$status" -eq 0 ]
	[ "$output" = "hello" ]
}

@test "string.trim - 空字符串返回空" {
	run string.trim ""
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "string.trim - 只有空白字符返回空" {
	run string.trim "   "
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

# ============ string.int.check 测试 ============

@test "string.int.check - 正整数返回成功" {
	run string.int.check "123"
	[ "$status" -eq 0 ]
}

@test "string.int.check - 负整数返回成功" {
	run string.int.check "-123"
	[ "$status" -eq 0 ]
}

@test "string.int.check - 0返回成功" {
	run string.int.check "0"
	[ "$status" -eq 0 ]
}

@test "string.int.check - 大数返回成功" {
	run string.int.check "999999999999"
	[ "$status" -eq 0 ]
}

@test "string.int.check - 小数返回失败" {
	run string.int.check "123.45"
	[ "$status" -ne 0 ]
}

@test "string.int.check - 字符串返回失败" {
	run string.int.check "abc"
	[ "$status" -ne 0 ]
}

@test "string.int.check - 混合字符串返回失败" {
	run string.int.check "123abc"
	[ "$status" -ne 0 ]
}

@test "string.int.check - 空字符串返回失败" {
	run string.int.check ""
	[ "$status" -ne 0 ]
}

@test "string.int.check - 只有符号返回失败" {
	run string.int.check "-"
	[ "$status" -ne 0 ]
}

@test "string.int.check - 中间有符号返回失败" {
	run string.int.check "12-34"
	[ "$status" -ne 0 ]
}

# ============ string.natural.check 测试 ============

@test "string.natural.check - 正整数返回成功" {
	run string.natural.check "123"
	[ "$status" -eq 0 ]
}

@test "string.natural.check - 负数返回失败" {
	run string.natural.check "-123"
	[ "$status" -ne 0 ]
}

@test "string.natural.check - 0返回失败" {
	run string.natural.check "0"
	[ "$status" -ne 0 ]
}

@test "string.natural.check - 01返回失败" {
	run string.natural.check "01"
	[ "$status" -ne 0 ]
}

@test "string.natural.check - 小数返回失败" {
	run string.natural.check "123.45"
	[ "$status" -ne 0 ]
}

@test "string.natural.check - 字符串返回失败" {
	run string.natural.check "abc"
	[ "$status" -ne 0 ]
}

@test "string.natural.check - 空字符串返回失败" {
	run string.natural.check ""
	[ "$status" -ne 0 ]
}

# ============ string.float.check 测试 ============

@test "string.float.check - 正小数返回成功" {
	run string.float.check "123.45"
	[ "$status" -eq 0 ]
}

@test "string.float.check - 负小数返回成功" {
	run string.float.check "-123.45"
	[ "$status" -eq 0 ]
}

@test "string.float.check - 整数返回失败" {
	run string.float.check "123"
	[ "$status" -ne 0 ]
}

@test "string.float.check - 整数.返回失败" {
	run string.float.check "123."
	[ "$status" -ne 0 ]
}

@test "string.float.check - .小数返回失败" {
	run string.float.check ".45"
	[ "$status" -ne 0 ]
}

@test "string.float.check - 0.45返回成功" {
	run string.float.check "0.45"
	[ "$status" -eq 0 ]
}

@test "string.float.check - 字符串返回失败" {
	run string.float.check "abc"
	[ "$status" -ne 0 ]
}

@test "string.float.check - 空字符串返回失败" {
	run string.float.check ""
	[ "$status" -ne 0 ]
}
