import Foundation

/// 确保 Rime 的 installation.yaml 包含正确的同步配置。
/// installation_id 使用设备标识，sync_dir 指向 "sync/"。
enum QiwoInstallationHelper {
  static let syncDir = "sync"

  /// 确保 installation.yaml 包含正确的 installation_id 和 sync_dir。
  /// installation_id 始终设为 WebDAV 设备 ID。sync_dir 若缺失则补充。
  static func ensure(rimeUserDir: String, deviceId: String) {
    let file = URL(fileURLWithPath: rimeUserDir).appendingPathComponent("installation.yaml")
    let safeId = makeSafeId(deviceId)

    if FileManager.default.fileExists(atPath: file.path) {
      guard var content = try? String(contentsOf: file, encoding: .utf8) else { return }

      // 替换或添加 installation_id
      if content.contains("installation_id:") {
        content = content.replacingOccurrences(
          of: #"installation_id:.*"#,
          with: "installation_id: \"\(safeId)\"",
          options: .regularExpression
        )
      } else {
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        content.append("\ninstallation_id: \"\(safeId)\"\n")
      }

      // 添加 sync_dir（若缺失）
      if !content.contains("sync_dir:") {
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        content.append("\nsync_dir: \"\(syncDir)\"\n")
      }

      try? content.write(to: file, atomically: true, encoding: .utf8)
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
