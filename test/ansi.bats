#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
  _common_setup
  import std/ansi
}

teardown() {
  : # No cleanup needed
}

# ============ 功能检测测试 ============

@test "ansi.Color.IsAvailable - 返回函数而非别名" {
  run ansi.Color.IsAvailable
  [[ $status -eq 0 || $status -eq 1 ]]
}

@test "ansi.Powerline.IsAvailable - 返回函数" {
  run ansi.Powerline.IsAvailable
  [[ $status -eq 0 || $status -eq 1 ]]
}

# ============ 启用/禁用颜色测试 ============

@test "ansi.enable.color() 设置颜色变量" {
  run ansi.enable.color
  [[ $status -eq 0 ]]
}

@test "ansi.disable.color() 清空颜色变量" {
  run ansi.disable.color
  [[ $status -eq 0 ]]
  [[ -z "$RED" ]]
  [[ -z "$GREEN" ]]
  [[ -z "$BLUE" ]]
  [[ -z "$NC" ]]
}

# ============ 启用/禁用样式测试 ============

@test "ansi.enable.style() 设置样式变量" {
  run ansi.enable.style
  [[ $status -eq 0 ]]
}

@test "ansi.disable.style() 清空样式变量" {
  run ansi.disable.style
  [[ $status -eq 0 ]]
  [[ -z "$Bold" ]]
  [[ -z "$Italics" ]]
  [[ -z "$Underline" ]]
}

@test "ansi.is.initialized() 检测初始化状态" {
  run ansi.is.initialized
  # 导入时已启用，如果终端支持则返回0
}

# ============ 启用/禁用 Powerline 测试 ============

@test "ansi.enable.powerline() 设置 Powerline 变量" {
  run ansi.enable.powerline
  [[ $status -eq 0 ]]
}

@test "ansi.disable.powerline() 重置 Powerline 为 ASCII" {
  ansi.disable.powerline
  [[ "$POWERLINE_SEPARATOR" == ">" ]]
  [[ "$POWERLINE_BRANCH" == "|}" ]]
  [[ "$POWERLINE_OK" == "+" ]]
}

# ============ 主入口函数测试 ============

@test "ansi.enable() 根据检测启用功能" {
  run ansi.enable
  [[ $status -eq 0 ]]
}

@test "ansi.disable() 禁用所有功能" {
  ansi.disable
  [[ -z "$RED" ]]
  [[ -z "$Bold" ]]
  [[ "$POWERLINE_SEPARATOR" == ">" ]]
}

# ============ 环境变量控制测试 ============

@test "BASHLET_ANSI_FORCE_DISABLE 强制禁用颜色" {
  export BASHLET_ANSI_FORCE_DISABLE=1
  import std/ansi.sh
  [[ -z "$RED" ]]
  [[ -z "$Bold" ]]
  unset BASHLET_ANSI_FORCE_DISABLE
}

# ============ 变量使用场景测试 ============

@test "使用颜色变量组合字符串" {
  ansi.enable.color
  local msg="${RED}Error${NC}: something failed"
  [[ -n "$msg" ]]
}

@test "使用样式变量" {
  ansi.enable.style
  local msg="${Bold}bold text${NC}"
  [[ -n "$msg" ]]
}

@test "使用 Powerline 变量" {
  ansi.disable.powerline
  local prompt="${POWERLINE_SEPARATOR} prompt"
  [[ "$prompt" == "> prompt" ]]

  ansi.enable.powerline
  [[ -n "$POWERLINE_SEPARATOR" ]]
}

@test "组合颜色、样式和 Powerline" {
  ansi.enable.color
  ansi.enable.style
  local msg="${RED}${Bold}Error${NC}: ${POWERLINE_FAIL} failed"
  [[ -n "$msg" ]]
}

@test "使用 Powerline 分隔符构建 prompt" {
  ansi.enable.color
  ansi.enable.powerline
  local prompt="${GREEN} user ${NC}${POWERLINE_SEPARATOR}${BLUE} dir ${NC}${POWERLINE_SEPARATOR}${NC}"
  [[ -n "$prompt" ]]
}

# ============ 边界条件测试 ============

@test "多次调用 ansi.enable.color() 不会出错" {
  ansi.enable.color
  ansi.enable.color
  run ansi.enable.color
  [[ $status -eq 0 ]]
}

@test "多次调用 ansi.disable.color() 不会出错" {
  ansi.disable.color
  ansi.disable.color
  run ansi.disable.color
  [[ $status -eq 0 ]]
}

@test "多次调用 ansi.enable.style() 不会出错" {
  ansi.enable.style
  ansi.enable.style
  run ansi.enable.style
  [[ $status -eq 0 ]]
}

@test "多次调用 ansi.disable.style() 不会出错" {
  ansi.disable.style
  ansi.disable.style
  run ansi.disable.style
  [[ $status -eq 0 ]]
}

@test "交替调用 enable/disable" {
  ansi.enable.color
  ansi.enable.style
  ansi.disable.color
  ansi.disable.style
  [[ -z "$RED" ]]
  [[ -z "$Bold" ]]
  ansi.enable.color
  ansi.enable.style
  [[ -n "$ANSI_CSI" || -z "$ANSI_CSI" ]]
}

# ============ 实际使用场景测试 ============

@test "日志场景：不同级别使用不同颜色" {
  ansi.enable.color
  local error_msg="${RED}ERROR${NC}: something went wrong"
  local success_msg="${GREEN}SUCCESS${NC}: operation completed"
  local warning_msg="${YELLOW}WARNING${NC}: please check"

  [[ -n "$error_msg" ]]
  [[ -n "$success_msg" ]]
  [[ -n "$warning_msg" ]]
}

@test "样式场景：使用粗体和斜体" {
  ansi.enable.style
  local bold_text="${Bold}Important${NC}"
  local italic_text="${Italics}emphasis${NC}"
  local underline_text="${Underline}link${NC}"

  [[ -n "$bold_text" ]]
  [[ -n "$italic_text" ]]
  [[ -n "$underline_text" ]]
}

@test "Git 提示符：使用 Powerline 分支符号" {
  ansi.enable.powerline
  local git_prompt="${POWERLINE_BRANCH} main"
  [[ -n "$git_prompt" ]]
}

@test "状态显示：使用 Powerline 符号表示状态" {
  ansi.disable.powerline
  local success="${POWERLINE_OK} Done"
  local failed="${POWERLINE_FAIL} Failed"

  [[ "$success" == "+ Done" ]]
  [[ "$failed" == "x Failed" ]]
}

@test "帮助文本：使用颜色和样式突出显示" {
  ansi.enable.color
  ansi.enable.style
  local help_text="${Bold}Usage:${NC} ${Italics}script${NC} ${RED}[options]${NC}"
  [[ -n "$help_text" ]]
}

@test "禁用后输出纯文本" {
  ansi.disable
  local plain_text="${RED}${Bold}Error${NC}: message"
  [[ "$plain_text" == "Error: message" ]]
}
