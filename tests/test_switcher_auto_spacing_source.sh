#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing $path"
}

assert_grep() {
  local pattern="$1"
  local path="$2"
  grep -Eq -- "$pattern" "$path" || fail "missing pattern in $path: $pattern"
}

assert_not_grep() {
  local pattern="$1"
  local path="$2"
  ! grep -Eq -- "$pattern" "$path" || fail "unexpected pattern in $path: $pattern"
}

config="qiwo-squirrel/sources/QiwoConfig.swift"
controller="qiwo-squirrel/sources/QiwoInputController.swift"
delegate="qiwo-squirrel/sources/QiwoApplicationDelegate.swift"
makefile="qiwo-squirrel/Makefile"
action_install="qiwo-squirrel/action-install.sh"
project="qiwo-squirrel/Qiwo.xcodeproj/project.pbxproj"
add_data_files="qiwo-squirrel/package/add_data_files"
gitmodules="qiwo-squirrel/.gitmodules"

assert_file "$config"
assert_file "$controller"
assert_file "$delegate"
assert_file "$makefile"
assert_file "$action_install"
assert_file "$project"
assert_file "$add_data_files"
assert_file "$gitmodules"

assert_grep "func[[:space:]]+autoCommitSpacingEnabled\\(" "$config"
assert_grep "user_config_open\\(\"user\"" "$config"
assert_grep "var/option/auto_commit_spacing" "$config"
assert_grep "getBool\\(\"input/auto_commit_spacing\"\\)[[:space:]]*\\?\\?[[:space:]]*true" "$config"

create_session_body="$(awk '/func createSession\(\)/,/func updateAppOptions\(\)/' "$controller")"
[[ "$create_session_body" == *'rimeAPI.set_option(session, "auto_commit_spacing"'* ]] ||
  fail "createSession() does not seed the Rime auto_commit_spacing option"
[[ "$create_session_body" == *"fallbackAutoCommitSpacingEnabled()"* ]] ||
  fail "createSession() does not use the saved/config fallback value"

commit_body="$(awk '/func commit\(string: String\)/,/func show\(preedit:/' "$controller")"
[[ "$commit_body" == *'rimeAPI.get_option(session, "auto_commit_spacing")'* ]] ||
  fail "commit(string:) does not read the live Rime auto_commit_spacing option"
[[ "$commit_body" == *"fallbackAutoCommitSpacingEnabled()"* ]] ||
  fail "commit(string:) does not keep a config fallback"
[[ "$commit_body" == *"QiwoInputFormatter.formatCommitText"* ]] ||
  fail "commit(string:) does not format committed text"
[[ "$commit_body" == *"insertText(formattedString"* ]] ||
  fail "commit(string:) does not insert formattedString"

assert_grep "path[[:space:]]*=[[:space:]]*rime-frost" "$gitmodules"
assert_grep "gaboolic/rime-frost\\.git" "$gitmodules"
assert_grep "QIWO_FROST_ROOT[[:space:]]*\\?=[[:space:]]*rime-frost" "$makefile"
assert_not_grep "qiwo-ibusr/rime-frost" "$makefile"
assert_grep "git submodule update --init --recursive" "$makefile"
assert_grep "gaboolic/rime-frost\\.git" "$makefile"
assert_grep "copy-rime-frost-data" "$makefile"
assert_grep "copy-rime-frost-data" "$action_install"
assert_grep "submodule update --init plum rime-frost" "$action_install"
assert_grep "rime-frost in Copy Shared Support Files" "$project"
assert_grep "data/rime-frost" "$project"
assert_grep "data/rime-frost" "$add_data_files"
assert_grep "initializeBundledFrostIfNeeded\\(" "$delegate"
assert_grep "rime_frost\\.schema\\.yaml" "$delegate"
assert_grep "default\\.custom\\.yaml" "$delegate"
assert_grep "schema: rime_frost" "$delegate"
assert_grep "switcher/hotkeys/@next: F4" "$delegate"
assert_grep "switcher/save_options/@next: auto_commit_spacing" "$delegate"
assert_grep "fileName\\.hasPrefix\\(\"rime_frost\"\\)" "$delegate"
assert_grep "schemaID.*custom\\.yaml" "$delegate"
assert_grep "switches/@next" "$delegate"
assert_grep "关闭中英数字自动空格" "$delegate"
assert_grep "开启中英数字自动空格" "$delegate"

echo "PASS: macOS switcher auto spacing source checks"
