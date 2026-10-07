#!/usr/bin/env bats
#
# 载荷回归：每个模块配一个「只 import 该模块」的最小消费者，记录 build 字节数。
# 载荷只允许下降或持平（棘轮）；增长即失败，需说明理由并刷新基线。
# 刷新：PAYLOAD_UPDATE=1 test/bats/bin/bats test/payload.bats
# 注意：数值依赖 shfmt 版本（无 shfmt 时不压缩，数值会更大）。

load 'test_helper/common-setup'

setup() {
	_common_setup
	TMP="$(mktemp -d)"
	cd "$TMP"
	BASELINE="$PROJECT_ROOT/test/payload/baseline.tsv"
}

teardown() {
	cd "$PROJECT_ROOT"
	rm -rf "$TMP"
}

_payload_size() {
	local mod="$1" src="$TMP/s.sh" out="$TMP/gen"
	printf '#!/usr/bin/env bash\nimport %s\n' "$mod" > "$src"
	# 构建失败必须报出来：否则 wc -c 读到空值/0，棘轮会把没测到的东西当成通过
	"$PROJECT_ROOT/tools/build" -o "$out" "$src" > /dev/null 2>&1 || return 1
	[[ -s $out ]] || return 1
	wc -c < "$out"
}

@test "payload: 各模块载荷不超过基线（棘轮）" {
	local failures=0 mod expected actual
	while IFS=$'\t' read -r mod expected; do
		[[ -z $mod || $mod == '#'* ]] && continue
		actual=$(_payload_size "$mod") || {
			echo "  $mod: 构建失败，无法测量载荷"
			failures=1
			continue
		}
		if ((actual > expected)); then
			echo "  $mod: $actual > baseline $expected"
			failures=1
		fi
	done < "$BASELINE"
	[ "$failures" -eq 0 ]
}

@test "payload: console.layout 不被 core/log 消费者带入（底座隔离）" {
	printf '#!/usr/bin/env bash\nimport core/log\n' > "$TMP/gen.sh"
	"$PROJECT_ROOT/tools/build" -o "$TMP/gen" "$TMP/gen.sh" > /dev/null 2>&1
	run grep -c 'console\.layout\.section' "$TMP/gen"
	[ "$output" = "0" ]
}

@test "payload: 刷新基线（需 PAYLOAD_UPDATE=1）" {
	[[ ${PAYLOAD_UPDATE:-} == "1" ]] || skip "设置 PAYLOAD_UPDATE=1 以刷新基线"
	local mod size out="$TMP/baseline.tsv"
	: > "$out"
	for mod in core/args core/log core/usage core/config core/config.persist core/report \
		std/array std/map std/string std/fs std/path std/system std/console std/console.layout std/console.epipe std/cache \
		std/ansi std/ansi.powerline std/markdown ext/requests ext/requests.sse ext/requests.cache ext/github ext/select ext/llm; do
		# 先在临时文件里攒全，中途失败不会把基线截断
		size=$(_payload_size "$mod") || {
			echo "构建失败，基线未刷新: $mod" >&2
			return 1
		}
		printf '%s\t%s\n' "$mod" "$size" >> "$out"
	done
	mv "$out" "$BASELINE"
}
