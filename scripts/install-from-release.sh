#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Install the Qiwo.app bundled in this GitHub Actions artifact.

Options:
  --keep-webdav-settings       Keep existing WebDAV settings and Keychain password
  --reset-webdav-settings      Remove existing WebDAV settings and Keychain password
  --dstroot PATH               Install location, default: /Library/Input Methods
  -h, --help                   Show this help

Environment:
  QIWO_INSTALL_WEBDAV_SETTINGS=keep|reset|ask
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DSTROOT="${DSTROOT:-/Library/Input Methods}"
WEBDAV_CHOICE="${QIWO_INSTALL_WEBDAV_SETTINGS:-ask}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --keep-webdav|--keep-webdav-settings|--preserve-webdav-settings)
      WEBDAV_CHOICE="keep"
      ;;
    --reset-webdav|--reset-webdav-settings|--discard-webdav-settings)
      WEBDAV_CHOICE="reset"
      ;;
    --dstroot)
      shift
      if [ "$#" -eq 0 ]; then
        echo "--dstroot requires a path" >&2
        exit 2
      fi
      DSTROOT="$1"
      ;;
    --dstroot=*)
      DSTROOT="${1#--dstroot=}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

case "${WEBDAV_CHOICE}" in
  keep|reset|ask) ;;
  *)
    echo "QIWO_INSTALL_WEBDAV_SETTINGS must be keep, reset, or ask" >&2
    exit 2
    ;;
esac

APP_SOURCE="${SCRIPT_DIR}/Qiwo.app"
APP_TARGET="${DSTROOT}/Qiwo.app"
LEGACY_TARGET="${DSTROOT}/Squirrel.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
KEYCHAIN_SERVICE="im.rime.inputmethod.Qiwo.webdav"
KEYCHAIN_ACCOUNT="webdav-password"

if [ ! -d "${APP_SOURCE}" ]; then
  echo "Qiwo.app not found next to install.sh; download and extract a Qiwo-macOS-*.tar.gz Actions artifact first." >&2
  exit 1
fi

LOGIN_USER="$(/usr/bin/stat -f%Su /dev/console 2>/dev/null || true)"
if [ -z "${LOGIN_USER}" ] || [ "${LOGIN_USER}" = "root" ]; then
  LOGIN_USER="${SUDO_USER:-$(/usr/bin/id -un)}"
fi
LOGIN_HOME="$(/usr/bin/dscl . -read "/Users/${LOGIN_USER}" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')"
if [ -z "${LOGIN_HOME}" ] || [ ! -d "${LOGIN_HOME}" ]; then
  LOGIN_HOME="${HOME}"
fi

WEBDAV_SETTINGS_FILE="${LOGIN_HOME}/Library/Rime/.qiwo-sync/webdav.plist"

run_as_login_user() {
  if [ "$(/usr/bin/id -un)" = "${LOGIN_USER}" ]; then
    "$@"
  else
    /usr/bin/sudo -u "${LOGIN_USER}" "$@"
  fi
}

resolve_webdav_choice() {
  if [ "${WEBDAV_CHOICE}" != "ask" ]; then
    return
  fi
  if [ ! -f "${WEBDAV_SETTINGS_FILE}" ]; then
    WEBDAV_CHOICE="keep"
    return
  fi
  if [ -t 0 ]; then
    echo "==> Existing WebDAV settings: ${WEBDAV_SETTINGS_FILE}"
    answer=""
    read -r -p "Keep existing WebDAV settings and Keychain password? [Y/n] " answer || answer=""
    case "${answer}" in
      n|N|no|NO|No)
        WEBDAV_CHOICE="reset"
        ;;
      *)
        WEBDAV_CHOICE="keep"
        ;;
    esac
  else
    WEBDAV_CHOICE="keep"
  fi
}

apply_webdav_choice() {
  if [ "${WEBDAV_CHOICE}" = "reset" ]; then
    echo "==> Resetting WebDAV settings for ${LOGIN_USER}"
    run_as_login_user /bin/rm -f "${WEBDAV_SETTINGS_FILE}" || true
    run_as_login_user /usr/bin/security delete-generic-password \
      -s "${KEYCHAIN_SERVICE}" \
      -a "${KEYCHAIN_ACCOUNT}" >/dev/null 2>&1 || true
  else
    echo "==> Keeping WebDAV settings for ${LOGIN_USER}"
  fi
}

stop_existing_input_method() {
  echo "==> Stopping existing Qiwo processes"
  if [ -x "${APP_TARGET}/Contents/MacOS/Qiwo" ]; then
    run_as_login_user "${APP_TARGET}/Contents/MacOS/Qiwo" --disable-input-source >/dev/null 2>&1 || true
    run_as_login_user "${APP_TARGET}/Contents/MacOS/Qiwo" --quit >/dev/null 2>&1 || true
  fi
  run_as_login_user /usr/bin/killall Qiwo >/dev/null 2>&1 || true
  run_as_login_user /usr/bin/killall Squirrel >/dev/null 2>&1 || true
}

unregister_old_bundle_paths() {
  if [ -x "${LSREGISTER}" ]; then
    /usr/bin/sudo "${LSREGISTER}" -u "${APP_TARGET}" >/dev/null 2>&1 || true
    /usr/bin/sudo "${LSREGISTER}" -u "${LEGACY_TARGET}" >/dev/null 2>&1 || true
  fi
}

refresh_system_caches() {
  local app_path="$1"
  if [ -d "${app_path}" ]; then
    if [ -x "${LSREGISTER}" ]; then
      /usr/bin/sudo "${LSREGISTER}" -f "${app_path}" >/dev/null 2>&1 || true
    fi
    /usr/bin/sudo /usr/bin/mdimport "${app_path}" >/dev/null 2>&1 || true
  fi
  /usr/bin/sudo /usr/bin/touch "${DSTROOT}" >/dev/null 2>&1 || true
  run_as_login_user /usr/bin/killall cfprefsd >/dev/null 2>&1 || true
  run_as_login_user /usr/bin/killall TextInputMenuAgent >/dev/null 2>&1 || true
  run_as_login_user /usr/bin/killall SystemUIServer >/dev/null 2>&1 || true
}

echo "==> Installing Qiwo Input Method for macOS from GitHub Actions artifact"
echo "==> Source: ${APP_SOURCE}"
echo "==> Target: ${APP_TARGET}"

resolve_webdav_choice
apply_webdav_choice
stop_existing_input_method
unregister_old_bundle_paths

echo "==> Removing old installed app"
/usr/bin/sudo /bin/mkdir -p "${DSTROOT}"
/usr/bin/sudo /bin/rm -rf "${APP_TARGET}" "${LEGACY_TARGET}"
refresh_system_caches "${APP_TARGET}"

echo "==> Copying new app"
/usr/bin/sudo /usr/bin/ditto "${APP_SOURCE}" "${APP_TARGET}"
/usr/bin/sudo /usr/bin/xattr -dr com.apple.quarantine "${APP_TARGET}" 2>/dev/null || true

echo "==> Running postinstall"
/usr/bin/sudo env DSTROOT="${DSTROOT}" bash "${SCRIPT_DIR}/postinstall"
refresh_system_caches "${APP_TARGET}"

echo "==> Done. Select Qiwo from the input method menu."
