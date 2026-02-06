#!/usr/bin/env bash

files.file.exists() { [[ -f "$1" ]] }

files.dir.exists() { [[ -d "$1" ]] }

file.write() {
	local _f="$1" _tmp_f
	shift

	_tmp_f="$(mktemp)" || {
		log.error "无法创建临时文件"
		return 1
	}

	printf "%s\n" "$@" >"$_tmp_f" || {
		rm -f "$_tmp_f"
		log.error "写入临时文件失败"
		return 1
	}

	# 移动到目标文件
	mv "$_tmp_f" "$_f" && {
		log.info "配置已保存到: $_f"
		return 0
	} || {
		log.error "保存配置失败: $_f"
		rm -f "$_tmp_f"
		return 1
	}
}