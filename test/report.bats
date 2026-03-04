#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
  _common_setup
  import core/report.sh
  _REPORT_DIR="/tmp"
  _REPORT_SECTION_NUM=1
  _REPORT_CONTENT=()
}

teardown() {
  unset _REPORT_DIR _REPORT_SECTION_NUM _REPORT_CONTENT
}

@test "report.dir.set - 设置报告目录" {
  report.dir.set "/custom/dir"
  [ "$_REPORT_DIR" = "/custom/dir" ]
}

@test "report.reset - 重置报告内容" {
  _REPORT_CONTENT=("test" "content")
  report.reset
  [ "${#_REPORT_CONTENT[@]}" -eq 0 ]
}

@test "report.init - 初始化报告" {
  report.init "Test Report"
  # 应该包含 front_matter, 空行, h1 标题, 空行
  [[ "${_REPORT_CONTENT[0]}" == "---"* ]]
  [[ "${_REPORT_CONTENT[2]}" == "# Test Report" ]]
  [ "${#_REPORT_CONTENT[@]}" -eq 4 ]
}

@test "report.section - 添加章节" {
  report.section "Section Title"
  [[ "${_REPORT_CONTENT[0]}" == "## 1. Section Title" ]]
  [ "${_REPORT_CONTENT[1]}" = "" ]
  [ "$_REPORT_SECTION_NUM" -eq 2 ]
}

@test "report.subsection - 添加子章节" {
  report.subsection "Subsection Title"
  [ "${_REPORT_CONTENT[0]}" = "### Subsection Title" ]
}

@test "report.code - 添加代码块" {
  # 使用简单的命令进行测试
  report.code "echo hello"
  [[ "${_REPORT_CONTENT[0]}" == *"bash"* ]]
  [[ "${_REPORT_CONTENT[0]}" == *"echo hello"* ]]
  [[ "${_REPORT_CONTENT[0]}" == *"\`\`\`"* ]]
  [ "${_REPORT_CONTENT[1]}" = "hello" ]
  [ "${_REPORT_CONTENT[2]}" = "" ]
}

@test "report.table.begin - 开始表格" {
  report.table.begin "Col1" "Col2"
  [[ "${_REPORT_CONTENT[0]}" == *"Col1"* ]]
  [[ "${_REPORT_CONTENT[0]}" == *"Col2"* ]]
  [[ "${_REPORT_CONTENT[0]}" == *"---"* ]]
}

@test "report.table.add - 添加表格行" {
  report.table.add "Value1" "Value2"
  [ "${_REPORT_CONTENT[0]}" = "| Value1 | Value2 |" ]
}

@test "report.table.end - 结束表格" {
  report.table.end
  [ "${_REPORT_CONTENT[0]}" = "" ]
}

@test "report.export - 导出报告" {
  report.subsection "Test content"
  local file
  file=$(report.export "/tmp/test_report_$(date +%Y%m%d_%H%M%S).md")
  [ -f "$file" ]
  [ "$(cat "$file")" = "### Test content" ]
  rm -f "$file"
}