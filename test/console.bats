#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import std/console
}

teardown() {
	# 清理环境变量
	unset console 2> /dev/null || true
}

@test "console.stderr - 基本输出到 stderr" {
	run console.stderr "test message"
	[ "$status" -eq 0 ]
	[ "$output" = "test message" ]
}

@test "console.stderr - 多个参数正确连接" {
	run console.stderr "hello" "world"
	[ "$status" -eq 0 ]
	[ "$output" = "hello world" ]
}

@test "console.stderr - 空参数输出空行" {
	run console.stderr ""
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "console.stderr - 无参数输出空行" {
	run console.stderr
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "console.stderr - 特殊字符处理" {
	run console.stderr 'test with $VAR'
	[ "$status" -eq 0 ]
	[ "$output" = 'test with $VAR' ]
}

@test "console.stderr - 多行消息" {
	run console.stderr "line1" "line2" "line3"
	[ "$status" -eq 0 ]
	[ "$output" = "line1 line2 line3" ]
}

# ========== console.align 测试 ==========

@test "console.align - 基本格式化输出" {
	run console.align 20 "test" "desc"
	[ "$status" -eq 0 ]
	# test (4字符) + 16 空格 = 20字符 + desc (4字符) + 换行符 = 25字符
	# 但在 bats 中 ${#output} 计算字符数 = 24 (不包含换行符)
	[ "${#output}" -eq 24 ]
}

@test "console.align - 文本长度等于宽度不填充" {
	run console.align 4 "test" "desc"
	[ "$status" -eq 0 ]
	[ "$output" = "testdesc" ]
}

@test "console.align - 文本长度超过宽度" {
	run console.align 3 "test" "desc"
	[ "$status" -eq 0 ]
	[ "$output" = "testdesc" ]
}

@test "console.align - 空文本处理" {
	run console.align 10 "" "desc"
	[ "$status" -eq 0 ]
	# 10空格 + desc
	[ "${#output}" -eq 14 ] # 10 + 4 (desc)
}

@test "console.align - 空描述处理" {
	run console.align 10 "test" ""
	[ "$status" -eq 0 ]
	# test (4字符) + 6空格 = 10字符 + 换行符 = 11字节
	# bats ${#output} 计算字符数 = 10
	[ "${#output}" -eq 10 ]
}

@test "console.align - ANSI 转义码不被计入宽度" {
	local red=$'\x1b[31m'  # 5字节
	local reset=$'\x1b[0m' # 4字节

	# width=10, 可见字符="test"(4), padding=6
	# 输出: red(5) + test(4) + reset(4) + 空格(6) + desc(4) + 换行(1)
	#      = 5+4+4+6+4+1 = 24 字节
	run console.align 10 "${red}test${reset}" "desc"
	[ "$status" -eq 0 ]
	[ "${#output}" -eq 23 ] # 24-1 (不含换行符)
}

@test "console.align - 多个 ANSI 转义码正确处理" {
	local red=$'\x1b[31m'   # 5字节
	local green=$'\x1b[32m' # 5字节
	local reset=$'\x1b[0m'  # 4字节

	# width=10, 可见字符="test"(4), padding=6
	# 输出: red(5) + te(2) + green(5) + st(2) + reset(4) + 空格(6) + desc(4) + 换行(1)
	#      = 5+2+5+2+4+6+4+1 = 29 字节
	run console.align 10 "${red}te${green}st${reset}" "desc"
	[ "$status" -eq 0 ]
	[ "${#output}" -eq 28 ] # 29-1 (不含换行符)
}

@test "console.align - 长数字 ANSI 参数处理" {
	local color=$'\x1b[38;2;255;0;0m' # 15字节
	local reset=$'\x1b[0m'            # 4字节

	# width=10, 可见字符="test"(4), padding=6
	# 输出: color(15) + test(4) + reset(4) + 空格(6) + desc(4) + 换行(1)
	#      = 15+4+4+6+4+1 = 34 字节
	run console.align 10 "${color}test${reset}" "desc"
	[ "$status" -eq 0 ]
	[ "${#output}" -eq 33 ] # 34-1 (不含换行符)
}

@test "console.align - 未闭合的 ANSI 转义码" {
	local red=$'\x1b[31m' # 5字节 (无重置码)

	# width=10, 可见字符="test"(4), padding=6
	# 输出: red(5) + test(4) + 空格(6) + desc(4) + 换行(1)
	#      = 5+4+6+4+1 = 20 字节
	run console.align 10 "${red}test" "desc"
	[ "$status" -eq 0 ]
	[ "${#output}" -eq 19 ] # 20-1 (不含换行符)
}

@test "console.align - 零宽度边界" {
	run console.align 0 "test" "desc"
	[ "$status" -eq 0 ]
	[ "$output" = "testdesc" ]
}

@test "console.align - 宽度为1" {
	run console.align 1 "t" "desc"
	[ "$status" -eq 0 ]
	[ "${#output}" -eq 5 ] # t + desc + 换行符
}

@test "console.align - 非常大的宽度" {
	run console.align 1000 "test" "desc"
	[ "$status" -eq 0 ]
	# test + 996空格 + desc + 换行符
	[ "${#output}" -eq 1004 ]
}

@test "console.align - 多字节字符处理" {
	run console.align 10 "测试" "desc"
	[ "$status" -eq 0 ]
	# 2中文字符(4字节) + 6空格 + desc + 换行符
	# 注意: ${#}计算字符数，但 printf 格式化按字节
	# 当前实现按字符数填充空格
	[ "${#output}" -ge 11 ]
}

@test "console.align - 特殊字符在文本中" {
	run console.align 10 'test$VAR' "desc"
	[ "$status" -eq 0 ]
	# test\$VAR (8) + 2空格 + desc (4) + 换行符 (1) = 15字节
	# bats ${#output} 计算字符数 = 14
	[ "${#output}" -eq 14 ]
}

@test "console.align - 换行符在描述中" {
	run console.align 10 "test" "desc
with newline"
	[ "$status" -eq 0 ]
	[[ $output == *"desc"* ]]
}

# ========== console.display_width 测试 ==========

@test "console.display_width - 纯英文文本" {
	run console.display_width "hello"
	[ "$status" -eq 0 ]
	[ "$output" = "5" ]
}

@test "console.display_width - 纯中文文本" {
	run console.display_width "中文"
	[ "$status" -eq 0 ]
	[ "$output" = "4" ]
}

@test "console.display_width - 中英文混排" {
	run console.display_width "hello中文"
	[ "$status" -eq 0 ]
	[ "$output" = "9" ]
}

@test "console.display_width - ANSI 颜色码过滤" {
	local red=$'\x1b[31m'
	local reset=$'\x1b[0m'
	run console.display_width "${red}Red${reset}"
	[ "$status" -eq 0 ]
	[ "$output" = "3" ]
}

@test "console.display_width - 空字符串" {
	run console.display_width ""
	[ "$status" -eq 0 ]
	[ "$output" = "0" ]
}

@test "console.display_width - 多个 ANSI 码" {
	local red=$'\x1b[31m'
	local bold=$'\x1b[1m'
	local reset=$'\x1b[0m'
	run console.display_width "${red}${bold}text${reset}"
	[ "$status" -eq 0 ]
	[ "$output" = "4" ]
}

@test "console.display_width - 复杂 ANSI 码" {
	local color=$'\x1b[38;2;255;0;0m'
	local reset=$'\x1b[0m'
	run console.display_width "${color}colored${reset}"
	[ "$status" -eq 0 ]
	[ "$output" = "7" ]
}

@test "console.display_width - 多行文本" {
	run console.display_width "line1
line2"
	[ "$status" -eq 0 ]
	[ "$output" = "11" ] # line1(5) + 换行符(1) + line2(5)
}

@test "console.display_width - 特殊字符" {
	run console.display_width 'test$VAR'
	[ "$status" -eq 0 ]
	[ "$output" = "8" ]
}

@test "console.display_width - 空字符串 → 0" {
	run console.display_width ""
	[ "$status" -eq 0 ]
	[ "$output" = "0" ]
}

@test "console.display_width - 纯 ASCII 字符串 → 字符数" {
	run console.display_width "hello world"
	[ "$status" -eq 0 ]
	[ "$output" = "11" ]
}

@test "console.display_width - 纯 CJK 字符串 → 字符数 × 2" {
	run console.display_width "中文测试"
	[ "$status" -eq 0 ]
	[ "$output" = "8" ]
}

@test "console.display_width - 混合字符串 (ASCII + CJK) → 正确宽度" {
	run console.display_width "hello中文world"
	[ "$status" -eq 0 ]
	[ "$output" = "14" ] # hello(5) + 中文(4) + world(5)
}

@test "console.display_width - 带 ANSI 转义序列 → 过滤 ANSI 后计算宽度" {
	local red=$'\x1b[31m'
	local reset=$'\x1b[0m'
	run console.display_width "${red}hello${reset}"
	[ "$status" -eq 0 ]
	[ "$output" = "5" ]
}

@test "console.display_width - ANSI + CJK 混合 → 正确过滤和计算" {
	local red=$'\x1b[31m'
	local green=$'\x1b[32m'
	local reset=$'\x1b[0m'
	run console.display_width "${red}中${green}文${reset}hello"
	[ "$status" -eq 0 ]
	[ "$output" = "9" ] # 中文(4) + hello(5)
}

@test "console.display_width - 边界条件 - 单个 ASCII 字符" {
	run console.display_width "a"
	[ "$status" -eq 0 ]
	[ "$output" = "1" ]
}

@test "console.display_width - 边界条件 - 单个 CJK 字符" {
	run console.display_width "中"
	[ "$status" -eq 0 ]
	[ "$output" = "2" ]
}

@test "console.display_width - 边界条件 - 长字符串 (1000+ 字符)" {
	# 创建 1000 个 ASCII 字符的字符串
	local long_string=""
	for ((i = 0; i < 1000; i++)); do
		long_string+="a"
	done
	run console.display_width "$long_string"
	[ "$status" -eq 0 ]
	[ "$output" = "1000" ]
}

@test "console.display_width - 边界条件 - 多个 ANSI 序列" {
	local red=$'\x1b[31m'
	local bold=$'\x1b[1m'
	local underline=$'\x1b[4m'
	local reset=$'\x1b[0m'
	run console.display_width "${red}${bold}${underline}text${reset}"
	[ "$status" -eq 0 ]
	[ "$output" = "4" ]
}

@test "console.display_width - 边界条件 - 空 ANSI 序列" {
	local empty_ansi=$'\x1b[m'
	run console.display_width "${empty_ansi}hello"
	[ "$status" -eq 0 ]
	[ "$output" = "5" ]
}

# ========== console.align 中英文对齐增强测试 ==========

@test "console.align - 中文本本正确对齐" {
	run console.align 10 "中文" "desc"
	[ "$status" -eq 0 ]
	# 中文占 4 列，应填充 6 空格
	[ "${#output}" -eq 12 ] # 中文(2字符) + 6空格 + desc(4字符)
}

@test "console.align - 中英文混排正确对齐" {
	run console.align 15 "hello中文" "desc"
	[ "$status" -eq 0 ]
	# hello中文占 9 列(5+4)，应填充 6 空格
	[ "${#output}" -eq 17 ] # hello中文(7字符) + 6空格 + desc(4字符)
}

@test "console.align - 带 ANSI 码的中文正确对齐" {
	local red=$'\x1b[31m'
	local reset=$'\x1b[0m'
	run console.align 10 "${red}中文${reset}" "desc"
	[ "$status" -eq 0 ]
	# ANSI码被过滤，中文占 4 列，填充 6 空格
	[ "${#output}" -eq 21 ] # red(ANSI) + 中文(2字符) + reset(ANSI) + 6空格 + desc(4字符)
}

@test "console.align - 混合 ANSI 码和中文对齐" {
	local red=$'\x1b[31m'
	local green=$'\x1b[32m'
	local reset=$'\x1b[0m'
	run console.align 12 "${red}中${green}文${reset}" "desc"
	[ "$status" -eq 0 ]
	# ANSI码被过滤，中文占 4 列，填充 8 空格
	[ "${#output}" -eq 28 ] # red + 中 + green + 文 + reset + 8空格 + desc
}

@test "console.align - 长中文字符串截断处理" {
	run console.align 6 "中文测试" "desc"
	[ "$status" -eq 0 ]
	# 中文测试占 8 列，超过宽度 6，不填充
	[ "${#output}" -eq 8 ] # 中文测试(4字符) + desc(4字符)
}

@test "console.align - 精确宽度中文对齐" {
	run console.align 8 "四个字" "desc"
	[ "$status" -eq 0 ]
	# 四个字占 6 列，填充 2 空格
	[ "${#output}" -eq 9 ] # 四个字(3字符) + 2空格 + desc(4字符)
}

@test "console.align - 多个描述参数" {
	run console.align 20 "test" "desc1" "desc2" "desc3"
	[ "$status" -eq 0 ]
	# test(4) + 16空格 + desc1 desc2 desc3(17) = 37
	[ "${#output}" -eq 37 ]
	[[ $output == *"desc1 desc2 desc3" ]]
}

@test "console.align - 3 个参数（2个描述）" {
	run console.align 15 "text" "desc1" "desc2"
	[ "$status" -eq 0 ]
	[[ $output == *"desc1 desc2" ]]
}

@test "console.align - 4 个参数（3个描述）" {
	run console.align 20 "测试" "a" "b" "c"
	[ "$status" -eq 0 ]
	[[ $output == *"a b c" ]]
}

@test "console.align - 多参数中英文混合" {
	run console.align 25 "中文文本" "English" "混合" "Mixed"
	[ "$status" -eq 0 ]
	[[ $output == *"English 混合 Mixed" ]]
}

@test "console.align - 多参数含 ANSI 码" {
	local red=$'\x1b[31m'
	local green=$'\x1b[32m'
	local reset=$'\x1b[0m'
	local desc1="${red}desc1${reset}"
	local desc2="${green}desc2${reset}"
	run console.align 25 "text" "$desc1" "$desc2"
	[ "$status" -eq 0 ]
	# text(4) + padding(21空格) + desc1(14) + 空格(1) + desc2(14) = 54 字符
	[ "${#output}" -eq 54 ]
}

# ========== console.indent 测试 ==========

@test "console.indent - 基本缩进输出" {
	run console.indent 1 "test message"
	[ "$status" -eq 0 ]
	# 缩进级别 1 = 2 个空格 + text(12) = 14 (输出到 stderr)
	[ "${#output}" -eq 14 ]
	[[ $output == "  test message" ]]
}

@test "console.indent - 多级缩进" {
	run console.indent 2 "level 2"
	[ "$status" -eq 0 ]
	# 缩进级别 2 = 4 个空格
	[[ $output == "    level 2" ]]
}

@test "console.indent - 零级缩进" {
	run console.indent 0 "no indent"
	[ "$status" -eq 0 ]
	# 缩进级别 0 = 0 个空格
	[ "$output" = "no indent" ]
}

@test "console.indent - 多个参数" {
	run console.indent 1 "hello" "world"
	[ "$status" -eq 0 ]
	[[ $output == "  hello world" ]]
}

@test "console.indent - 空内容" {
	run console.indent 1 ""
	[ "$status" -eq 0 ]
	# 2 空格 + 空 = 2
	[ "${#output}" -eq 2 ]
}

@test "console.indent - 中文内容" {
	run console.indent 1 "中文测试"
	[ "$status" -eq 0 ]
	# 2 空格 + 4 个中文字符 = 6
	[ "${#output}" -eq 6 ]
}

@test "console.indent - 带 ANSI 码" {
	local red=$'\x1b[31m'
	local reset=$'\x1b[0m'
	run console.indent 1 "${red}red text${reset}"
	[ "$status" -eq 0 ]
	# 2 空格 + ANSI + text + ANSI
	[[ $output == "  ${red}red text${reset}" ]]
}

@test "console.indent - 大缩进级别" {
	run console.indent 10 "deep indent"
	[ "$status" -eq 0 ]
	# 20 空格 + 11 字符 = 31
	[ "${#output}" -eq 31 ]
}

# ========== console.stdout 测试 ==========

@test "console.stdout - 基本输出" {
	run console.stdout "test message"
	[ "$status" -eq 0 ]
	[ "$output" = "test message" ]
}

@test "console.stdout - 多个参数" {
	run console.stdout "hello" "world"
	[ "$status" -eq 0 ]
	[ "$output" = "hello world" ]
}

@test "console.stdout - 空参数" {
	run console.stdout
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "console.stdout - 特殊字符" {
	run console.stdout 'test with $VAR'
	[ "$status" -eq 0 ]
	[ "$output" = 'test with $VAR' ]
}

# ========== console.repeat 测试 ==========

@test "console.repeat - 重复字符" {
	result=$(console.repeat "=" 5)
	[ "$result" = "=====" ]
}

@test "console.repeat - 重复字符串" {
	result=$(console.repeat "ab" 3)
	[ "$result" = "ababab" ]
}

@test "console.repeat - 零次重复" {
	result=$(console.repeat "x" 0)
	[ "$result" = "" ]
}

@test "console.repeat - 默认参数为0" {
	result=$(console.repeat "y")
	[ "$result" = "" ]
}

@test "console.repeat - 单次重复" {
	result=$(console.repeat "-" 1)
	[ "$result" = "-" ]
}

@test "console.repeat - UNDERLINE_CACHE 使用" {
	# 验证缓存变量存在
	[[ -n $UNDERLINE_CACHE ]]
}

# ========== console.section 测试 ==========

@test "console.section - 基本标题输出" {
	run console.section "Title"
	[ "$status" -eq 0 ]
	[[ $output == *"Title:"* ]]
	[[ $output == *"====="* ]]
}

@test "console.section - 中文标题" {
	run console.section "章节"
	[ "$status" -eq 0 ]
	[[ $output == *"章节:"* ]]
}

@test "console.section - 空标题" {
	run console.section ""
	[ "$status" -eq 0 ]
	[[ $output == *":"* ]]
}

# ========== console.item 系列测试 ==========

@test "console.item.title - 基本标题" {
	run console.item.title 0 "Main Title"
	[ "$status" -eq 0 ]
	[[ $output == *"Main Title"* ]]
}

@test "console.item.title - 带缩进级别" {
	run console.item.title 2 "Sub Title"
	[ "$status" -eq 0 ]
	[[ $output == *"Sub Title"* ]]
}

@test "console.item.item - 基本项目" {
	# 先设置缩进深度
	_CONSOLE_INDENT_DEPTH=1
	run console.item.item "item content"
	[ "$status" -eq 0 ]
	[[ $output == *"item content"* ]]
}

@test "console.item.mid - 中间项目" {
	_CONSOLE_INDENT_DEPTH=1
	run console.item.mid "middle item"
	[ "$status" -eq 0 ]
	[[ $output == *"├─"* ]]
	[[ $output == *"middle item"* ]]
}

@test "console.item.end - 结束项目" {
	# 设置缩进深度
	_CONSOLE_INDENT_DEPTH=1

	run console.item.end "last item"
	[ "$status" -eq 0 ]
	# 包含缩进、└─、内容和最后的换行符（空行）
	[[ $output == *"└─ last item"* ]]
}

# ========== console.footer 测试 ==========

@test "console.footer - 基本页脚" {
	run console.footer "Footer Text"
	[ "$status" -eq 0 ]
	[[ $output == *"========="* ]]
	[[ $output == *"Footer Text"* ]]
}

@test "console.footer - 多个参数" {
	run console.footer "Line 1" "Line 2"
	[ "$status" -eq 0 ]
	[[ $output == *"Line 1 Line 2"* ]]
}

@test "console.footer - 无参数" {
	run console.footer
	[ "$status" -eq 0 ]
	[[ $output == *"========="* ]]
}
