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

assert_contains() {
  local text="$1"
  local path="$2"
  grep -Fq -- "$text" "$path" || fail "missing text in $path: $text"
}

wrapper="qiwo-squirrel/sources/QiwoInputFormatter.swift"
bridging_header="qiwo-squirrel/sources/Qiwo-Bridging-Header.h"
config="qiwo-squirrel/data/squirrel.yaml"
controller="qiwo-squirrel/sources/QiwoInputController.swift"
project="qiwo-squirrel/Qiwo.xcodeproj/project.pbxproj"
gitmodules="qiwo-squirrel/.gitmodules"

assert_file "$wrapper"
assert_file "$bridging_header"
assert_file "$config"
assert_file "$controller"
assert_file "$project"
assert_file "$gitmodules"

assert_grep "struct[[:space:]]+QiwoInputFormatter|enum[[:space:]]+QiwoInputFormatter|final[[:space:]]+class[[:space:]]+QiwoInputFormatter" "$wrapper"
assert_grep "QiwoInputFormatOptions" "$wrapper"
assert_grep "qiwo_input_format_commit_text" "$wrapper"
assert_grep "qiwo_input_format_free_string" "$wrapper"
assert_grep "beforeCursor:[[:space:]]*String\\?|beforeCursor[[:space:]]*=[[:space:]]*nil" "$wrapper"
assert_grep "afterCursor:[[:space:]]*String\\?|afterCursor[[:space:]]*=[[:space:]]*nil" "$wrapper"
assert_grep "auto_spacing_enabled[[:space:]]*=[[:space:]]*enabled" "$wrapper"

assert_grep "#import[[:space:]]+<qiwo_input_format\\.h>" "$bridging_header"

assert_grep "^input:" "$config"
assert_grep "^[[:space:]]+auto_commit_spacing:[[:space:]]*true([[:space:]]*(#.*)?)?$" "$config"

commit_body="$(awk '/func commit\(string: String\)/,/func show\(preedit:/' "$controller")"
[[ "$commit_body" == *"QiwoInputFormatter"* ]] || fail "commit(string:) does not call QiwoInputFormatter"
[[ "$commit_body" == *'getBool("input/auto_commit_spacing") ?? true'* ]] || fail "commit(string:) does not default input/auto_commit_spacing to true"
[[ "$commit_body" == *"beforeCursor: surroundingText?.beforeCursor"* ]] || fail "commit(string:) does not pass before-cursor context"
[[ "$commit_body" == *"afterCursor: surroundingText?.afterCursor"* ]] || fail "commit(string:) does not pass after-cursor context"
[[ "$commit_body" == *"insertText(formattedString"* ]] || fail "commit(string:) does not insert formattedString"
assert_grep "commitDirectInputIfNeeded\\(event:" "$controller"
assert_grep "formattedString != text" "$controller"
assert_grep "modifiers\\.contains\\(\\.command\\).*modifiers\\.contains\\(\\.control\\).*modifiers\\.contains\\(\\.option\\)" "$controller"
assert_grep "markedRange\\(\\)" "$controller"
assert_grep "selectedRange\\(\\)" "$controller"
assert_grep "attributedSubstring\\(from:" "$controller"

assert_grep "QiwoInputFormatter\\.swift" "$project"
assert_grep "\\$\\(SRCROOT\\)/qiwo-input-format-core/qiwo-input-format/include" "$project"
assert_grep "cargo build -p qiwo-input-format" "$project"
assert_contains 'build_archs=\"${ARCHS:-$(uname -m)}\"' "$project"
assert_contains 'aarch64-apple-darwin' "$project"
assert_contains 'x86_64-apple-darwin' "$project"
assert_contains 'cargo build -p qiwo-input-format $cargo_args --target \"$rust_target\"' "$project"
assert_contains 'lipo -create $built_libs -output \"$SRCROOT/lib/libqiwo_input_format.dylib\"' "$project"
assert_grep "install_name_tool -id @rpath/libqiwo_input_format\\.dylib" "$project"
assert_grep "\\$\\(SRCROOT\\)/lib" "$project"
assert_grep "-lqiwo_input_format" "$project"
assert_grep "libqiwo_input_format\\.dylib" "$project"
assert_grep "path[[:space:]]*=[[:space:]]*qiwo-input-format-core" "$gitmodules"
assert_grep "url[[:space:]]*=[[:space:]]*https://github\\.com/onl-star/qiwo-input-format-core\\.git" "$gitmodules"
if grep -q "\\$\\(SRCROOT\\)/\\.\\./qiwo-input-format-core" "$project"; then
  fail "project still references sibling qiwo-input-format-core instead of the submodule"
fi

echo "PASS: macOS input format source integration checks"
