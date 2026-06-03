import Foundation

/// 确保 Rime 的 installation.yaml 包含正确的同步配置。
/// installation_id 使用设备标识，sync_dir 指向 "sync/"。
enum QiwoInstallationHelper {
  static let syncDir = "sync"

  /// 确保 installation.yaml 包含正确的 installation_id 和 sync_dir。
  /// 如果 installation_id 被替换，会迁移旧的 sync 数据到新目录。
  static func ensure(rimeUserDir: String, deviceId: String) {
    let file = URL(fileURLWithPath: rimeUserDir).appendingPathComponent("installation.yaml")
    let safeId = makeSafeId(deviceId)
    var oldInstallationId: String?

    if FileManager.default.fileExists(atPath: file.path) {
      guard var content = try? String(contentsOf: file, encoding: .utf8) else { return }

      let needsUpdate = !content.contains("sync_dir:")
      // 提取旧的 installation_id
      if let match = try? NSRegularExpression(pattern: #"installation_id:\s*"([^"]*)""#)
        .firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
        let range = Range(match.range(at: 1), in: content) {
        oldInstallationId = String(content[range])
      }

      // 替换或添加 installation_id
      if content.contains("installation_id:") {
        content = content.replacingOccurrences(
          of: #"installation_id:\s*"[^"]*""#,
          with: "installation_id: \"\(safeId)\"",
          options: .regularExpression
        )
      } else {
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        content.append("\ninstallation_id: \"\(safeId)\"\n")
      }

      if needsUpdate {
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        content.append("\nsync_dir: \"\(syncDir)\"\n")
      }

      try? content.write(to: file, atomically: true, encoding: .utf8)

      // 迁移旧的 sync 数据
      if let oldId = oldInstallationId, oldId != safeId {
        migrateSyncData(rimeUserDir: rimeUserDir, from: oldId, to: safeId)
      }
      return
    }

    // 新建
    let yaml = """
      distribution: "Qiwo"
      distribution_version: "1.0"
      installation_id: "\(safeId)"
      sync_dir: "\(syncDir)"
      """
    try? yaml.write(to: file, atomically: true, encoding: .utf8)
  }

  /// 将旧 installation_id 的 sync 数据迁移到新目录。
  private static func migrateSyncData(rimeUserDir: String, from oldId: String, to newId: String) {
    let syncDirUrl = URL(fileURLWithPath: rimeUserDir).appendingPathComponent(syncDir)
    let oldDir = syncDirUrl.appendingPathComponent(oldId)
    let newDir = syncDirUrl.appendingPathComponent(newId)

    guard FileManager.default.fileExists(atPath: oldDir.path) else { return }

    try? FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)

    if let files = try? FileManager.default.contentsOfDirectory(at: oldDir, includingPropertiesForKeys: nil) {
      for file in files {
        let dest = newDir.appendingPathComponent(file.lastPathComponent)
        try? FileManager.default.moveItem(at: file, to: dest)
      }
    }

    // 删除旧的空目录
    try? FileManager.default.removeItem(at: oldDir)
  }

  /// 确保 sync/{device_id}/ 目录存在。
  static func ensureSyncExportDir(rimeUserDir: String, deviceId: String) {
    let dir = URL(fileURLWithPath: rimeUserDir)
      .appendingPathComponent(syncDir)
      .appendingPathComponent(makeSafeId(deviceId))
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  }

  private static func makeSafeId(_ deviceId: String) -> String {
    deviceId
      .replacingOccurrences(of: " ", with: "-")
      .replacingOccurrences(of: ":", with: "-")
      .replacingOccurrences(of: "\\", with: "-")
      .replacingOccurrences(of: "/", with: "-")
      .lowercased()
  }
}
