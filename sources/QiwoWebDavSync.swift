import Foundation

final class QiwoWebDavSync {
  enum Mode: String {
    case sync = "sync"
    case push = "push"
    case pull = "pull"
  }

  private let settings: QiwoWebDavSettings
  private let password: String

  init(settings: QiwoWebDavSettings, password: String) {
    self.settings = settings
    self.password = password
  }

  func run(mode: Mode = .sync) -> (success: Bool, exitCode: Int32, output: String) {
    guard let syncTool = findSyncTool() else {
      return (false, -1, "qiwo-rime-sync not found in app bundle.")
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
      "--remote-url", url,
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

      if process.terminationStatus == 0 {
        DistributedNotificationCenter.default()
          .postNotificationName(.init("QiwoReloadNotification"), object: nil)
      }

      return (process.terminationStatus == 0, process.terminationStatus, output)
    } catch {
      return (false, -1, error.localizedDescription)
    }
  }

  private func findSyncTool() -> URL? {
    if let resourcePath = Bundle.main.resourcePath {
      let bundled = URL(fileURLWithPath: resourcePath)
        .appendingPathComponent("qiwo-sync/qiwo-rime-sync")
      if FileManager.default.isExecutableFile(atPath: bundled.path) {
        return bundled
      }
    }
    return nil
  }
}
