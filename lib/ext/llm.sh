#!/usr/bin/env bash

import ext/requests
import core/log

: ${OPENAI_API_KEY:=""}
: ${OPENAI_BASE_URL:="https://api.deepseek.com/v1"}
: ${_LLM_MODEL:="deepseek-chat"}

llm.init() {
	requests.init
	log.debug "llm module initialized: model=$_LLM_MODEL"
}

llm.api_key() { OPENAI_API_KEY="$1"; }
llm.base_url() { OPENAI_BASE_URL="$1"; }
llm.model() { _LLM_MODEL="$1"; }

llm.chat() {
	local model="$1"
	local messages="$2"
	local callback="${3:-llm._default_callback}"

	requests.jq.check
	[[ -n "$OPENAI_API_KEY" ]] || { log.error "API key not set. Call llm.api_key first." && return 1; }

	local body
	body=$(jq -n \
		--arg model "$_LLM_MODEL" \
		--argjson messages "$messages" \
		'{
			model: $model,
			messages: $messages,
			stream: true
		}')

	requests.auth_bearer "$OPENAI_API_KEY"

	requests.sse "$callback" "POST" "${OPENAI_BASE_URL}/chat/completions" "$body"
}

llm._sse_callback() {
	[[ "$1" == "[DONE]" ]] && return 0

	local content
	content=$(jq -r '.choices[0].delta.content // empty' <<<"$1")
	[[ -n "$content" ]] && printf "%s" "$content" || true
}

llm.chat.stream() {
	local text="$1"
	[[ -n "$text" ]] || { log.error "Missing prompt text" && return 1; }

	local messages
	messages=$(jq -n --arg text "$text" '[{"role": "user", "content": $text}]')

	llm.chat "$_LLM_MODEL" "$messages" "llm._sse_callback"
	echo
}
