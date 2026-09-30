#!/usr/bin/env bash

import std/system
import std/string

# 选择器：统一 fzf(终端) / rofi(图形) / native(数字回退) 三种后端，
# 调用方只关心"选什么"，不关心用哪个界面（借鉴 dotfiles/settings 的 select_ui）。
#
# 后端选择：环境变量 SELECT_UI=gui|tui|native 优先；未设时自动探测
#   fzf 存在 → tui；否则 rofi 且有图形会话 → gui；否则 native。
# 注意：native 为强制；gui/tui 若对应后端不可用，会按 tui → gui → native 静默回退。
#
# 约定：
#   - 候选数据换行分隔，经 -d 传入；缺省时从 stdin 读取。
#   - 取消/无候选返回 1 且不输出，调用方据此判断（不要再包 || true）。
#   - -s 传入"当前选中项"，后端据此定位高亮（记住内容、由后端换算行号）。
#   - -i 传入预览命令模板（含 {}，替换为当前行）：fzf 用作 --preview，
#     rofi 取其输出的图片路径作为图标。
#   - -t/--theme 仅 rofi 后端生效；fzf 主题走 FZF_DEFAULT_OPTS 或自身配置。
#
# 用法：
#   select.one  -p 主题 -d "$(list)" -s "$(current)"
#   select.many -p 选择 -d "$(list)"

: "${SELECT_UI:=}"

# 具体后端：偏好(SELECT_UI)可用则用，否则 tui → gui → native 逐级回退
select.ui() {
	case "${SELECT_UI:-tui}" in
		native) echo native ;;
		gui) select.gui.supported && echo gui || { system.command.exist fzf && echo tui || echo native; } ;;
		*) system.command.exist fzf && echo tui || { select.gui.supported && echo gui || echo native; } ;;
	esac
}

# rofi 可用且有图形会话（DISPLAY 或 WAYLAND_DISPLAY）
select.gui.supported() {
	system.command.exist rofi && system.gui_supported
}

# 当前选中项在数据中的 0-based 行号；未指定或未命中返回 -1
select._row_of() {
	local needle="$1" data="$2" i=0 line
	[[ -n $needle ]] || {
		printf '%s\n' -1
		return 0
	}
	while IFS= read -r line; do
		[[ $line == "$needle" ]] && {
			printf '%s\n' "$i"
			return 0
		}
		i=$((i + 1))
	done <<< "$data"
	printf '%s\n' -1
}

# 解析 -d/-p/-s 等常规选项；数据缺省时读 stdin。结果经 _SELECT_DATA/_SELECT_PROMPT 等返回。
select._read_stdin() { [[ -t 0 ]] || cat; }

select.one() {
	local prompt="选择" data="" selected="" header="" height="40%" image="" preview="right:60%" theme=""
	while (($#)); do
		case "$1" in
			-p | --prompt) prompt="${2:-}"; shift 2 ;;
			-d | --data) data="${2:-}"; shift 2 ;;
			-s | --selected) selected="${2:-}"; shift 2 ;;
			-h | --header) header="${2:-}"; shift 2 ;;
			-H | --height) height="${2:-40%}"; shift 2 ;;
			-i | --image-cmd) image="${2:-}"; shift 2 ;;
			-W | --preview-window) preview="${2:-right:60%}"; shift 2 ;;
			-t | --theme) theme="${2:-}"; shift 2 ;;
			*) shift ;;
		esac
	done
	[[ -n $data ]] || data="$(select._read_stdin)"
	[[ -n $data ]] || return 1
	case "$(select.ui)" in
		gui) select._rofi "$prompt" "$data" "$selected" "$image" "$theme" "" ;;
		tui) select._fzf "$prompt" "$data" "$selected" "$header" "$height" "$image" "$preview" "" ;;
		*) select._native "$prompt" "$data" "$selected" "" ;;
	esac
}

select.many() {
	local prompt="选择" data="" selected="" header="" height="40%"
	while (($#)); do
		case "$1" in
			-p | --prompt) prompt="${2:-}"; shift 2 ;;
			-d | --data) data="${2:-}"; shift 2 ;;
			-s | --selected) selected="${2:-}"; shift 2 ;;
			-h | --header) header="${2:-}"; shift 2 ;;
			-H | --height) height="${2:-40%}"; shift 2 ;;
			*) shift ;;
		esac
	done
	[[ -n $data ]] || data="$(select._read_stdin)"
	[[ -n $data ]] || return 1
	case "$(select.ui)" in
		gui) select._rofi "$prompt" "$data" "$selected" "" "" "multi" ;;
		tui) select._fzf "$prompt" "$data" "$selected" "$header" "$height" "" "" "multi" ;;
		*) select._native "$prompt" "$data" "$selected" "multi" ;;
	esac
}

# fzf 后端: <prompt> <data> <selected> <header> <height> <image-cmd> <preview-window> <multi>
select._fzf() {
	local prompt="$1" data="$2" selected="${3:-}" header="${4:-}" height="${5:-40%}"
	local image="${6:-}" preview="${7:-right:60%}" multi="${8:-}"
	local -a args=(--prompt "$prompt" --height "$height" --border --bind 'left:abort,right:accept')
	[[ -n $header ]] && args+=(--header "$header")
	[[ -n $image ]] && args+=(--preview "$image" --preview-window "$preview")
	[[ -n $multi ]] && args+=(-m --bind 'space:toggle' --bind 'ctrl-a:select-all')
	local row
	row="$(select._row_of "$selected" "$data")"
	((row >= 0)) && args+=(--bind "load:pos:$((row + 1))")
	local result
	result="$(printf '%s\n' "$data" | fzf "${args[@]}" 2> /dev/null)" || return 1
	[[ -n $result ]] && printf '%s\n' "$result" || return 1
}

# rofi 后端: <prompt> <data> <selected> <image-cmd> <theme> <multi>
select._rofi() {
	local prompt="$1" data="$2" selected="${3:-}" image="${4:-}" theme="${5:-}" multi="${6:-}"
	# Left/Right 让位给"取消/接受"（rofi 默认把它们绑给移动光标）
	local -a args=(-dmenu -p "$prompt"
		-kb-move-char-back Control+b -kb-move-char-forward Control+f
		-kb-accept-entry 'Control+j,Control+m,Return,KP_Enter,Right'
		-kb-cancel 'Escape,Control+g,Control+bracketleft,Left')
	[[ -n $theme ]] && args+=(-theme "$theme")
	[[ -n $multi ]] && args+=(-multi-select)
	local row
	row="$(select._row_of "$selected" "$data")"
	((row >= 0)) && args+=(-selected-row "$row")

	local result
	if [[ -n $image ]]; then
		# 每行附加 \0icon\x1f<路径>（rofi 解析，不进入返回值）；逐项解析预览图标。
		# {} 占位符换成 $1，候选行作为位置参数传入，避免 eval 注入。
		local icon_cmd="${image//\{\}/__SELECT_ARG__}"
		icon_cmd="${icon_cmd//__SELECT_ARG__/\$1}"
		result="$({
			local line icon
			while IFS= read -r line; do
				icon="$(bash -c "$icon_cmd" _ "$line" 2> /dev/null || true)"
				if [[ -n $icon && -f $icon ]]; then
					printf '%s\0icon\x1f%s\n' "$line" "$icon"
				else
					printf '%s\n' "$line"
				fi
			done <<< "$data"
		} | rofi "${args[@]}")" || return 1
	else
		result="$(printf '%s\n' "$data" | rofi "${args[@]}")" || return 1
	fi
	[[ -n $result ]] && printf '%s\n' "$result" || return 1
}

# 数字回退后端: <prompt> <data> <selected> <multi>（提示走 stderr，结果走 stdout）
select._native() {
	local prompt="$1" data="$2" selected="${3:-}" multi="${4:-}"
	local -a opts=()
	mapfile -t opts <<< "$data"
	local i=0 opt
	printf '%s\n' "$prompt" >&2
	for opt in "${opts[@]}"; do
		printf '  [%d] %s\n' "$i" "$opt" >&2
		i=$((i + 1))
	done
	local answer
	if [[ -n $multi ]]; then
		printf 'Enter numbers (space-separated, 0-%d): ' "$((i - 1))" >&2
		read -r answer || return 1
		local -a picked=()
		local n
		for n in $answer; do
			string.int.check "$n" && ((n >= 0 && n < i)) && picked+=("${opts[$n]}")
		done
		((${#picked[@]})) || return 1
		printf '%s\n' "${picked[@]}"
	else
		printf 'Enter number (0-%d): ' "$((i - 1))" >&2
		read -r answer || return 1
		string.int.check "$answer" && ((answer >= 0 && answer < i)) && printf '%s\n' "${opts[$answer]}" || return 1
	fi
}

# ---- 旧接口（deprecated）----
# 兼容 select.single <prompt> <opt...> / select.multi <prompt> <opt...>。
# select.multi 保持旧的"空格连接单行"输出。新代码请用 select.one/select.many。
select.single() {
	local prompt="$1"
	shift
	(($#)) || return 1
	select.one -p "$prompt" -d "$(printf '%s\n' "$@")"
}

select.multi() {
	local prompt="$1" out
	shift
	(($#)) || return 1
	out="$(select.many -p "$prompt" -d "$(printf '%s\n' "$@")")" || return 1
	printf '%s\n' "${out//$'\n'/ }"
}
