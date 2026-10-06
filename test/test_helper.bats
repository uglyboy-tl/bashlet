#!/usr/bin/env bats

# 测 test_helper 自己的设施（_fast_load 的语义很容易回归，且影响所有包）

load 'test_helper/common-setup'

setup() {
	_common_setup
}

@test "_fast_load: 加载期关掉 functrace，之后按原样恢复" {
	run bash -c '
		set -euT
		source "$1"
		probe() { case "$-" in *T*) echo "during=T-on" ;; *) echo "during=T-off" ;; esac; }
		_fast_load probe
		case "$-" in *T*) echo "after=T-on" ;; *) echo "after=T-off" ;; esac
	' _ "$PROJECT_ROOT/test/test_helper/common-setup.bash"
	assert_success
	assert_line --index 0 "during=T-off"
	assert_line --index 1 "after=T-on"
}

@test "_fast_load: 被加载的脚本出错时 fail fast，不静默吞掉" {
	printf 'false\ntouch "%s/not-created"\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/bad.sh"
	run bash -c '
		set -euo pipefail
		source "$1"
		_fast_load source "$2"
		echo "不该到这里"
	' _ "$PROJECT_ROOT/test/test_helper/common-setup.bash" "$BATS_TEST_TMPDIR/bad.sh"
	assert_failure
	refute_output --partial "不该到这里"
	[ ! -e "$BATS_TEST_TMPDIR/not-created" ]
}
