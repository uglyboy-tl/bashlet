#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	FIXTURES="$PROJECT_ROOT/test/fixtures/build"
	OUT_DIR="$(mktemp -d)"
	# 切到干净目录，避免宿主仓库的 .env 覆盖 OUTPUT_DIR
	cd "$OUT_DIR"
}

teardown() {
	rm -rf "$OUT_DIR"
}

# 构建 fixture 并返回产物路径
_build_fixture() {
	run env OUTPUT_DIR="$OUT_DIR" "$PROJECT_ROOT/tools/build" "$1"
}

@test "build 静态内联依赖且不残留 import" {
	_build_fixture "$FIXTURES/entry.sh"
	assert_success

	local out="$OUT_DIR/buildfixture"
	[[ -f $out ]]
	# 依赖模块的函数被内联
	grep -q 'string.trim()' "$out"
	grep -q 'log.info()' "$out"
	# import/source/SCRIPT_NAME/PROJECT_ROOT 指令被剥离
	! grep -q '^import ' "$out"
	! grep -q '^source ' "$out"
	# PROJECT_ROOT 保留（产物按其自身位置推导）
	grep -q '^PROJECT_ROOT=' "$out"
}

@test "build 不执行目标脚本（无副作用）" {
	local marker="$OUT_DIR/side_effect"
	run env OUTPUT_DIR="$OUT_DIR" SIDE_EFFECT_MARKER="$marker" \
		"$PROJECT_ROOT/tools/build" "$FIXTURES/side_effect.sh"
	assert_success
	[[ ! -e $marker ]]
}

@test "build 产物头部有 shebang / set / SCRIPT_NAME 且各一次" {
	_build_fixture "$FIXTURES/entry.sh"
	assert_success

	local out="$OUT_DIR/buildfixture"
	[[ "$(head -1 "$out")" == "#!/usr/bin/env bash" ]]
	[[ "$(grep -c '^set -euo pipefail$' "$out")" -eq 1 ]]
	[[ "$(grep -c '^SCRIPT_NAME=' "$out")" -eq 1 ]]
}

@test "build 剥离 .env 调用（产物不读本地 .env）" {
	_build_fixture "$FIXTURES/entry.sh"
	assert_success

	! grep -qE '^\.env([[:space:]]|$)' "$OUT_DIR/buildfixture"
	! grep -qE '^\.env\(\)|^\.env \(\)' "$OUT_DIR/buildfixture"
}

@test "build # build:keep-env 指令时保留 .env" {
	_build_fixture "$FIXTURES/entry_keep_env.sh"
	assert_success

	local out="$OUT_DIR/entry_keep_env"
	grep -qE '^\.env$' "$out"
	grep -qE '^\.env\(\)|^\.env \(\)' "$out"
}

@test "build 产物语法有效且可执行" {
	_build_fixture "$FIXTURES/entry.sh"
	assert_success

	local out="$OUT_DIR/buildfixture"
	[[ -x $out ]]
	bash -n "$out"
}

@test "build 无法解析的 import 时失败并报错" {
	run env OUTPUT_DIR="$OUT_DIR" "$PROJECT_ROOT/tools/build" "$FIXTURES/bad_import.sh"
	[ "$status" -ne 0 ]
	[[ $output == *"无法解析 import"* ]]
}
