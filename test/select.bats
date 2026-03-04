#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
  _common_setup
  import ext/select
}

# select.single 空参数测试
@test "select.single - 空选项应该返回错误" {
  ! select.single "prompt"
}

# select.multi 空参数测试
@test "select.multi - 空选项应该返回错误" {
  ! select.multi "prompt"
}

# select._native_single 测试
@test "select._native_single - 有效输入返回正确选项" {
  # 使用 echo 和管道模拟用户输入
  result=$(echo "1" | select._native_single "Choose:" "opt0" "opt1" "opt2" 2> /dev/null)
  [ "$result" = "opt1" ]
}

@test "select._native_single - 输入 0 返回第一个选项" {
  result=$(echo "0" | select._native_single "Choose:" "opt0" "opt1" "opt2" 2> /dev/null)
  [ "$result" = "opt0" ]
}

@test "select._native_single - 输入最后一个索引返回最后一个选项" {
  result=$(echo "2" | select._native_single "Choose:" "opt0" "opt1" "opt2" 2> /dev/null)
  [ "$result" = "opt2" ]
}

@test "select._native_single - 无效输入返回错误" {
  # 输入超出范围的数字
  ! echo "99" | select._native_single "Choose:" "opt0" "opt1" 2> /dev/null
}

@test "select._native_single - 非数字输入返回错误" {
  ! echo "abc" | select._native_single "Choose:" "opt0" "opt1" 2> /dev/null
}

@test "select._native_single - 负数输入返回错误" {
  ! echo "-1" | select._native_single "Choose:" "opt0" "opt1" 2> /dev/null
}

# select._native_multi 测试
@test "select._native_multi - 单选返回正确选项" {
  result=$(echo "1" | select._native_multi "Choose:" "opt0" "opt1" "opt2" 2> /dev/null)
  [ "$result" = "opt1" ]
}

@test "select._native_multi - 多选返回多个选项" {
  result=$(echo "0 2" | select._native_multi "Choose:" "opt0" "opt1" "opt2" 2> /dev/null)
  [ "$result" = "opt0 opt2" ]
}

@test "select._native_multi - 选择所有选项" {
  result=$(echo "0 1 2" | select._native_multi "Choose:" "opt0" "opt1" "opt2" 2> /dev/null)
  [ "$result" = "opt0 opt1 opt2" ]
}

@test "select._native_multi - 无效输入返回错误" {
  ! echo "99" | select._native_multi "Choose:" "opt0" "opt1" 2> /dev/null
}

@test "select._native_multi - 空输入返回错误" {
  ! echo "" | select._native_multi "Choose:" "opt0" "opt1" 2> /dev/null
}

@test "select._native_multi - 混合有效和无效输入只返回有效选项" {
  result=$(echo "0 99 1" | select._native_multi "Choose:" "opt0" "opt1" "opt2" 2> /dev/null)
  [ "$result" = "opt0 opt1" ]
}

# 边界条件测试
@test "select._native_single - 单选项数组" {
  result=$(echo "0" | select._native_single "Choose:" "only" 2> /dev/null)
  [ "$result" = "only" ]
}

@test "select._native_single - 单选项数组越界" {
  ! echo "1" | select._native_single "Choose:" "only" 2> /dev/null
}

@test "select._native_multi - 单选项数组" {
  result=$(echo "0" | select._native_multi "Choose:" "only" 2> /dev/null)
  [ "$result" = "only" ]
}

@test "select._native_multi - 重复索引处理" {
  result=$(echo "0 0 1" | select._native_multi "Choose:" "opt0" "opt1" 2> /dev/null)
  # 重复索引应该被保留（Bash 数组行为）
  [ "$result" = "opt0 opt0 opt1" ]
}

# 特殊字符测试
@test "select._native_single - 选项包含空格" {
  result=$(echo "1" | select._native_single "Choose:" "opt 0" "opt 1" "opt 2" 2> /dev/null)
  [ "$result" = "opt 1" ]
}

@test "select._native_multi - 选项包含空格" {
  result=$(echo "0 2" | select._native_multi "Choose:" "opt 0" "opt 1" "opt 2" 2> /dev/null)
  [ "$result" = "opt 0 opt 2" ]
}
