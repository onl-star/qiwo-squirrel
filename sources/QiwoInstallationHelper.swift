import Foundation

/// 确保 Rime 的 installation.yaml 包含正确的同步配置。
/// installation_id 使用设备标识，sync_dir 指向 "sync/"。
enum QiwoInstallationHelper {
  static let syncDir = "sync"

  /// 确保 installation.yaml 存在且包含 installation_id 和 sync_dir。
  static func ensure(rimeUserDir: String, deviceId: String) {
    let file = URL(fileURLWithPath: rimeUserDir).appendingPathComponent("installation.yaml")
    let safeId = makeSafeId(deviceId)

    // 如果已存在，只补缺失的字段
    if FileManager.default.fileExists(atPath: file.path) {
      guard var content = try? String(contentsOf: file, encoding: .utf8) else { return }
      var updated = content.trimmingCharacters(in: .whitespacesAndNewlines)
      var needsUpdate = false

      if !updated.contains("sync_dir:") {
        updated.append("\n")
        updated.append("sync_dir: \"\(syncDir)\"\n")
        needsUpdate = true
      }
      if !updated.contains("installation_id:") {
        updated.append("\n")
        updated.append("installation_id: \"\(safeId)\"\n")
        needsUpdate = true
      }

      if needsUpdate {
        try? updated.write(to: file, atomically: true, encoding: .utf8)
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
