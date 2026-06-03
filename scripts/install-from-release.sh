#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DSTROOT="${DSTROOT:-/Library/Input Methods}"
APP_SOURCE="${SCRIPT_DIR}/Qiwo.app"
APP_TARGET="${DSTROOT}/Qiwo.app"
LEGACY_TARGET="${DSTROOT}/Squirrel.app"

if [ ! -d "${APP_SOURCE}" ]; then
  echo "Qiwo.app not found next to install.sh" >&2
  exit 1
fi

echo "==> Installing Qiwo Input Method for macOS"
echo "==> Target: ${APP_TARGET}"

sudo mkdir -p "${DSTROOT}"
sudo rm -rf "${APP_TARGET}" "${LEGACY_TARGET}"
sudo ditto "${APP_SOURCE}" "${APP_TARGET}"
sudo xattr -dr com.apple.quarantine "${APP_TARGET}" 2>/dev/null || true

sudo env DSTROOT="${DSTROOT}" bash "${SCRIPT_DIR}/postinstall"

echo "==> Done. Select Qiwo from the input method menu."
