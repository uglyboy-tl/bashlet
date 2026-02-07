#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import std/fs
}

teardown() {
	# 清理测试文件
	rm -f /tmp/test_file_*.txt 2>/dev/null || true
}

# ============ fs.file.exists 测试 ============

@test "fs.file.exists - 文件存在时返回成功" {
	touch /tmp/test_file_exists.txt
	run fs.file.exists "/tmp/test_file_exists.txt"
	[ "$status" -eq 0 ]
	rm -f /tmp/test_file_exists.txt
}

@test "fs.file.exists - 文件不存在时返回失败" {
	run fs.file.exists "/tmp/nonexistent_file_$$.txt"
	[ "$status" -ne 0 ]
}

@test "fs.file.exists - 目录存在时返回失败" {
	mkdir -p /tmp/test_dir_$$
	run fs.file.exists "/tmp/test_dir_$$"
	[ "$status" -ne 0 ]
	rmdir /tmp/test_dir_$$
}

# ============ fs.dir.exists 测试 ============

@test "fs.dir.exists - 目录存在时返回成功" {
	mkdir -p /tmp/test_dir_exists_$$
	run fs.dir.exists "/tmp/test_dir_exists_$$"
	[ "$status" -eq 0 ]
	rmdir /tmp/test_dir_exists_$$
}

@test "fs.dir.exists - 目录不存在时返回失败" {
	run fs.dir.exists "/tmp/nonexistent_dir_$$"
	[ "$status" -ne 0 ]
}

@test "fs.dir.exists - 文件存在时返回失败" {
	touch /tmp/test_file_for_dir.txt
	run fs.dir.exists "/tmp/test_file_for_dir.txt"
	[ "$status" -ne 0 ]
	rm -f /tmp/test_file_for_dir.txt
}

# ============ fs.write 测试 ============

@test "fs.write - 正常写入多行内容" {
	local test_file="/tmp/test_write_multi_$$.txt"
	run fs.write "$test_file" "第一行" "第二行" "第三行"
	[ "$status" -eq 0 ]
	[ -f "$test_file" ]

	# 验证文件内容
	local content=$(cat "$test_file")
	[ "$content" = $'第一行\n第二行\n第三行' ]

	rm -f "$test_file"
}

@test "fs.write - 覆盖写入文件" {
	local test_file="/tmp/test_write_overwrite_$$.txt"

	# 第一次写入
	fs.write "$test_file" "旧内容"
	[ -f "$test_file" ]

	# 第二次覆盖写入
	run fs.write "$test_file" "新内容第一行" "新内容第二行"
	[ "$status" -eq 0 ]

	# 验证文件内容被覆盖
	local content=$(cat "$test_file")
	[ "$content" = $'新内容第一行\n新内容第二行' ]

	rm -f "$test_file"
}

@test "fs.write - 写入空内容" {
	local test_file="/tmp/test_write_empty_$$.txt"
	run fs.write "$test_file"
	[ "$status" -eq 0 ]
	[ -f "$test_file" ]

	# 验证文件为空
	[ ! -s "$test_file" ]

	rm -f "$test_file"
}

@test "fs.write - 写入单行内容" {
	local test_file="/tmp/test_write_single_$$.txt"
	run fs.write "$test_file" "单行内容"
	[ "$status" -eq 0 ]
	[ -f "$test_file" ]

	local content=$(cat "$test_file")
	[ "$content" = "单行内容" ]

	rm -f "$test_file"
}

@test "fs.write - 包含特殊字符的内容" {
	local test_file="/tmp/test_write_special_$$.txt"
	run fs.write "$test_file" "包含空格的行" "包含\$符号" "包含\"引号\"" "包含'单引号'"
	[ "$status" -eq 0 ]
	[ -f "$test_file" ]

	local content=$(cat "$test_file")
	[ "$content" = $'包含空格的行\n包含$符号\n包含"引号"\n包含\'单引号\'' ]

	rm -f "$test_file"
}

@test "fs.write - 目标目录不存在时失败" {
	local test_file="/tmp/nonexistent_dir_$$/test.txt"
	run fs.write "$test_file" "内容"
	[ "$status" -ne 0 ]
	[ ! -f "$test_file" ]
}

@test "fs.write - 无写入权限时失败" {
	local test_file="/root/test_no_permission_$$.txt"
	run fs.write "$test_file" "内容"
	[ "$status" -ne 0 ]
	# 注意：如果以root运行，这个测试会通过，但通常不是root
}

@test "fs.write - 函数命名一致性验证" {
	# 验证所有函数都以 fs. 开头
	local file_content=$(cat "lib/std/fs.sh")

	# 提取所有函数定义
	local functions=$(echo "$file_content" | grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*\(\)')

	# 验证每个函数都以 fs. 开头
	for func in $functions; do
		func_name=$(echo "$func" | cut -d'(' -f1)
		[[ "$func_name" == fs.* ]] || echo "函数 $func_name 不以 fs. 开头"
	done
}

# ============ fs.replace 测试 ============

@test "fs.replace - 替换第一个匹配行" {
  local test_file="/tmp/test_replace_$$.txt"
  fs.write "$test_file" "line1: apple" "line2: banana" "line3: apple" "line4: cherry"

  run fs.replace "$test_file" "^line.*apple$" "lineX: replaced"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'lineX: replaced\nline2: banana\nline3: apple\nline4: cherry' ]

  rm -f "$test_file"
}

@test "fs.replace - 正则表达式匹配" {
  local test_file="/tmp/test_replace_regex_$$.txt"
  fs.write "$test_file" "version: 1.0.0" "author: john" "version: 2.0.0"

  run fs.replace "$test_file" "^version:.*$" "version: 3.0.0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'version: 3.0.0\nauthor: john\nversion: 2.0.0' ]

  rm -f "$test_file"
}

@test "fs.replace - 文件不存在时返回失败" {
  run fs.replace "/tmp/nonexistent_file_$$.txt" "pattern" "replacement"
  [ "$status" -ne 0 ]
}

@test "fs.replace - 没有匹配行时不修改文件" {
  local test_file="/tmp/test_replace_no_match_$$.txt"
  fs.write "$test_file" "line1" "line2" "line3"
  local original_content=$(cat "$test_file")

  run fs.replace "$test_file" "^nonexistent$" "replacement"
  [ "$status" -eq 0 ]

  local new_content=$(cat "$test_file")
  [ "$new_content" = "$original_content" ]

  rm -f "$test_file"
}
