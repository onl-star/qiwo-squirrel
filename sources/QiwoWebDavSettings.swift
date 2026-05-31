import Foundation
import Security

struct QiwoWebDavSettings: Codable {
  var serverUrl: String = ""
  var remotePath: String = "qiwo-rime-sync"
  var username: String = ""
  var deviceId: String = ""

  static let defaultRemotePath = "qiwo-rime-sync"

  static func settingsFile() -> URL {
    let rimeDir = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Rime/.qiwo-sync")
    return rimeDir.appendingPathComponent("webdav.plist")
  }

  static func load() -> QiwoWebDavSettings {
    let file = settingsFile()
    guard let data = try? Data(contentsOf: file),
          let settings = try? PropertyListDecoder().decode(QiwoWebDavSettings.self, from: data)
    else {
      var defaults = QiwoWebDavSettings()
      defaults.deviceId = Host.current().localizedName ?? "mac"
      return defaults
    }
    if settings.remotePath.isEmpty {
      var fixed = settings
      fixed.remotePath = defaultRemotePath
      return fixed
    }
    return settings
  }

  func save() -> Bool {
    let file = Self.settingsFile()
    let dir = file.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    guard let data = try? PropertyListEncoder().encode(self) else { return false }
    do {
      try data.write(to: file)
      return true
    } catch {
      return false
    }
  }

  func buildRemoteUrl() -> String {
    var server = serverUrl.trimmingCharacters(in: .whitespaces)
    var remote = remotePath.trimmingCharacters(in: .whitespaces)

    if server.isEmpty { return "" }
    if remote.isEmpty { return server }

    if remote.hasPrefix("http://") || remote.hasPrefix("https://") {
      return remote
    }

    while server.hasSuffix("/") || server.hasSuffix("\\") {
      server.removeLast()
    }
    while remote.hasPrefix("/") || remote.hasPrefix("\\") {
      remote.removeFirst()
    }

    if remote.isEmpty { return server }
    return "\(server)/\(remote)"
  }
}

// MARK: - Keychain password storage

enum QiwoKeychain {
  private static let service = "im.rime.inputmethod.Qiwo.webdav"
  private static let account = "webdav-password"

  static func loadPassword() -> String {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess,
          let data = item as? Data,
          let password = String(data: data, encoding: .utf8)
    else { return "" }
    return password
  }

  static func savePassword(_ password: String) {
    if password.isEmpty {
      deletePassword()
      return
    }
    guard let data = password.data(using: .utf8) else { return }

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
      let update: [String: Any] = [kSecValueData as String: data]
      SecItemUpdate(query as CFDictionary, update as CFDictionary)
    } else {
      var add = query
      add[kSecValueData as String] = data
      SecItemAdd(add as CFDictionary, nil)
    }
  }

  static func deletePassword() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
  }
}
