import Foundation

final class QiwoWebDavSync {
  enum Mode: String {
    case sync
    case push
    case pull
    case syncUserDict = "sync-user-dict"
  }

  private let settings: QiwoWebDavSettings
  private let password: String

  init(settings: QiwoWebDavSettings, password: String) {
    self.settings = settings
    self.password = password
  }

  func run(mode: Mode = .sync) -> (success: Bool, exitCode: Int32, output: String) {
    guard let syncTool = findSyncTool() else {
      return (false, -1, "qiwo-rime-sync not found in app bundle. Expected at Resources/qiwo-sync/qiwo-rime-sync")
    }

    let url = settings.buildRemoteUrl()
    if url.isEmpty {
      return (false, -1, "WebDAV server URL is not configured.")
    }

    let userDir = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Rime").path

    var args: [String] = [
      mode.rawValue,
      "--frontend", "squirrel",
      "--rime-user-dir", userDir,
      "--remote-url", url
    ]

    if !settings.username.isEmpty {
      args.append(contentsOf: ["--username", settings.username])
    }

    if !settings.deviceId.isEmpty {
      args.append(contentsOf: ["--device-id", settings.deviceId])
    }

    var env = ProcessInfo.processInfo.environment
    if !password.isEmpty {
      env["QIWO_WEBDAV_PASSWORD"] = password
      args.append(contentsOf: ["--password-env", "QIWO_WEBDAV_PASSWORD"])
    }

    let process = Process()
    process.executableURL = syncTool
    process.arguments = args
    process.environment = env

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8) ?? ""

      return (process.terminationStatus == 0, process.terminationStatus, output)
    } catch {
      return (false, -1, error.localizedDescription)
    }
  }

  private func findSyncTool() -> URL? {
    // 1. App bundle Resources/qiwo-sync/
    if let resourcePath = Bundle.main.resourcePath {
      let bundled = URL(fileURLWithPath: resourcePath)
        .appendingPathComponent("qiwo-sync/qiwo-rime-sync")
      if FileManager.default.isExecutableFile(atPath: bundled.path) {
        return bundled
      }
    }

    // 2. System path (installed by install.sh)
    let systemPath = URL(fileURLWithPath: "/usr/local/bin/qiwo-rime-sync")
    if FileManager.default.isExecutableFile(atPath: systemPath.path) {
      return systemPath
    }

    return nil
  }
}
