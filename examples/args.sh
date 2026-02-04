#!/usr/bin/env bash
#
# 示例：使用 args 模块构建带子命令的 CLI 工具
#
# 用法:
#   ./args.sh [global_options] <subcommand> [subcommand_options]
#
# 全局选项:
#   -v, --verbose    全局详细模式
#   -h, --help       显示帮助
#   -V, --version    显示版本
#
# 子命令:
#   build    构建项目
#   test     运行测试
#   deploy   部署应用
#

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PROJECT_ROOT/lib/std/import.sh"

import core/args

VERSION="1.0.0"

# ============================================================
# 子命令: build - 构建项目
# ============================================================
cmd_build() {

	args.init
	args.add_options "clean" "c" "构建前清理"
	args.add_options "target" "t" "构建目标" "TARGET"
	args.add_options "verbose" "v" "详细输出"
	args.add_options "NOTICE" "默认构建目标为 release"
	args.add_options "EXAMPLE" "" "构建项目"
	args.add_options "EXAMPLE" "-c" "清理后构建"
	args.add_options "EXAMPLE" "-t debug" "构建调试版本"

	args.process "$@"

	log.info "开始构建项目..."

	args.has "-c" "--clean" && log.info "  $POWERLINE_ARROW_RIGHT 清理旧构建文件"

	target=$(args.get "-t" "--target") || target="release"
	log.info "  $POWERLINE_ARROW_RIGHT 构建目标: $target"

	args.has "-v" "--verbose" && log.info "  $POWERLINE_ARROW_RIGHT 启用详细输出"

	log.success "构建完成！"
}

# ============================================================
# 子命令: test - 运行测试
# ============================================================
cmd_test() {
	args.init "运行项目测试"
	args.add_options "watch" "w" "监视模式"
	args.add_options "filter" "f" "测试过滤器" "PATTERN"
	args.add_options "coverage" "" "生成覆盖率报告"
	args.add_options "NOTICE" "使用 -f 过滤特定的测试"
	args.add_options "EXAMPLE" "" "运行所有测试"
	args.add_options "EXAMPLE" "-w" "监视模式运行测试"
	args.add_options "EXAMPLE" "-f unit" "只运行单元测试"

	args.process "$@"

	log.info "运行测试..."

	filter=$(args.get "-f" "--filter") && log.info "  $POWERLINE_ARROW_RIGHT 过滤模式: $filter"
	args.has "-w" "--watch" && log.info "  $POWERLINE_ARROW_RIGHT 监视模式已启用"
	args.has "--coverage" && log.info "  $POWERLINE_ARROW_RIGHT 生成覆盖率报告"

	log.success "测试通过！"
}

# ============================================================
# 子命令: deploy - 部署应用
# ============================================================
cmd_deploy() {
	args.init "部署应用到目标环境"
	args.add_options "env" "e" "部署环境" "ENV"
	args.add_options "dry-run" "n" "仅模拟，不实际部署"
	args.add_options "force" "" "强制部署"
	args.add_options "NOTICE" "-e 选项是必需的"
	args.add_options "EXAMPLE" "-e production" "部署到生产环境"
	args.add_options "EXAMPLE" "-e staging -n" "模拟部署到测试环境"

	args.process "$@"

	env=$(args.get "-e" "--env") || { log.error "请指定部署环境 (-e <env>)"; return 1; }

	log.info "开始部署..."
	log.info "  $POWERLINE_ARROW_RIGHT 目标环境: $env"

	args.has "-n" "--dry-run" && log.warn "  $POWERLINE_ARROW_RIGHT [模拟模式] 不会实际部署"
	args.has "--force" && log.warn "  $POWERLINE_ARROW_RIGHT 强制部署模式"

	log.success "部署成功！"
}

# ============================================================
# 主函数
# ============================================================
main() {
	# 设置脚本信息
	args.name "项目工具"
	args.init "项目管理 CLI 工具"

	# 不是子命令，设置全局选项并解析
	args.add_options "verbose" "v" "启用全局详细模式"
	args.add_options "help" "h" "显示帮助信息"
	args.add_options "version" "V" "显示版本信息"
	args.add_options "NOTICE" "可用子命令: build, test, deploy"
	args.add_options "EXAMPLE" "" "显示版本信息"
	args.add_options "EXAMPLE" "build -c -v" "清理并构建项目"
	args.add_options "EXAMPLE" "test -w" "以监视模式运行测试"
	args.add_options "EXAMPLE" "deploy -e production" "部署到生产环境"

	# 注册子命令
	args.add_subcommand "build" "构建项目" "cmd_build"
	args.add_subcommand "test" "运行测试" "cmd_test"
	args.add_subcommand "deploy" "部署应用" "cmd_deploy"


	args.process "$@"

	# 处理全局选项
	args.has "-V" "--version" && { usage.version; exit 0; }
	args.has "-v" "--verbose" && log.info "全局详细模式已启用"

	# 无参数或未知情况，显示帮助
	args.show_help
	exit 1
}

main "$@"
