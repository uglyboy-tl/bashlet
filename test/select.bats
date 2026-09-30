#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import ext/select
}

# 在子 shell 里运行选择器（控制 SELECT_UI 与 stdin），避免污染测试进程
# 用法: _sel <ui> <stdin(%b 转义)> <fn> [args...]
_sel() {
	local ui="$1" input="$2" fn="$3"
	shift 3
	run --separate-stderr bash -c '
		source "$1/lib/std/import.sh"
		import ext/select
		SELECT_UI="$2"
		printf "%b" "$3" | "$4" "${@:5}"
	' _ "$PROJECT_ROOT" "$ui" "$input" "$fn" "$@"
}

# ---- _row_of ----

@test "select._row_of - 命中返回 0-based 行号" {
	run select._row_of b $'a\nb\nc'
	assert_output "1"
}

@test "select._row_of - 未命中返回 -1" {
	run select._row_of z $'a\nb\nc'
	assert_output "-1"
}

@test "select._row_of - 空选中返回 -1" {
	run select._row_of "" $'a\nb'
	assert_output "-1"
}

# ---- select.ui ----

@test "select.ui - 显式 native 直接返回 native" {
	run bash -c 'source "$1/lib/std/import.sh"; import ext/select; SELECT_UI=native; select.ui' _ "$PROJECT_ROOT"
	assert_output "native"
}

@test "select.ui - 显式 gui 且 rofi/显示可用时返回 gui" {
	local dir
	dir="$(_fake_bin rofi 'exit 0')"
	run bash -c 'source "$1/lib/std/import.sh"; import ext/select; PATH="$2:$PATH"; SELECT_UI=gui; DISPLAY=:0; select.ui' _ "$PROJECT_ROOT" "$dir"
	assert_output "gui"
}

@test "select.ui - 显式 gui 但 rofi 不可用时回退 tui" {
	local dir
	dir="$(_fake_bin fzf 'exit 0')"
	run bash -c 'source "$1/lib/std/import.sh"; import ext/select; PATH="$2"; SELECT_UI=gui; DISPLAY=:0; select.ui' _ "$PROJECT_ROOT" "$dir"
	assert_output "tui"
}

# ---- native 后端 ----

@test "select.one - native 输入索引返回对应选项" {
	_sel native "1\n" select.one -p P -d $'a\nb\nc'
	assert_success
	assert_output "b"
}

@test "select.one - native 输入 0 返回第一项" {
	_sel native "0\n" select.one -p P -d $'a\nb\nc'
	assert_output "a"
}

@test "select.one - native 越界返回错误" {
	_sel native "9\n" select.one -p P -d $'a\nb\nc'
	assert_failure
}

@test "select.one - native 非数字返回错误" {
	_sel native "x\n" select.one -p P -d $'a\nb\nc'
	assert_failure
}

@test "select.one - 空候选返回错误" {
	_sel native "" select.one -p P -d ""
	assert_failure
}

@test "select.one - 选项含空格不被拆分" {
	_sel native "1\n" select.one -p P -d $'hello world\nsecond item'
	assert_output "second item"
}

@test "select.many - native 多选返回多行" {
	_sel native "0 2\n" select.many -p P -d $'a\nb\nc'
	assert_success
	assert_output $'a\nc'
}

@test "select.many - native 空输入返回错误" {
	_sel native "\n" select.many -p P -d $'a\nb'
	assert_failure
}

@test "select.many - native 忽略非法索引只返回有效地" {
	_sel native "0 x 2\n" select.many -p P -d $'a\nb\nc'
	assert_output $'a\nc'
}

# ---- 后端分派（用假二进制）----

_fake_bin() { # <名称> <脚本体>
	local dir="$BATS_TEST_TMPDIR/bin"
	mkdir -p "$dir"
	printf '#!/usr/bin/env bash\n%s\n' "$2" > "$dir/$1"
	chmod +x "$dir/$1"
	printf '%s' "$dir"
}

@test "select.one - tui 分派到 fzf 并返回其结果" {
	local dir
	dir="$(_fake_bin fzf 'cat >/dev/null; echo PICKED')"
	PATH="$dir:$PATH" SELECT_UI=tui run select.one -p P -d $'a\nb'
	assert_success
	assert_output "PICKED"
}

@test "select.one - gui 分派到 rofi 并返回其结果" {
	local dir
	dir="$(_fake_bin rofi 'cat >/dev/null; echo RO')"
	PATH="$dir:$PATH" SELECT_UI=gui DISPLAY=:0 run select.one -p P -d $'a\nb'
	assert_success
	assert_output "RO"
}

@test "select.one - fzf 收到提示与选中项定位参数" {
	local dir
	dir="$(_fake_bin fzf "printf '%s\n' \"\$@\" > '$BATS_TEST_TMPDIR/args'; cat >/dev/null; echo c")"
	PATH="$dir:$PATH" SELECT_UI=tui run select.one -p 主题 -d $'a\nb\nc' -s c
	assert_success
	assert_output "c"
	run cat "$BATS_TEST_TMPDIR/args"
	assert_output --partial "--prompt"
	assert_output --partial "主题"
	assert_output --partial "load:pos:3"
}

@test "select.one - fzf 取消返回错误" {
	local dir
	dir="$(_fake_bin fzf 'cat >/dev/null; exit 1')"
	PATH="$dir:$PATH" SELECT_UI=tui run select.one -p P -d $'a\nb'
	assert_failure
}

@test "select.one - 未给 -d 时从 stdin 读取候选" {
	local dir
	dir="$(_fake_bin fzf "cat > '$BATS_TEST_TMPDIR/seen'; echo X")"
	run bash -c '
		source "$1/lib/std/import.sh"
		import ext/select
		PATH="$2:$PATH"
		SELECT_UI=tui
		printf "a\nb\n" | select.one -p P
	' _ "$PROJECT_ROOT" "$dir"
	assert_success
	assert_output "X"
	run cat "$BATS_TEST_TMPDIR/seen"
	assert_output $'a\nb'
}

@test "select.one - fzf 选中第 0 行时也定位" {
	local dir
	dir="$(_fake_bin fzf "printf '%s\n' \"\$@\" > '$BATS_TEST_TMPDIR/args'; cat >/dev/null; echo a")"
	PATH="$dir:$PATH" SELECT_UI=tui run select.one -p P -d $'a\nb\nc' -s a
	assert_success
	run cat "$BATS_TEST_TMPDIR/args"
	assert_output --partial "load:pos:1"
}

@test "select.many - tui 分派到 fzf 并传 -m" {
	local dir
	dir="$(_fake_bin fzf "printf '%s\n' \"\$@\" > '$BATS_TEST_TMPDIR/args'; cat >/dev/null; printf 'a\nc\n'")"
	PATH="$dir:$PATH" SELECT_UI=tui run select.many -p P -d $'a\nb\nc'
	assert_success
	assert_output $'a\nc'
	run cat "$BATS_TEST_TMPDIR/args"
	assert_output --partial "-m"
}

@test "select.one - rofi 带 -i 时附加 icon 标记" {
	local dir img
	dir="$(_fake_bin rofi "cat > '$BATS_TEST_TMPDIR/seen'; echo a")"
	img="$BATS_TEST_TMPDIR/i.png"
	: > "$img"
	PATH="$dir:$PATH" SELECT_UI=gui DISPLAY=:0 run select.one -p P -d $'a\nb' -i "printf '%s' '$img'"
	assert_success
	assert_output "a"
	run cat -v "$BATS_TEST_TMPDIR/seen"
	assert_output --partial "icon"
}

# ---- 旧接口兼容 ----

@test "select.single - 旧接口转发到 select.one" {
	_sel native "1\n" select.single "P" a b c
	assert_output "b"
}

@test "select.single - 无选项返回错误" {
	run select.single "P"
	assert_failure
}

@test "select.multi - 旧接口输出空格连接单行" {
	_sel native "0 2\n" select.multi "P" a b c
	assert_output "a c"
}
