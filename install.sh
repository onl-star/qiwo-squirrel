#!/bin/bash
set -e

# ============================================================
# 齐我输入法 (Qiwo) macOS 一键安装脚本
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  齐我输入法 (Qiwo) macOS 一键安装"
echo "=========================================="
echo ""

# ── 1. 系统环境检查 ────────────────────────────────────────

log_info "检查系统环境..."

MACOS_VER=$(sw_vers -productVersion 2>/dev/null || echo "0")
MACOS_MAJOR=$(echo "$MACOS_VER" | cut -d. -f1)
if [ "$MACOS_MAJOR" -lt 13 ]; then
    log_err "需要 macOS 13.0 或更高版本，当前: $MACOS_VER"
    exit 1
fi
log_ok "macOS $MACOS_VER"

# ── 1a. Xcode Command Line Tools ──────────────────────────────

if ! xcode-select -p &>/dev/null; then
    log_warn "未找到 Xcode Command Line Tools，正在安装..."
    xcode-select --install 2>/dev/null || true
    echo "请等待 Command Line Tools 安装完成后重新运行本脚本。"
    exit 0
fi
log_ok "Xcode Command Line Tools 已就绪"

# ── 1b. Homebrew ─────────────────────────────────────────────

NEED_BREW=false
if ! command -v brew &>/dev/null; then
    NEED_BREW=true
fi

# ── 1c. 构建工具检查与自动安装 ──────────────────────────────

MISSING_TOOLS=()
MISSING_BREW_PACKAGES=()

check_tool() {
    if ! command -v "$1" &>/dev/null; then
        MISSING_TOOLS+=("$1")
        MISSING_BREW_PACKAGES+=("${2:-$1}")
    fi
}

check_tool cmake
check_tool git
check_tool cargo rust

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    if [ "$NEED_BREW" = true ]; then
        log_warn "缺少构建工具: ${MISSING_TOOLS[*]}，需要先安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # 激活 brew (Apple Silicon 和 Intel 路径不同)
        if [ -f /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        NEED_BREW=false
    fi

    log_info "正在安装缺失工具: ${MISSING_TOOLS[*]}..."
    brew install "${MISSING_BREW_PACKAGES[@]}"
fi

log_ok "构建工具已就绪 (cmake: $(cmake --version 2>/dev/null | head -1 | awk '{print $NF}'), git: $(git --version | awk '{print $NF}'), cargo: $(cargo --version | awk '{print $2}'))"

# ── 2. Rust 同步核心 ────────────────────────────────────────

SYNC_CORE_DIR="$SCRIPT_DIR/../qiwo-sync-core"

# ── 3. 子模块初始化 ─────────────────────────────────────────

log_info "初始化子模块..."
make setup
log_ok "子模块就绪"

# ── 4. 构建依赖 (librime / plum data / opencc / Sparkle) ───

log_info "构建依赖 (这可能需要几分钟)..."
make deps
log_ok "依赖构建完成"

# ── 5. 构建同步工具 (可选) ──────────────────────────────────

HAS_SYNC=false
if [ -d "$SYNC_CORE_DIR" ]; then
    log_info "构建同步工具 (Rust)..."

    pushd "$SYNC_CORE_DIR" > /dev/null
    cargo build --release -p qiwo-rime-sync

    mkdir -p "$SCRIPT_DIR/qiwo-sync"
    cp "target/release/qiwo-rime-sync" "$SCRIPT_DIR/qiwo-sync/"
    popd > /dev/null

    HAS_SYNC=true
    log_ok "同步工具构建完成"
else
    log_warn "未找到 qiwo-sync-core，将跳过同步工具构建"
fi

# ── 6. 编译 Qiwo.app ────────────────────────────────────────

log_info "编译 Qiwo.app (Release)..."
make release
log_ok "编译完成"

# ── 7. 安装到系统 ──────────────────────────────────────────

echo ""
log_info "准备安装到 /Library/Input Methods/ (需要 sudo 权限)..."
sudo make install-release

# ── 8. 完成 ────────────────────────────────────────────────

echo ""
echo "=========================================="
echo "  安装完成！"
echo "=========================================="
echo ""
echo "  现在可以通过输入法菜单切换到「齐我」输入法。"
echo ""

if [ "$HAS_SYNC" = false ]; then
    echo "  WebDAV 同步: 未构建同步工具。"
else
    echo "  WebDAV 同步: 已集成，请在输入法菜单中配置。"
fi

echo ""
echo "  卸载: sudo rm -rf '/Library/Input Methods/Qiwo.app'"
echo "        rm -rf ~/Library/Rime"
echo ""
