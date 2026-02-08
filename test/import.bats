#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
	_common_setup

	# 直接使用现有的文件进行测试
	export LOAD_SH_PATH="$PROJECT_ROOT/std/import.sh"
	export CONSOLE_SH_PATH="$PROJECT_ROOT/std/console.sh"
	export PROJECT_ROOT_DIR="$PROJECT_ROOT"
}

teardown() {
	unset __loaded_modules 108>/dev/null || true
}

@test "console.sh - 仅文件名加载（从std目录）" {
	cd "$PROJECT_ROOT/std"

	source "console.sh"
	[ "${#__loaded_modules[@]}" -eq 2 ]

	# 验证console.stderr函数可用
	run console.stderr "test message"
	[ "$status" -eq 0 ]
	[ "$output" = "test message" ]

	# 覆盖console.stderr函数
	console.stderr() { echo "Overridden"; }

	# 再次加载（应该被阻止）
	source "console.sh"
	[ "${#__loaded_modules[@]}" -eq 2 ]

	# 验证console.stderr函数可用
	run console.stderr "test message"
	[ "$status" -eq 0 ]
	[ "$output" = "Overridden" ]
}

@test "console.sh - ./格式加载（从std目录）" {
	cd "$PROJECT_ROOT/std"

	source "./console.sh"
	[ "${#__loaded_modules[@]}" -eq 2 ]

	# 使用仅文件名再次加载（应该被阻止）
	source "console.sh"
	[ "${#__loaded_modules[@]}" -eq 2 ]

	[ "$(type -t console.stderr)" = "function" ]
}

@test "console.sh - ../格式化加载（从不同目录）" {
	cd "$PROJECT_ROOT"

	source "std/console.sh"
	[ "${#__loaded_modules[@]}" -eq 2 ]

	# 切换到std目录，使用不同相对路径加载（应该被阻止）
	cd "$PROJECT_ROOT/std"
	source "./console.sh"
	[ "${#__loaded_modules[@]}" -eq 2 ]
}

@test "console.sh - 绝对路径与相对路径混合" {
	# 使用绝对路径加载
	source "$CONSOLE_SH_PATH"
	local count1="${#__loaded_modules[@]}"

	# 使用相对路径再次加载（从std目录，应该被阻止）
	cd "$PROJECT_ROOT/std"
	source "./console.sh"
	local count2="${#__loaded_modules[@]}"

	[ "$count1" -eq 2 ]
	[ "$count2" -eq 2 ]
}

@test "错误处理 - 空字符串参数" {
	run source ""
	[ "$status" -ne 0 ]
	[ -n "$output" ]

	# 验证错误信息
	[[ "$output" == *"没有那个文件或目录"* ]]
}

@test "错误处理 - 不存在的文件" {
	run source "/nonexistent/path/to/file.sh"
	[ "$status" -ne 0 ]
	[ -n "$output" ]

	# 验证错误信息
	[[ "$output" == *"没有那个文件或目录"* ]]
}

@test "import.sh自身 - 多次source不重复初始化（绝对路径）" {
	# setup中已经source过一次，__loaded_modules已被初始化
	[ "${#__loaded_modules[@]}" -eq 1 ]

	# 在__loaded_modules中添加一个测试条目
	__loaded_modules["/test/path"]=1
	[ "${#__loaded_modules[@]}" -eq 2 ]

	# 再次source，应该被第3行阻止，不会重新初始化
	source "$LOAD_SH_PATH"
	# 验证测试条目仍然存在（证明没有重新初始化）
	[ "${#__loaded_modules[@]}" -eq 2 ]
	[ -n "${__loaded_modules[/test/path]+x}" ]
}

@test "import.sh自身 - 多次source不重复初始化（相对路径）" {
	cd "$PROJECT_ROOT/std"

	# setup中已经source过一次，__loaded_modules已被初始化
	[ "${#__loaded_modules[@]}" -eq 1 ]

	# 在__loaded_modules中添加一个测试条目
	__loaded_modules["/test/path2"]=1
	[ "${#__loaded_modules[@]}" -eq 2 ]

	# 再次source，应该被第3行阻止，不会重新初始化
	source "./import.sh"
	# 验证测试条目仍然存在（证明没有重新初始化）
	[ "${#__loaded_modules[@]}" -eq 2 ]
	[ -n "${__loaded_modules[/test/path2]+x}" ]
}

@test "import.sh与console.sh - 不同模块可正常加载" {
	# 加载import.sh
	source "$LOAD_SH_PATH"
	local count1="${#__loaded_modules[@]}"

	# 加载console.sh（不同模块）
	source "$CONSOLE_SH_PATH"
	local count2="${#__loaded_modules[@]}"

	[ "$count1" -eq 1 ]
	[ "$count2" -eq 2 ]
}

@test "console.sh - 不同工作目录下的相对路径" {
	cd "$PROJECT_ROOT"

	# 在项目根目录加载
	source "std/console.sh"
	local count1="${#__loaded_modules[@]}"

	# 在std目录加载（应该被阻止）
	cd "$PROJECT_ROOT/std"
	source "./console.sh"
	local count2="${#__loaded_modules[@]}"

	[ "$count1" -eq 2 ]
	[ "$count2" -eq 2 ]
}

@test "多级相对路径 - ../../格式加载" {
	# 创建测试目录和模块
	export TEST_DEEP_DIR="/tmp/test_load_deep/nested/deep"
	export TEST_MODULE_PATH="$TEST_DEEP_DIR/test_module.sh"
	mkdir -p "$TEST_DEEP_DIR"
	cat > "$TEST_MODULE_PATH" << 'EOF'
#!/usr/bin/env bash
test_module_function() { echo "Test module loaded"; }
EOF

	local test_dir="/tmp/test_load_deep/nested/deep"
	local module_path="$test_dir/test_module.sh"

	# 确保测试目录存在
	[ -d "$test_dir" ]

	# 在嵌套目录中使用多级相对路径加载
	cd "$test_dir"
	source "../../../test_load_deep/nested/deep/test_module.sh"
	[ "${#__loaded_modules[@]}" -eq 2 ]

	# 验证模块已加载（函数可用）
	[ "$(type -t test_module_function)" = "function" ]

	# 在父目录使用不同相对路径加载（应该被阻止）
	cd "/tmp/test_load_deep"
	source "nested/deep/test_module.sh"
	[ "${#__loaded_modules[@]}" -eq 2 ]


	# 清理测试目录
	rm -rf "/tmp/test_load_deep" 2>/dev/null || true
}

@test "import - 从src目录加载相对路径" {
	cd "$PROJECT_ROOT"

	# 使用import加载std/console.sh (相对于lib/)
	import "std/console.sh"
	local count1="${#__loaded_modules[@]}"

	# 验证console函数可用
	[ "$(type -t console.stderr)" = "function" ]
	run console.stderr "test"
	[ "$status" -eq 0 ]
	[ "$output" = "test" ]

	# 再次用相同路径加载,应该被阻止
	import "std/console.sh"
	local count2="${#__loaded_modules[@]}"

	[ "$count1" -eq 2 ]
	[ "$count2" -eq 2 ]
}

@test "import - 绝对路径不受影响" {
	# 使用绝对路径
	import "$CONSOLE_SH_PATH"
	local count1="${#__loaded_modules[@]}"

	[ "$(type -t console.stderr)" = "function" ]

	# 验证已加载
	[ "$count1" -eq 2 ]
}

@test "import - 错误处理" {
	# 不存在的文件
	run import "nonexistent/file.sh"
	[ "$status" -ne 0 ]
}

@test "import - 支持深层路径" {
	cd "$PROJECT_ROOT"

	# 创建深层测试模块
	mkdir -p deep/nested
	cat > deep/nested/module.sh << 'EOF'
#!/usr/bin/env bash
deep_module_func() { echo "deep module"; }
EOF

	# 使用import加载
	import "deep/nested/module.sh"
	local count="${#__loaded_modules[@]}"

	# 验证函数可用
	[ "$(type -t deep_module_func)" = "function" ]
	run deep_module_func
	[ "$status" -eq 0 ]
	[ "$output" = "deep module" ]

	# 验证已加载(包含import.sh + module.sh)
	[ "$count" -eq 2 ]

	# 清理
	rm -rf deep
}
