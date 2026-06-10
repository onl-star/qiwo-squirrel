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

config="qiwo-squirrel/sources/QiwoConfig.swift"
controller="qiwo-squirrel/sources/QiwoInputController.swift"

assert_file "$config"
assert_file "$controller"

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

echo "PASS: macOS switcher auto spacing source checks"
