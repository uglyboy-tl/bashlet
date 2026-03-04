#!/usr/bin/env bats

load 'test_helper/common-setup'

setup() {
  _common_setup
  import std/markdown.sh
}

@test "markdown.escape escapes pipe characters" {
  result=$(markdown.escape "test|pipe")
  [ "$result" = "test\|pipe" ]
}

@test "markdown.header creates headers with correct levels" {
  result=$(markdown.header 1 "Test")
  [ "$result" = "# Test" ]

  result=$(markdown.header 3 "Test")
  [ "$result" = "### Test" ]

  result=$(markdown.header 6 "Test")
  [ "$result" = "###### Test" ]
}

@test "markdown.h1-h6 functions work correctly" {
  [ "$(markdown.h1 "Test")" = "# Test" ]
  [ "$(markdown.h2 "Test")" = "## Test" ]
  [ "$(markdown.h3 "Test")" = "### Test" ]
  [ "$(markdown.h4 "Test")" = "#### Test" ]
  [ "$(markdown.h5 "Test")" = "##### Test" ]
  [ "$(markdown.h6 "Test")" = "###### Test" ]
}

@test "markdown.list creates bullet lists" {
  result=$(markdown.list "item1" "item2")
  expected="- item1
- item2"
  [ "$result" = "$expected" ]
}

@test "markdown.numbered creates numbered lists" {
  result=$(markdown.numbered "item1" "item2")
  expected="1. item1
2. item2"
  [ "$result" = "$expected" ]
}

@test "markdown.todo creates todo items" {
  result=$(markdown.todo "task")
  [ "$result" = "- [ ] task" ]
}

@test "markdown.table.header creates table headers" {
  result=$(markdown.table.header "Name" "Age")
  expected="| Name| Age|
|---|---|"
  [ "$result" = "$expected" ]
}

@test "markdown.table.row creates table rows" {
  result=$(markdown.table.row "John" "25")
  expected="| John | 25 |"
  [ "$result" = "$expected" ]

  # Test with empty value
  result=$(markdown.table.row "John" "")
  expected="| John | - |"
  [ "$result" = "$expected" ]
}

@test "markdown.code creates code blocks" {
  # With language
  result=$(markdown.code "bash" "echo hello")
  expected='```bash
echo hello
```'
  [ "$result" = "$expected" ]

  # Without language (single parameter)
  result=$(markdown.code "echo hello")
  expected='```
echo hello
```'
  [ "$result" = "$expected" ]

  # Empty language
  result=$(markdown.code "" "echo hello")
  expected='```
echo hello
```'
  [ "$result" = "$expected" ]
}

@test "markdown.line creates horizontal rules" {
  result=$(markdown.line)
  [ "$result" = "---" ]
}

@test "markdown.link creates links" {
  result=$(markdown.link "text" "url")
  [ "$result" = "[text](url)" ]
}

@test "markdown.quote creates blockquotes" {
  result=$(markdown.quote "quote")
  [ "$result" = "> quote" ]
}

@test "markdown.front_matter creates YAML front matter" {
  export SCRIPT_NAME="test"
  run bash -c "source $PROJECT_ROOT/lib/std/markdown.sh && markdown.front_matter 'Title'"
  [[ ${lines[0]} == "---" ]]
  [[ ${lines[1]} == "title: Title" ]]
  [[ ${lines[3]} == "author: test" ]]
  [[ ${lines[4]} == "---" ]]
}
