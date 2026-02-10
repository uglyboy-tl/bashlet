#!/usr/bin/env bash

import ext/requests
import core/log

declare -g _LLM_API_KEY=""
declare -g _LLM_MODEL="deepseek-chat"
declare -g _LLM_BASE_URL="https://api.deepseek.com/v1"

llm.init() {
	requests.init
	log.debug "llm module initialized: model=$_LLM_MODEL"
}

llm.api_key() { _LLM_API_KEY="$1"; }
llm.model() { _LLM_MODEL="$1"; }
llm.base_url() { _LLM_BASE_URL="$1"; }

llm.chat() {
	local messages="$1"
	local callback="${2:-llm._default_callback}"

	requests.jq.check

	[[ -n "$_LLM_API_KEY" ]] || { log.error "API key not set. Call llm.api_key first." && return 1; }

	local body
	body=$(jq -n \
		--arg model "$_LLM_MODEL" \
		--argjson messages "$messages" \
		'{
			model: $model,
			messages: $messages,
			stream: true
		}')

	requests.auth_bearer "$_LLM_API_KEY"

	requests.sse "$callback" "POST" "${_LLM_BASE_URL}/chat/completions" "$body"
}

llm._sse_callback() {
	[[ "$1" == "[DONE]" ]] && return 0

	local content
	content=$(jq -r '.choices[0].delta.content // empty' <<<"$1")
	[[ -n "$content" ]] && printf "%s" "$content"
}

llm.chat.stream() {
	local text="$1"
	[[ -n "$text" ]] || { log.error "Missing prompt text" && return 1; }
	[[ -n "${_LLM_API_KEY:-}" ]] || { log.error "API key not set" && return 1; }

	local messages
	messages=$(jq -n --arg text "$text" '[{"role": "user", "content": $text}]')

	llm.chat "$messages" "llm._sse_callback"
	echo
}
