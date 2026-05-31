#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[--]${NC} $1"; }
err()   { echo -e "${RED}[ERR]${NC} $1"; }
header(){ echo -e "\n${YELLOW}=== $1 ===${NC}"; }

# ── 1. submodule / dependency check ────────────────────────────

header "Checking dependencies"

need_git_clone=false

check_dir() {
  local dir=$1 name=$2 repo=$3
  if [ ! -f "$dir" ]; then
    warn "$name not found"
    need_git_clone=true
  else
    info "$name found"
  fi
}

if [ -f .gitmodules ] || [ -d .git ]; then
  info "Git repo detected, initializing submodules..."
  git submodule update --init --recursive 2>/dev/null || warn "submodule init failed, will clone manually"
fi

check_dir "librime/CMakeLists.txt" "librime" "https://github.com/rime/librime.git"
check_dir "plum/Makefile"              "plum"    "https://github.com/rime/plum.git"
check_dir "Sparkle/Sparkle.xcodeproj" "Sparkle" "https://github.com/sparkle-project/Sparkle.git"

if $need_git_clone; then
  header "Downloading missing dependencies"
  [ ! -f librime/CMakeLists.txt ] && git clone --depth 1 https://github.com/rime/librime.git librime && info "librime cloned"
  [ ! -f plum/Makefile ]          && git clone --depth 1 https://github.com/rime/plum.git plum       && info "plum cloned"
  [ ! -d Sparkle/Sparkle.xcodeproj ] && git clone --depth 1 https://github.com/sparkle-project/Sparkle.git Sparkle && info "Sparkle cloned"
fi

# ── 2. .NET SDK check ──────────────────────────────────────────

header "Checking .NET SDK"
if command -v dotnet &>/dev/null; then
  info "dotnet $(dotnet --version)"
else
  warn ".NET SDK not found, attempting brew install..."
  if command -v brew &>/dev/null; then
    brew install dotnet-sdk@8 && info "dotnet installed"
  else
    err "Please install .NET 8 SDK: https://dotnet.microsoft.com/download"
    exit 1
  fi
fi

# ── 3. Build librime ──────────────────────────────────────────

header "Building librime"
if [ -f lib/librime.1.dylib ]; then
  info "librime already built"
else
  cd librime
  if [ ! -d dist ]; then
    make deps && make release && make install
  fi
  cd ..
  mkdir -p lib bin
  cp librime/dist/lib/librime.1.dylib lib/ 2>/dev/null || true
  cp librime/dist/bin/rime_deployer bin/   2>/dev/null || true
  cp librime/dist/bin/rime_dict_manager bin/ 2>/dev/null || true
  info "librime built"
fi

# ── 4. Prepare data ──────────────────────────────────────────

header "Preparing data files"
if [ ! -f data/plum/default.yaml ] && [ -f plum/Makefile ]; then
  (cd plum && make) || warn "plum data build failed"
  mkdir -p data/plum data/opencc
  cp plum/output/*.yaml plum/output/*.txt data/plum/ 2>/dev/null || true
  cp plum/output/opencc/* data/opencc/ 2>/dev/null || true
  cp plum/rime-install bin/ 2>/dev/null || true
  info "data prepared"
else
  info "data already prepared or plum not available"
fi

# ── 5. Build qiwo-rime-sync ──────────────────────────────────

header "Building qiwo-rime-sync"
SYNC_SRC="../qiwo-sync-core/src/qiwo-rime-sync"
if [ -f "$SYNC_SRC/Program.cs" ]; then
  ARCH=$(uname -m)
  [ "$ARCH" = "arm64" ] && RID="osx-arm64" || RID="osx-x64"
  dotnet publish "$SYNC_SRC/qiwo-rime-sync.csproj" \
    --configuration Release --runtime "$RID" \
    --self-contained true -p:PublishSingleFile=true -p:PublishTrimmed=true \
    -o qiwo-sync 2>&1 | tail -1
  info "qiwo-rime-sync published for $RID"
elif [ -f qiwo-sync/qiwo-rime-sync ]; then
  info "qiwo-rime-sync already present"
else
  warn "qiwo-sync-core not found, sync tool will not be bundled"
fi

# ── 6. Build Qiwo.app ─────────────────────────────────────────

header "Building Qiwo.app"
if command -v xcodebuild &>/dev/null; then
  xcodebuild -project Qiwo.xcodeproj -configuration Release -scheme Qiwo -derivedDataPath build build 2>&1 | tail -3
  info "Build complete: build/Build/Products/Release/Qiwo.app"
else
  warn "xcodebuild not found, skipping app build"
  warn "Install Xcode and run: make release"
fi

header "Setup complete"
echo "Run: sudo make install-release   # to install"
echo "Or:  open build/Build/Products/Release/"
