#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup
	import core/pass
	import core/log
	log.setLevel INFO
}

teardown() {
	true
}

# ============ 公共函数 ============

_setup_gpg_test() {
	local suffix="$1"
	local name="$2"
	local email="$3"

	_PASS_TMP_DIR=$(mktemp -d)
	_PASS_GPG_HOME="$_PASS_TMP_DIR/gpg"
	mkdir -p "$_PASS_GPG_HOME"

	export GNUPGHOME="$_PASS_GPG_HOME"
	export SCRIPT_NAME="test_pass_${suffix}_$$"
	export XDG_CONFIG_HOME="$_PASS_TMP_DIR"

	_PASS_CONFIG_DIR="$XDG_CONFIG_HOME/$SCRIPT_NAME"
	mkdir -p "$_PASS_CONFIG_DIR"

	_PASS_EMAIL="$email"

	gpg --batch --gen-key --pinentry-mode loopback << EOF 2> /dev/null
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: $name
Name-Email: $email
Expire-Date: 0
%no-protection
%commit
EOF
}

_teardown_gpg_test() {
	unset GNUPGHOME SCRIPT_NAME XDG_CONFIG_HOME SCRIPT_CONFIG_DIR 2> /dev/null || true
	rm -rf "$_PASS_TMP_DIR"
}

_encrypt_secret() {
	echo "$1" | gpg --batch --yes --encrypt --recipient "$_PASS_EMAIL" --output "$_PASS_CONFIG_DIR/$2.gpg" 2> /dev/null
}

# ============ 参数验证测试 ============

@test "pass.get - 参数包含 / 返回失败" {
	run pass.get "path/to/secret"
	[ "$status" -eq 1 ]
}

@test "pass.get - 参数包含 ./ 返回失败" {
	run pass.get "./secret"
	[ "$status" -eq 1 ]
}

@test "pass.get - 参数包含 ../ 返回失败" {
	run pass.get "../secret"
	[ "$status" -eq 1 ]
}

@test "pass.get - 参数包含 .. 返回失败" {
	run pass.get "secret..name"
	[ "$status" -eq 1 ]
}

@test "pass.get - 参数包含多个 .. 返回失败" {
	run pass.get "secret...name"
	[ "$status" -eq 1 ]
}

@test "pass.get - 参数以 .. 开头返回失败" {
	run pass.get "..secret"
	[ "$status" -eq 1 ]
}

@test "pass.get - 参数以 .. 结尾返回失败" {
	run pass.get "secret.."
	[ "$status" -eq 1 ]
}

@test "pass.get - 参数包含 / 在中间返回失败" {
	run pass.get "my/path/secret"
	[ "$status" -eq 1 ]
}

@test "pass.get - 参数以 / 开头返回失败" {
	run pass.get "/secret"
	[ "$status" -eq 1 ]
}

@test "pass.get - 参数以 / 结尾返回失败" {
	run pass.get "secret/"
	[ "$status" -eq 1 ]
}

@test "pass.get - 参数仅包含 / 返回失败" {
	run pass.get "/"
	[ "$status" -eq 1 ]
}

@test "pass.get - 参数仅包含 .. 返回失败" {
	run pass.get ".."
	[ "$status" -eq 1 ]
}

# ============ 允许的字符测试 ============

@test "pass.get - 中文参数通过验证" {
	run pass.get "密码库"
	[ "$status" -eq 1 ]
}

@test "pass.get - emoji 参数通过验证" {
	run pass.get "🔑secret"
	[ "$status" -eq 1 ]
}

@test "pass.get - 包含 @ 的参数通过验证" {
	run pass.get "user@example.com"
	[ "$status" -eq 1 ]
}

@test "pass.get - 包含空格的参数通过验证" {
	run pass.get "my secret name"
	[ "$status" -eq 1 ]
}

@test "pass.get - 包含连字符的参数通过验证" {
	run pass.get "my-secret-name"
	[ "$status" -eq 1 ]
}

@test "pass.get - 包含下划线的参数通过验证" {
	run pass.get "my_secret_name"
	[ "$status" -eq 1 ]
}

@test "pass.get - 包含点号（非 ..）的参数通过验证" {
	run pass.get "secret.name"
	[ "$status" -eq 1 ]
}

@test "pass.get - 包含多个点号（非连续 ..）的参数通过验证" {
	run pass.get "my.secret.name"
	[ "$status" -eq 1 ]
}

@test "pass.get - 包含特殊字符 !@#$%^&*() 的参数通过验证" {
	run pass.get "secret!@#$%^&*()"
	[ "$status" -eq 1 ]
}

@test "pass.get - 包含 Unicode 字符的参数通过验证" {
	run pass.get "密码🔐测试"
	[ "$status" -eq 1 ]
}

@test "pass.get - 纯数字参数通过验证" {
	run pass.get "123456"
	[ "$status" -eq 1 ]
}

@test "pass.get - 纯字母参数通过验证" {
	run pass.get "abcdefghijklmnopqrstuvwxyz"
	[ "$status" -eq 1 ]
}

@test "pass.get - 混合大小写字母参数通过验证" {
	run pass.get "MySecretName"
	[ "$status" -eq 1 ]
}

@test "pass.get - 包含 + 号的参数通过验证" {
	run pass.get "secret+name"
	[ "$status" -eq 1 ]
}

@test "pass.get - 包含 = 号的参数通过验证" {
	run pass.get "secret=name"
	[ "$status" -eq 1 ]
}

@test "pass.get - 包含 : 号的参数通过验证" {
	run pass.get "secret:name"
	[ "$status" -eq 1 ]
}

# ============ 边界条件测试 ============

@test "pass.get - 空参数返回失败" {
	run pass.get ""
	[ "$status" -eq 1 ]
}

@test "pass.get - 单字符参数通过验证" {
	run pass.get "a"
	[ "$status" -eq 1 ]
}

@test "pass.get - 单点号通过验证" {
	run pass.get "."
	[ "$status" -eq 1 ]
}

@test "pass.get - 以点号开头的参数通过验证" {
	run pass.get ".secret"
	[ "$status" -eq 1 ]
}

@test "pass.get - 以点号结尾的参数通过验证" {
	run pass.get "secret."
	[ "$status" -eq 1 ]
}

# ============ 文件不存在测试 ============

@test "pass.get - 文件不存在返回失败" {
	run pass.get "nonexistent_secret_file_xyz"
	[ "$status" -eq 1 ]
}

# ============ 集成测试（需要 gpg） ============

@test "pass.get - gpg 命令不存在时返回失败" {
	# 临时覆盖 PATH，使 gpg 不可用
	local orig_path="$PATH"
	# shellcheck disable=SC2123
	PATH="/tmp/nonexistent_bin_xyz"
	export PATH

	run pass.get "test_secret"
	[ "$status" -eq 1 ]

	PATH="$orig_path"
	export PATH
}

@test "pass.get - 正常解密返回明文（需要 gpg 和测试密钥）" {
	system.command.exist "gpg" || skip "gpg 命令不存在"

	_setup_gpg_test "" "Test User" "test@example.com"
	_encrypt_secret "test_secret_content_123" "test_secret"

	import std/path

	result=$(pass.get "test_secret" 2> /dev/null)
	[ "$result" = "test_secret_content_123" ]

	_teardown_gpg_test
}

@test "pass.get - 解密中文内容（需要 gpg）" {
	system.command.exist "gpg" || skip "gpg 命令不存在"

	_setup_gpg_test "cn" "Test CN" "test-cn@example.com"
	_encrypt_secret "中文密码内容测试" "中文密码"

	import std/path

	result=$(pass.get "中文密码" 2> /dev/null)
	[ "$result" = "中文密码内容测试" ]

	_teardown_gpg_test
}

@test "pass.get - 解密带 emoji 的名称（需要 gpg）" {
	system.command.exist "gpg" || skip "gpg 命令不存在"

	_setup_gpg_test "emoji" "Test Emoji" "test-emoji@example.com"
	_encrypt_secret "emoji_secret" "🔑secret"

	import std/path

	result=$(pass.get "🔑secret" 2> /dev/null)
	[ "$result" = "emoji_secret" ]

	_teardown_gpg_test
}
