#!/usr/bin/env bash

# 在关掉 functrace / errtrace 的情况下执行一段加载代码。
#
# 为什么需要：bats 会装 DEBUG trap 并开着 functrace（测试进程 `$-` 里看得到 T），trap 因此会
# 传播进被 source 的每一个文件 —— 一个包加载十几个模块时，**每一条命令**都要过一遍 trap。
# 实测：`source binup.sh` 在 -T 下 2.9s，关掉后 6ms；单个模块也使 import 从 ~0 变成 325ms。
# 载入完成后按原样恢复，测试体的断言与 bats 的错误跟踪不受影响。
#
# 上游情况（查证于 bats v1.14.0）：bats 在 libexec/bats-core/bats-exec-test:2 主动
# `set -eET`（2018 年 commit 199ec98，为重构 run() 的栈追踪需要），不是 bug。它唯一的排除
# 机制 BATS_DEBUG_EXCLUDE_PATHS 只让 bats_debug_trap 早退，省不掉 bash「派发 DEBUG trap 本身」
# 的开销——实测同一份加载，开不开它都是 ~3.1s；而 set +T 之后是 0.24s。
# （顺带：该变量在 1.14 里用 `IFS=':' read -r exclude_paths` 解析，多路径会被整体当成一项，
# 等于不生效。）纯 bash 侧的量级：2000 次函数调用，无 trap 33ms、有 trap+-T 308ms、
# 有 trap 无 -T 207ms —— 所以省掉派发开销是唯一有效手段。
#
# 用法：_fast_load source "$PROJECT_ROOT/<包>.sh"
#       _fast_load import size common provider
#
# 注意：这里刻意写成普通的 "$@" 而不是 "$@" || rc=$?。因为 bash 规定「处于 || 列表中的
# 函数/被 source 的文件会豁免 errexit」——那样写会让加载期的失败被静默吞掉，而且被加载
# 文件会以最后一条命令的退出码收尾（常见是 0），连 rc 都骗到。实测：文件里一句 false
# 之后，|| 版继续往下跑且 rc=0；普通版立即按 fail fast 中止。
# 代价：加载失败当场中止时不再恢复 -T/-E，但整条链已经终止，不影响调用方。
_fast_load() {
	local flags="$-"
	set +T +E
	"$@"
	local rc=$?
	[[ $flags == *T* ]] && set -T
	[[ $flags == *E* ]] && set -E
	return $rc
}

_common_setup() {
	# 这三步都是 source（bats-support / bats-assert / import.sh），在 bats 的 functrace 下
	# 每一条命令都要过 DEBUG trap：实测 140ms/条 → 85ms/条。包自己的加载也照此处理。
	_fast_load load 'test_helper/bats-support/load'
	_fast_load load 'test_helper/bats-assert/load'
	# get the containing directory of this file
	# use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
	# as those will point to the bats executable's location or the preprocessed file respectively
	PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." > /dev/null 2>&1 && pwd)"
	# make executables in lib/ visible to PATH
	PATH="$PROJECT_ROOT/lib:$PATH"
	_fast_load source "$PROJECT_ROOT/lib/std/import.sh"
}
