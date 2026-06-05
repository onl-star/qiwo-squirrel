#!/bin/bash
set -euo pipefail

cat >&2 <<'EOF'
Qiwo macOS no longer supports local source installation from this script.

Use the GitHub Actions artifact instead:
  1. Download Qiwo-macOS-*.tar.gz from the remote repository workflow/release.
  2. Extract it.
  3. Run ./install.sh inside the extracted artifact directory.

The artifact installer installs the bundled Qiwo.app directly and refreshes
macOS input method caches after replacing any existing installation.
EOF

exit 1
