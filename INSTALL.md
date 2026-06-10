# 齐我输入法 macOS 端安装指南

## 系统要求

- macOS 13.0 或更高版本

## 安装方式

正式产物由 GitHub Actions 构建。下载 `Qiwo-macOS-*.tar.gz` 后解压，运行包内脚本：

```bash
./install.sh
```

该脚本只安装同目录的 `Qiwo.app`，不进行本地源码构建，也不会触发未签名 `.pkg` 安装流程。

安装时会先停用并删除 `/Library/Input Methods/Qiwo.app` 和旧的 `Squirrel.app`，刷新 macOS 输入法与 LaunchServices 缓存，再复制新版本并重新注册输入源。

如果已配置过 WebDAV，脚本会询问是否保留 `~/Library/Rime/.qiwo-sync/webdav.plist` 和 Keychain 中的 WebDAV 密码。也可以用参数显式指定：

```bash
./install.sh --keep-webdav-settings
./install.sh --reset-webdav-settings
```

源码目录里的 `install.sh` 和 `make install*` 目标已停用。当前安装链路只支持远程仓库 workflow/release 产物。

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

## 中英数字自动空格

默认开启提交文本格式化，会在汉字与半角英文、数字之间自动补空格。

切换到齐我输入法后，按 `Ctrl` + `` ` `` 或 `F4` 打开 Rime 方案选单，可以切换 **「中英数字自动空格」**。该开关会立即影响后续上屏文本，并由 Rime 记住状态。

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
