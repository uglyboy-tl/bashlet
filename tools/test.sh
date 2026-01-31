#!/usr/bin/env bash

# 测试运行器 - 运行bashlet项目的Bats测试

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BATS_DIR="$PROJECT_ROOT/test/bats"
BATS_EXEC="$BATS_DIR/bin/bats"

source "$PROJECT_ROOT/src/std/import.sh"

import core/args
import std/files


# 检查Bats是否可用
check_bats() {
	files.file.exists "$BATS_EXEC" && return 0
	log.error "Bats测试框架未找到: $BATS_EXEC"
	log.info "请确保Bats已正确安装在 test/bats/ 目录"
	exit 1
}

# 构建Bats命令参数
build_bats_args() {
	local -a args=()

	# 设置默认参数
	args+=("--jobs" "$JOBS")

	# 格式选项
	if [[ "$TAP_FORMAT" == "true" ]]; then
			args+=("--tap")
	elif [[ "$VERBOSE" == "true" ]]; then
			args+=("-v")
	fi

	# 过滤选项
	if [[ -n "$FILTER_PATTERN" ]]; then
			args+=("--filter" "$FILTER_PATTERN")
	fi

	# 计数选项
	if [[ "$COUNT_ONLY" == "true" ]]; then
			args+=("--count")
	fi

	echo "${args[@]}"
}

# 运行测试
run_tests() {
	local test_path="$1"

	log.info "开始运行测试..."

	# 切换到test目录并添加bats到PATH
	cd "$PROJECT_ROOT/test"
	export PATH="$BATS_DIR/bin:$PATH"

	# 构建Bats命令
	local bats_args
	bats_args=$(build_bats_args)

	# 运行测试
	log.info "执行: bats $bats_args $test_path"

	if eval "bats $bats_args $test_path"; then
		local exit_code=$?
		if [[ $exit_code -eq 0 ]]; then
			log.success "执行成功!"
			return 0
		else
			log.error "测试失败，退出码: $exit_code"
			return $exit_code
		fi
	else
		local exit_code=$?
		log.error "测试执行失败，退出码: $exit_code"
		return $exit_code
	fi
}

# 获取所有测试文件列表
list_test_files() {
	cd "$PROJECT_ROOT/test"
	find . -name "*.bats" -not -path "./bats/*" -not -path "./test_bats/*"  -not -path "./test_helper/*" | sort
}

# 显示测试统计
show_test_stats() {
	local test_files
	test_files=$(list_test_files)

	if [[ -z "$test_files" ]]; then
		log.warn "没有找到测试文件"
		return
	fi

	local count
	count=$(echo "$test_files" | wc -l)

	log.info "找到 $count 个测试文件:"
	echo "$test_files" | while read -r file; do
		echo "  - $file"
	done
}

# 主函数
main() {
	help.name.set "测试运行器"
	help.seccription.set "运行 bashlet 项目的 Bats 测试"

	args.new_options "main"
	args.add_options "filter" "f" "只运行匹配模式的测试" "STRING"
	args.add_options "jobs" "j" "并行运行测试 (默认: 1)" "NUM"
	args.add_options "verbose" "v" "详细输出"
	args.add_options "tap" "t" "使用TAP格式输出"
	args.add_options "count" "c" "只计算测试数量"
	args.add_options "arg" "测试文件/模式" "可选：指定测试文件或目录(默认: 运行所有测试)"
	args.add_options "example" "" "# 运行所有测试"
	args.add_options "example" "test.bats" "# 运行单个测试文件"
	args.add_options "example" "-f \"log\"" "# 运行包含"log"的测试"
	args.add_options "example" "-j 4" "# 并行运行4个测试"
	args.add_options "example" "-v test/log.bats" "# 详细运行特定测试"
	args.add_options "notice" '测试应该在项目的 test/ 目录下运行'
	args.add_options "notice" '测试文件必须使用 .bats 扩展名'

	args.parse "$@"
	args.verify || { args.show_help; exit 1; }
	args.has "-h" "--help" && args.show_help && exit 0
	#args.has "-c" "--count" && show_test_stats && exit 0
	args.has "-c" "--count" && COUNT_ONLY="true" || COUNT_ONLY="false"
	args.has "-v" "--verbose" && VERBOSE="true" || VERBOSE="false"
	args.has "-t" "--tap" && TAP_FORMAT="true" || TAP_FORMAT="false"
	FILTER_PATTERN=$(args.get "-f" "--filter" 2>/dev/null) || FILTER_PATTERN=""
	JOBS=$(args.get "-j" "--jobs" 2>/dev/null) || JOBS="1"
	declare -n args=$(args.args)
	[[ ${#args[@]} -ne 0 ]] && TEST_TARGET="${args[@]}" ||TEST_TARGET="."

	# 检查Bats
	check_bats

	# 运行测试
	run_tests "$TEST_TARGET"
}

# 入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
