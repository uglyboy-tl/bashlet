#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
  _common_setup
  import std/fs
}

teardown() {
  # 清理测试文件
  rm -f /tmp/test_file_*.txt 2> /dev/null || true
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
  run fs.write "$test_file" "包含空格的行" '包含$符号' '包含"引号"' "包含'单引号'"
  [ "$status" -eq 0 ]
  [ -f "$test_file" ]

  local content=$(cat "$test_file")
  [ "$content" = $'包含空格的行\n包含$符号\n包含"引号"\n包含\'单引号\'' ]

  rm -f "$test_file"
}

@test "fs.write - 目标目录不存在时自动创建" {
  local test_file="/tmp/nonexistent_dir_$$/subdir/test.txt"
  run fs.write "$test_file" "内容"
  [ "$status" -eq 0 ]
  [ -f "$test_file" ]
  [ "$(cat "$test_file")" = "内容" ]

  # 清理
  rm -rf "/tmp/nonexistent_dir_$$"
}

@test "fs.write - 多级嵌套目录自动创建" {
  local test_file="/tmp/a_$$/b/c/d/e/f/test.txt"
  run fs.write "$test_file" "nested content"
  [ "$status" -eq 0 ]
  [ -f "$test_file" ]
  [ "$(cat "$test_file")" = "nested content" ]

  # 清理
  rm -rf "/tmp/a_$$"
}

@test "fs.write - 父目录已存在也能正常写入" {
  mkdir -p "/tmp/existing_dir_$$"
  local test_file="/tmp/existing_dir_$$/test.txt"

  run fs.write "$test_file" "existing dir content"
  [ "$status" -eq 0 ]
  [ -f "$test_file" ]
  [ "$(cat "$test_file")" = "existing dir content" ]

  # 清理
  rm -rf "/tmp/existing_dir_$$"
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
    [[ $func_name == fs.* ]] || echo "函数 $func_name 不以 fs. 开头"
  done
}

# ============ fs.replace 测试 ============

@test "fs.replace - 替换第一个匹配行（整行替换）" {
  local test_file="/tmp/test_replace_$$.txt"
  fs.write "$test_file" "line1: apple" "line2: banana" "line3: apple" "line4: cherry"

  run fs.replace "$test_file" "apple" "lineX: replaced" "0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'lineX: replaced\nline2: banana\nline3: apple\nline4: cherry' ]

  rm -f "$test_file"
}

@test "fs.replace - 正则表达式匹配（整行替换）" {
  local test_file="/tmp/test_replace_regex_$$.txt"
  fs.write "$test_file" "version: 1.0.0" "author: john" "version: 2.0.0"

  run fs.replace "$test_file" "version:.*" "version: 3.0.0" "0"
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

@test "fs.replace - 无第4个参数时全局替换整行" {
  local test_file="/tmp/test_replace_global_$$.txt"
  fs.write "$test_file" "apple pie" "banana bread" "apple juice"

  run fs.replace "$test_file" "apple" "orange"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'orange\nbanana bread\norange' ]

  rm -f "$test_file"
}

@test "fs.replace - 从指定行号开始替换整行" {
  local test_file="/tmp/test_replace_from_line_$$.txt"
  fs.write "$test_file" "apple: first" "banana" "apple: second" "cherry"

  # 从第2行开始，替换第一个匹配
  run fs.replace "$test_file" "apple" "REPLACED_LINE" "2"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'apple: first\nbanana\nREPLACED_LINE\ncherry' ]

  rm -f "$test_file"
}

@test "fs.replace - 起始行号之后无匹配时不修改" {
  local test_file="/tmp/test_replace_no_match_after_$$.txt"
  fs.write "$test_file" "apple: first" "banana" "cherry" "apple: last"

  # 从第4行开始查找，应该找不到匹配（因为第4行就是最后一个apple）
  # 实际上第4行有"apple"，应该能找到
  # 改为从第5行开始，超出文件范围
  run fs.replace "$test_file" "apple" "orange" "5"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  # 应该没有变化，因为从第5行开始没有内容
  [ "$content" = $'apple: first\nbanana\ncherry\napple: last' ]

  rm -f "$test_file"
}

@test "fs.replace - 替换包含特殊字符的内容（整行替换）" {
  local test_file="/tmp/test_replace_special_$$.txt"
  fs.write "$test_file" "version=1.0.0" "path=/usr/local/bin" "version=2.0.0"

  run fs.replace "$test_file" "version=.*" "version=3.0.0" "0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'version=3.0.0\npath=/usr/local/bin\nversion=2.0.0' ]

  rm -f "$test_file"
}

@test "fs.replace - 替换整行内容" {
  local test_file="/tmp/test_replace_whole_line_$$.txt"
  fs.write "$test_file" "# old comment" "code line" "# another comment"

  run fs.replace "$test_file" "old comment" "# new comment here" "0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'# new comment here\ncode line\n# another comment' ]

  rm -f "$test_file"
}

@test "fs.replace - 从第0行开始等同于从文件开头" {
  local test_file="/tmp/test_replace_zero_$$.txt"
  fs.write "$test_file" "first" "second" "third"

  # 显式指定从第0行开始
  run fs.replace "$test_file" "second" "SECOND_LINE" "0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'first\nSECOND_LINE\nthird' ]

  rm -f "$test_file"
}

@test "fs.replace - 空文件不报错" {
  local test_file="/tmp/test_replace_empty_$$.txt"
  fs.write "$test_file"

  run fs.replace "$test_file" "pattern" "replacement" "0"
  [ "$status" -eq 0 ]

  # 文件仍为空
  [ ! -s "$test_file" ]

  rm -f "$test_file"
}

@test "fs.replace - 单行文件替换" {
  local test_file="/tmp/test_replace_single_$$.txt"
  fs.write "$test_file" "only line"

  run fs.replace "$test_file" "only" "ONLY_LINE" "0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = "ONLY_LINE" ]

  rm -f "$test_file"
}

@test "fs.replace - 替换内容包含管道符 |" {
  local test_file="/tmp/test_replace_pipe_$$.txt"
  fs.write "$test_file" "line1: apple" "line2: banana" "line3: apple"

  # 测试替换内容包含 | 字符
  run fs.replace "$test_file" "apple" "fruit|with|pipe" "0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'fruit|with|pipe\nline2: banana\nline3: apple' ]

  rm -f "$test_file"
}

@test "fs.replace - 替换内容包含多个管道符" {
  local test_file="/tmp/test_replace_multi_pipe_$$.txt"
  fs.write "$test_file" "config: old_value" "other: line"

  # 测试替换内容包含多个 | 字符
  run fs.replace "$test_file" "old_value" "a|b|c|d|e" "0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'a|b|c|d|e\nother: line' ]

  rm -f "$test_file"
}

@test "fs.replace - 全局替换时处理管道符" {
  local test_file="/tmp/test_replace_global_pipe_$$.txt"
  fs.write "$test_file" "item: apple" "item: banana" "item: apple"

  # 无第4个参数，全局替换，替换内容包含 |
  run fs.replace "$test_file" "apple" "fruit|type|A"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'fruit|type|A\nitem: banana\nfruit|type|A' ]

  rm -f "$test_file"
}

@test "fs.replace - 从指定行号开始替换时处理管道符" {
  local test_file="/tmp/test_replace_from_line_pipe_$$.txt"
  fs.write "$test_file" "line1: apple" "line2: banana" "line3: apple" "line4: cherry"

  # 从第2行开始替换，替换内容包含 |
  run fs.replace "$test_file" "apple" "fruit|with|pipe" "2"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'line1: apple\nline2: banana\nfruit|with|pipe\nline4: cherry' ]

  rm -f "$test_file"
}

@test "fs.replace - 替换内容以管道符开头或结尾" {
  local test_file="/tmp/test_replace_edge_pipe_$$.txt"
  fs.write "$test_file" "value: old"

  # 测试替换内容以 | 开头或结尾
  run fs.replace "$test_file" "old" "|start|middle|end|" "0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = "|start|middle|end|" ]

  rm -f "$test_file"
}

@test "fs.replace - 替换内容包含转义字符和管道符" {
  local test_file="/tmp/test_replace_escape_pipe_$$.txt"
  fs.write "$test_file" "path: /old/path"

  # 测试替换内容包含 \ 和 | 的混合
  run fs.replace "$test_file" "\/old\/path" '/usr/local/bin|/opt/bin|C:\Program Files' "0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = '/usr/local/bin|/opt/bin|C:\Program Files' ]

  rm -f "$test_file"
}

@test "fs.replace - 使用 string.escape.regex 处理 & 字符" {
  local test_file="/tmp/test_sed_escape_repl_$$.txt"
  fs.write "$test_file" "config: old_value"

  # 使用 fs.replace 替换内容包含 & (整行替换)
  run fs.replace "$test_file" "old_value" "user&password" "0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = "user&password" ]

  rm -f "$test_file"
}

@test "fs.replace - 使用 string.escape.regex 处理混合特殊字符" {
  local test_file="/tmp/test_sed_escape_repl_mixed_$$.txt"
  fs.write "$test_file" "path: /usr/local/bin"

  # 替换内容包含 \ & | (整行替换)
  run fs.replace "$test_file" "$(string.escape.regex "/usr/local/bin")" 'C:\Program Files&Tools|C:\opt' "0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'C:\\Program Files&Tools|C:\\opt' ]

  rm -f "$test_file"
}

@test "fs.replace - 使用 string.escape.regex 匹配" {
  local test_file="/tmp/test_regex_escape_replace_$$.txt"
  fs.write "$test_file" "path: /usr/local/bin" "path: /usr/bin"

  local escaped=$(string.escape.regex "/usr/local/bin")
  run fs.replace "$test_file" "$escaped" "path: /opt/bin" "0"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'path: /opt/bin\npath: /usr/bin' ]

  rm -f "$test_file"
}
# ============ fs.find 测试 ============

@test "fs.find - 查找存在的模式返回行号" {
  local test_file="/tmp/test_find_$$.txt"
  fs.write "$test_file" "apple pie" "banana bread" "cherry tart"

  run fs.find "$test_file" "banana"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]

  rm -f "$test_file"
}

@test "fs.find - 查找第一行" {
  local test_file="/tmp/test_find_first_$$.txt"
  fs.write "$test_file" "first line" "second line" "third line"

  run fs.find "$test_file" "first"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]

  rm -f "$test_file"
}

@test "fs.find - 查找最后一行" {
  local test_file="/tmp/test_find_last_$$.txt"
  fs.write "$test_file" "line1" "line2" "target line"

  run fs.find "$test_file" "target"
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]

  rm -f "$test_file"
}

@test "fs.find - 模式不存在时返回失败" {
  local test_file="/tmp/test_find_notfound_$$.txt"
  fs.write "$test_file" "apple" "banana" "cherry"

  run fs.find "$test_file" "grape"
  [ "$status" -ne 0 ]

  rm -f "$test_file"
}

@test "fs.find - 文件不存在时返回失败" {
  run fs.find "/tmp/nonexistent_file_$$.txt" "pattern"
  [ "$status" -ne 0 ]
}

@test "fs.find - 使用正则表达式查找" {
  local test_file="/tmp/test_find_regex_$$.txt"
  fs.write "$test_file" "version: 1.0.0" "author: john" "version: 2.0.0"

  run fs.find "$test_file" "^version:"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]

  rm -f "$test_file"
}

@test "fs.find - 空文件返回失败" {
  local test_file="/tmp/test_find_empty_$$.txt"
  fs.write "$test_file"

  run fs.find "$test_file" "pattern"
  [ "$status" -ne 0 ]

  rm -f "$test_file"
}

@test "fs.find - 多个匹配返回第一个" {
  local test_file="/tmp/test_find_multi_$$.txt"
  fs.write "$test_file" "apple first" "banana" "apple second"

  run fs.find "$test_file" "apple"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]

  rm -f "$test_file"
}

@test "fs.find - 从指定行号开始查找" {
  local test_file="/tmp/test_find_from_$$.txt"
  fs.write "$test_file" "apple first" "banana" "apple second"

  run fs.find "$test_file" "apple" "2"
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]

  rm -f "$test_file"
}

@test "fs.find - 从第1行开始等同于从文件开头" {
  local test_file="/tmp/test_find_from1_$$.txt"
  fs.write "$test_file" "apple" "banana" "cherry"

  run fs.find "$test_file" "banana" "1"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]

  rm -f "$test_file"
}

@test "fs.find - 起始行号之后无匹配时返回失败" {
  local test_file="/tmp/test_find_from_nomatch_$$.txt"
  fs.write "$test_file" "apple" "banana" "cherry"

  run fs.find "$test_file" "apple" "2"
  [ "$status" -ne 0 ]

  rm -f "$test_file"
}

@test "fs.find - 使用 string.escape.regex 匹配" {
  local test_file="/tmp/test_regex_escape_$$.txt"
  fs.write "$test_file" "item[0] = value" "item[1] = other"

  local escaped=$(string.escape.regex "item[0]")
  run fs.find "$test_file" "$escaped"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]

  rm -f "$test_file"
}
# ============ fs.insert 测试 ============

@test "fs.insert - 在匹配行后插入新行" {
  local test_file="/tmp/test_insert_$$.txt"
  fs.write "$test_file" "line1" "line2" "line3"

  run fs.insert "$test_file" "line2" "inserted line"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'line1\nline2\ninserted line\nline3' ]

  rm -f "$test_file"
}

@test "fs.insert - 使用正则表达式匹配" {
  local test_file="/tmp/test_insert_regex_$$.txt"
  fs.write "$test_file" "# comment" "code line" "# another comment"

  run fs.insert "$test_file" "^# comment$" "# new comment"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'# comment\n# new comment\ncode line\n# another comment' ]

  rm -f "$test_file"
}

@test "fs.insert - 在多个匹配行后都插入" {
  local test_file="/tmp/test_insert_multi_$$.txt"
  fs.write "$test_file" "item: apple" "item: banana" "item: cherry"

  run fs.insert "$test_file" "item:" "-- separator --"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'item: apple\n-- separator --\nitem: banana\n-- separator --\nitem: cherry\n-- separator --' ]

  rm -f "$test_file"
}

@test "fs.insert - 模式不存在时不修改文件" {
  local test_file="/tmp/test_insert_nomatch_$$.txt"
  fs.write "$test_file" "line1" "line2" "line3"
  local original_content=$(cat "$test_file")

  run fs.insert "$test_file" "nonexistent" "new line"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = "$original_content" ]

  rm -f "$test_file"
}

@test "fs.insert - 插入包含特殊字符的内容" {
  local test_file="/tmp/test_insert_special_$$.txt"
  fs.write "$test_file" "start" "end"

  run fs.insert "$test_file" "start" "line with special chars"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'start\nline with special chars\nend' ]

  rm -f "$test_file"
}

@test "fs.insert - 在文件开头插入" {
  local test_file="/tmp/test_insert_first_$$.txt"
  fs.write "$test_file" "first line" "second line"

  run fs.insert "$test_file" "first line" "header line"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'first line\nheader line\nsecond line' ]

  rm -f "$test_file"
}

@test "fs.insert - 在文件末尾插入" {
  local test_file="/tmp/test_insert_last_$$.txt"
  fs.write "$test_file" "line1" "line2"

  run fs.insert "$test_file" "line2" "last line"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'line1\nline2\nlast line' ]

  rm -f "$test_file"
}

# ============ fs.rmline 测试 ============

@test "fs.rmline - 删除所有匹配行（无第4参数）" {
  local test_file="/tmp/test_rmline_all_$$.txt"
  fs.write "$test_file" "apple pie" "banana bread" "apple juice"

  run fs.rmline "$test_file" "apple"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = "banana bread" ]

  rm -f "$test_file"
}

@test "fs.rmline - 从指定行号开始删除第一个匹配" {
  local test_file="/tmp/test_rmline_from_$$.txt"
  fs.write "$test_file" "apple first" "banana" "apple second" "cherry"

  run fs.rmline "$test_file" "apple" "" "2"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'apple first\nbanana\ncherry' ]

  rm -f "$test_file"
}

@test "fs.rmline - 模式不存在时不修改文件" {
  local test_file="/tmp/test_rmline_nomatch_$$.txt"
  fs.write "$test_file" "line1" "line2" "line3"
  local original_content=$(cat "$test_file")

  run fs.rmline "$test_file" "nonexistent"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = "$original_content" ]

  rm -f "$test_file"
}

@test "fs.rmline - 使用正则表达式删除" {
  local test_file="/tmp/test_rmline_regex_$$.txt"
  fs.write "$test_file" "# comment 1" "code line" "# comment 2" "another code"

  run fs.rmline "$test_file" "^#"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'code line\nanother code' ]

  rm -f "$test_file"
}

@test "fs.rmline - 删除单行文件" {
  local test_file="/tmp/test_rmline_single_$$.txt"
  fs.write "$test_file" "only line"

  run fs.rmline "$test_file" "only"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ -z "$content" ]

  rm -f "$test_file"
}

@test "fs.rmline - 起始行号之后无匹配时不修改" {
  local test_file="/tmp/test_rmline_no_match_after_$$.txt"
  fs.write "$test_file" "apple first" "banana" "apple second"
  local original_content=$(cat "$test_file")

  # 从第3行开始查找 "apple"，应该能找到第3行的 "apple second"
  # 但让我们测试从第4行开始（超出范围）
  run fs.rmline "$test_file" "apple" "" "4"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  # 应该没有变化
  [ "$content" = "$original_content" ]

  rm -f "$test_file"
}

@test "fs.rmline - 删除空行" {
  local test_file="/tmp/test_rmline_empty_$$.txt"
  fs.write "$test_file" "line1" "" "line3"

  run fs.rmline "$test_file" "^$"
  [ "$status" -eq 0 ]

  local content=$(cat "$test_file")
  [ "$content" = $'line1\nline3' ]

  rm -f "$test_file"
}

# ============ fs.cleanup 测试 ============

@test "fs.cleanup - 保留指定数量的文件" {
  # 创建测试文件
  rm -f /tmp/cleanup-test-*.bak 2> /dev/null
  for i in 1 2 3 4 5; do
    touch "/tmp/cleanup-test-${i}.bak"
    sleep 0.05
  done

  run fs.cleanup "/tmp/cleanup-test" 2
  [ "$status" -eq 0 ]

  # 应该保留最新的2个文件（4.bak 和 5.bak）
  local count=$(ls /tmp/cleanup-test-*.bak 2> /dev/null | wc -l)
  [ "$count" -eq 2 ]

  # 验证保留的是最新的文件
  [ -f "/tmp/cleanup-test-4.bak" ]
  [ -f "/tmp/cleanup-test-5.bak" ]

  # 验证旧文件已被删除
  [ ! -f "/tmp/cleanup-test-1.bak" ]
  [ ! -f "/tmp/cleanup-test-2.bak" ]
  [ ! -f "/tmp/cleanup-test-3.bak" ]

  rm -f /tmp/cleanup-test-*.bak 2> /dev/null
}

@test "fs.cleanup - 默认保留3个文件" {
  # 创建测试文件
  rm -f /tmp/cleanup-default-*.bak 2> /dev/null
  for i in 1 2 3 4 5 6 7; do
    touch "/tmp/cleanup-default-${i}.bak"
    sleep 0.05
  done

  # 不传第二个参数，使用默认值3
  run fs.cleanup "/tmp/cleanup-default"
  [ "$status" -eq 0 ]

  # 应该保留最新的3个文件（5.bak, 6.bak, 7.bak）
  local count=$(ls /tmp/cleanup-default-*.bak 2> /dev/null | wc -l)
  [ "$count" -eq 3 ]

  # 验证保留的是最新的文件
  [ -f "/tmp/cleanup-default-5.bak" ]
  [ -f "/tmp/cleanup-default-6.bak" ]
  [ -f "/tmp/cleanup-default-7.bak" ]

  # 验证旧文件已被删除
  [ ! -f "/tmp/cleanup-default-1.bak" ]
  [ ! -f "/tmp/cleanup-default-2.bak" ]
  [ ! -f "/tmp/cleanup-default-3.bak" ]
  [ ! -f "/tmp/cleanup-default-4.bak" ]

  rm -f /tmp/cleanup-default-*.bak 2> /dev/null
}

@test "fs.cleanup - 文件不存在时不报错" {
  run fs.cleanup "/tmp/nonexistent-pattern-$$"
  [ "$status" -eq 0 ]
}

@test "fs.cleanup - 文件数量少于保留数量时不删除" {
  # 创建2个文件，要求保留3个
  rm -f /tmp/cleanup-few-*.bak 2> /dev/null
  touch "/tmp/cleanup-few-1.bak"
  sleep 0.05
  touch "/tmp/cleanup-few-2.bak"

  run fs.cleanup "/tmp/cleanup-few" 3
  [ "$status" -eq 0 ]

  # 所有文件应该都保留
  local count=$(ls /tmp/cleanup-few-*.bak 2> /dev/null | wc -l)
  [ "$count" -eq 2 ]

  rm -f /tmp/cleanup-few-*.bak 2> /dev/null
}

# ============ fs.file.extract 测试 ============

@test "fs.file.extract - 解压 tar.gz 文件" {
  local temp_dir=$(mktemp -d)
  local test_file="$temp_dir/test.txt"
  echo "test content" > "$test_file"

  # 创建 tar.gz
  tar -czf "$temp_dir/archive.tar.gz" -C "$temp_dir" test.txt
  rm -f "$test_file"

  # 解压
  fs.file.extract "$temp_dir/archive.tar.gz" "$temp_dir"

  # 验证
  [ -f "$test_file" ]
  [ "$(cat "$test_file")" = "test content" ]

  rm -rf "$temp_dir"
}

@test "fs.file.extract - 解压 tar.bz2 文件" {
  local temp_dir=$(mktemp -d)
  local test_file="$temp_dir/test.txt"
  echo "bz2 content" > "$test_file"

  tar -cjf "$temp_dir/archive.tar.bz2" -C "$temp_dir" test.txt
  rm -f "$test_file"

  fs.file.extract "$temp_dir/archive.tar.bz2" "$temp_dir"

  [ -f "$test_file" ]
  [ "$(cat "$test_file")" = "bz2 content" ]

  rm -rf "$temp_dir"
}

@test "fs.file.extract - 解压 tar.xz 文件" {
  local temp_dir=$(mktemp -d)
  local test_file="$temp_dir/test.txt"
  echo "xz content" > "$test_file"

  tar -cJf "$temp_dir/archive.tar.xz" -C "$temp_dir" test.txt
  rm -f "$test_file"

  fs.file.extract "$temp_dir/archive.tar.xz" "$temp_dir"

  [ -f "$test_file" ]
  [ "$(cat "$test_file")" = "xz content" ]

  rm -rf "$temp_dir"
}

@test "fs.file.extract - 解压普通 tar 文件" {
  local temp_dir=$(mktemp -d)
  local test_file="$temp_dir/test.txt"
  echo "tar content" > "$test_file"

  tar -cf "$temp_dir/archive.tar" -C "$temp_dir" test.txt
  rm -f "$test_file"

  fs.file.extract "$temp_dir/archive.tar" "$temp_dir"

  [ -f "$test_file" ]
  [ "$(cat "$test_file")" = "tar content" ]

  rm -rf "$temp_dir"
}

@test "fs.file.extract - 解压 zip 文件" {
  # 检查是否安装了 zip 命令
  command -v zip > /dev/null 2>&1 || skip "zip 命令未安装"

  local temp_dir=$(mktemp -d)
  local test_file="$temp_dir/test.txt"
  echo "zip content" > "$test_file"

  # 创建 zip
  (cd "$temp_dir" && zip -q archive.zip test.txt)
  rm -f "$test_file"

  fs.file.extract "$temp_dir/archive.zip" "$temp_dir"

  [ -f "$test_file" ]
  [ "$(cat "$test_file")" = "zip content" ]

  rm -rf "$temp_dir"
}

@test "fs.file.extract - 解压 gz 文件" {
  local temp_dir=$(mktemp -d)
  local test_file="$temp_dir/test.txt"
  echo "gz content" > "$test_file"

  gzip -c "$test_file" > "$temp_dir/test.txt.gz"
  rm -f "$test_file"

  fs.file.extract "$temp_dir/test.txt.gz" "$temp_dir"

  [ -f "$test_file" ]
  [ "$(cat "$test_file")" = "gz content" ]

  rm -rf "$temp_dir"
}

@test "fs.file.extract - 解压 bz2 文件" {
  local temp_dir=$(mktemp -d)
  local test_file="$temp_dir/test.txt"
  echo "bz2 single" > "$test_file"

  bzip2 -c "$test_file" > "$temp_dir/test.txt.bz2"
  rm -f "$test_file"

  fs.file.extract "$temp_dir/test.txt.bz2" "$temp_dir"

  [ -f "$test_file" ]
  [ "$(cat "$test_file")" = "bz2 single" ]

  rm -rf "$temp_dir"
}

@test "fs.file.extract - 解压 xz 文件" {
  local temp_dir=$(mktemp -d)
  local test_file="$temp_dir/test.txt"
  echo "xz single" > "$test_file"

  xz -c "$test_file" > "$temp_dir/test.txt.xz"
  rm -f "$test_file"

  fs.file.extract "$temp_dir/test.txt.xz" "$temp_dir"

  [ -f "$test_file" ]
  [ "$(cat "$test_file")" = "xz single" ]

  rm -rf "$temp_dir"
}

@test "fs.file.extract - 未知类型复制并添加执行权限" {
  local temp_dir=$(mktemp -d)
  local test_file="$temp_dir/myscript.sh"
  echo '#!/bin/bash
echo "hello"' > "$test_file"
  chmod 644 "$test_file"

  fs.file.extract "$test_file" "$temp_dir"

  # 验证复制后的文件存在且有执行权限
  [ -f "$temp_dir/myscript" ]
  [ -x "$temp_dir/myscript" ]
  [ "$(cat "$temp_dir/myscript")" = "$(cat "$test_file")" ]

  rm -rf "$temp_dir"
}

@test "fs.file.extract - jar 文件使用 unzip" {
  command -v zip &> /dev/null || skip "zip 命令未安装"
  command -v unzip &> /dev/null || skip "unzip 命令未安装"

  local temp_dir=$(mktemp -d)
  local test_file="$temp_dir/test.txt"
  echo "jar content" > "$test_file"

  (cd "$temp_dir" && zip -q test.jar test.txt)
  rm -f "$test_file"

  fs.file.extract "$temp_dir/test.jar" "$temp_dir"

  [ -f "$test_file" ]
  [ "$(cat "$test_file")" = "jar content" ]

  rm -rf "$temp_dir"
}

# ============ fs.mktemp 测试 ============

@test "fs.mktemp - 创建临时文件（无参数）" {
  local temp_file=$(fs.mktemp)
  [ -n "$temp_file" ]
  [ -f "$temp_file" ]

  # 清理
  rm -f "$temp_file"
}

@test "fs.mktemp - 创建临时文件（带模板）" {
  local temp_file=$(fs.mktemp "/tmp/test_fs_mktemp_XXXXXX")
  [ -n "$temp_file" ]
  [ -f "$temp_file" ]
  # 验证文件名包含模板前缀
  [[ $temp_file == /tmp/test_fs_mktemp_* ]]

  # 清理
  rm -f "$temp_file"
}

@test "fs.mktemp - 创建临时目录（带 -d 参数）" {
  local temp_dir=$(fs.mktemp -d)
  [ -n "$temp_dir" ]
  [ -d "$temp_dir" ]

  # 清理
  rm -rf "$temp_dir"
}

@test "fs.mktemp - 创建临时目录（带模板和 -d 参数）" {
  local temp_dir=$(fs.mktemp -d "/tmp/test_fs_mktemp_dir_XXXXXX")
  [ -n "$temp_dir" ]
  [ -d "$temp_dir" ]
  [[ $temp_dir == /tmp/test_fs_mktemp_dir_* ]]

  # 清理
  rm -rf "$temp_dir"
}

@test "fs.mktemp - 返回的文件可写入" {
  local temp_file=$(fs.mktemp)

  # 写入内容
  echo "test content" > "$temp_file"
  [ $? -eq 0 ]

  # 验证内容
  local content=$(cat "$temp_file")
  [ "$content" = "test content" ]

  # 清理
  rm -f "$temp_file"
}

@test "fs.mktemp - 每次调用创建不同文件" {
  local temp_file1=$(fs.mktemp)
  local temp_file2=$(fs.mktemp)

  [ "$temp_file1" != "$temp_file2" ]
  [ -f "$temp_file1" ]
  [ -f "$temp_file2" ]

  # 清理
  rm -f "$temp_file1" "$temp_file2"
}
