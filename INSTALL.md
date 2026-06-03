# 齐我输入法 macOS 端安装指南

## 系统要求

- macOS 13.0 或更高版本
- Xcode 16+（用于编译）
- Rust toolchain（用于构建同步工具）

## 推荐安装方式

正式产物由 GitHub Actions 构建。下载 `Qiwo-macOS-*.tar.gz` 后解压，运行包内脚本：

```bash
./install.sh
```

该脚本会把同目录的 `Qiwo.app` 安装到 `/Library/Input Methods/` 并完成输入法注册，不依赖本地源码构建，也不会触发未签名 `.pkg` 安装流程。

## 源码构建依赖

```bash
brew install cmake git rust

# 安装 Xcode（通过 App Store）
# 安装 Command Line Tools
xcode-select --install
```

## 源码准备

qiwo-squirrel 依赖三个子模块（librime、plum、Sparkle）。如果这些目录为空，需要先初始化：

```bash
cd qiwo-squirrel

# 初始化子模块（首次构建必须）
git submodule update --init --recursive

# 如果 qiwo-squirrel 不是 git 仓库（是 copy 出来的），需要手动获取依赖
if [ ! -f librime/CMakeLists.txt ]; then
  git clone --depth 1 https://github.com/rime/librime.git librime
fi
if [ ! -f plum/Makefile ]; then
  git clone --depth 1 https://github.com/rime/plum.git plum
fi
if [ ! -d Sparkle/Sparkle.xcodeproj ]; then
  git clone --depth 1 https://github.com/sparkle-project/Sparkle.git Sparkle
fi
```

## 编译

### 1. 构建 qiwo-rime-sync

```bash
cd qiwo-sync-core
cargo build --release -p qiwo-rime-sync
```

### 2. 复制同步工具到应用包

```bash
mkdir -p qiwo-squirrel/qiwo-sync
cp qiwo-sync-core/target/release/qiwo-rime-sync qiwo-squirrel/qiwo-sync/
```

### 3. 构建依赖

```bash
cd qiwo-squirrel

# 构建 librime（如需要）
make librime

# 准备数据文件
make data

# 下载 Sparkle 框架
make deps
```

### 4. 编译 Qiwo.app

```bash
cd qiwo-squirrel
make release
```

编译产物位于 `build/Build/Products/Release/Qiwo.app`。

## 安装

```bash
cd qiwo-squirrel

# 安装到系统输入法目录
sudo make install-release
```

或者手动安装：

```bash
# 复制到系统输入法目录
sudo cp -R build/Build/Products/Release/Qiwo.app "/Library/Input Methods/"

# 注册输入法
"/Library/Input Methods/Qiwo.app/Contents/MacOS/Qiwo" --register-input-source

# 启用输入法
"/Library/Input Methods/Qiwo.app/Contents/MacOS/Qiwo" --enable-input-source

# 选择输入法
"/Library/Input Methods/Qiwo.app/Contents/MacOS/Qiwo" --select-input-source
```

## 配置 WebDAV 同步

### 方式一：偏好设置窗口

1. 切换到齐我输入法
2. 点击菜单栏的输入法图标 → **「WebDAV 设置…」**
3. 填写：
   - **Server URL**: WebDAV 服务器地址（如 `https://dav.example.com`）
   - **Remote path**: 远程路径（默认 `qiwo-rime-sync`）
   - **Username / Password**: WebDAV 凭据
   - **Device ID**: 设备标识（默认自动获取）
4. 点击 **「测试连接」** 验证配置
5. 点击 **「保存」**

### 方式二：环境变量

```bash
export QIWO_WEBDAV_URL="https://dav.example.com/qiwo-rime-sync"
export QIWO_WEBDAV_USERNAME="username"
export QIWO_WEBDAV_PASSWORD="password"
export QIWO_DEVICE_ID="mac-main"
```

环境变量优先级高于偏好设置。

## 使用同步

### 手动同步

- 输入法菜单 → **「WebDAV 同步」**
- 或命令行：`"/Library/Input Methods/Qiwo.app/Contents/MacOS/Qiwo" --webdav-sync`

### 命令行选项

```bash
# 执行 WebDAV 同步
Qiwo.app/Contents/MacOS/Qiwo --webdav-sync

# 打开 WebDAV 设置窗口
Qiwo.app/Contents/MacOS/Qiwo --webdav-sync-settings

# 重新部署
Qiwo.app/Contents/MacOS/Qiwo --reload

# 显示帮助
Qiwo.app/Contents/MacOS/Qiwo --help
```

## 数据存储位置

| 内容 | 路径 |
|------|------|
| Rime 用户配置 | `~/Library/Rime/` |
| WebDAV 设置 | `~/Library/Rime/.qiwo-sync/webdav.plist` |
| 同步清单 | `~/Library/Rime/.qiwo-sync/manifest.json` |
| 冲突备份 | `~/Library/Rime/.qiwo-sync/backups/` |
| 密码 | macOS Keychain |

## 卸载

```bash
# 注销输入法
"/Library/Input Methods/Qiwo.app/Contents/MacOS/Qiwo" --disable-input-source

# 删除应用
sudo rm -rf "/Library/Input Methods/Qiwo.app"

# 删除用户数据（可选）
rm -rf ~/Library/Rime
```
