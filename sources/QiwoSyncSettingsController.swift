import AppKit
import Foundation

final class QiwoSyncSettingsController: NSWindowController {
  private var settings: QiwoWebDavSettings
  private var currentPassword: String = ""

  // MARK: - Controls

  private let serverUrlField = NSTextField()
  private let remotePathField = NSTextField()
  private let usernameField = NSTextField()
  private let passwordField = NSSecureTextField()
  private let deviceIdField = NSTextField()
  private let autoSyncCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
  private let intervalField = NSTextField()
  private let intervalLabel = NSTextField()
  private let statusLabel = NSTextField()
  private let testButton = NSButton()
  private let saveButton = NSButton()
  private let syncButton = NSButton()

  // MARK: - Init

  init() {
    settings = QiwoWebDavSettings.load()
    currentPassword = QiwoKeychain.loadPassword()

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = NSLocalizedString("WebDAV Sync Settings", comment: "")
    window.center()
    super.init(window: window)
    buildUI()
    loadFields()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) not implemented")
  }

  // MARK: - UI Construction

  private func buildUI() {
    guard let content = window?.contentView else { return }

    let yOffsets: [CGFloat] = [290, 258, 226, 194, 162, 130]
    let labels = [
      NSLocalizedString("Server URL:", comment: ""),
      NSLocalizedString("Remote path:", comment: ""),
      NSLocalizedString("Username:", comment: ""),
      NSLocalizedString("Password:", comment: ""),
      NSLocalizedString("Device ID:", comment: "")
    ]
    let fields: [NSTextField] = [
      serverUrlField, remotePathField, usernameField, passwordField, deviceIdField
    ]
    let placeholders = [
      "https://dav.example.com",
      "qiwo-rime-sync",
      "",
      "",
      Host.current().localizedName ?? "mac"
    ]

    for i in 0..<5 {
      let lbl = makeLabel(labels[i])
      lbl.frame = NSRect(x: 15, y: yOffsets[i] + 4, width: 100, height: 20)
      content.addSubview(lbl)

      let fld = fields[i]
      fld.frame = NSRect(x: 120, y: yOffsets[i], width: 340, height: 24)
      fld.placeholderString = placeholders[i]
      content.addSubview(fld)
    }

    // Auto-sync controls
    autoSyncCheckbox.title = NSLocalizedString("Auto-sync user dictionary", comment: "")
    autoSyncCheckbox.frame = NSRect(x: 120, y: 130, width: 250, height: 24)
    autoSyncCheckbox.state = settings.autoSync ? .on : .off
    content.addSubview(autoSyncCheckbox)

    intervalLabel.stringValue = NSLocalizedString("Interval (min):", comment: "")
    intervalLabel.isEditable = false
    intervalLabel.isBordered = false
    intervalLabel.drawsBackground = false
    intervalLabel.alignment = .right
    intervalLabel.font = NSFont.systemFont(ofSize: 12)
    intervalLabel.frame = NSRect(x: 280, y: 130, width: 80, height: 24)
    content.addSubview(intervalLabel)

    intervalField.frame = NSRect(x: 365, y: 130, width: 60, height: 24)
    intervalField.placeholderString = "60"
    intervalField.font = NSFont.systemFont(ofSize: 12)
    content.addSubview(intervalField)

    // Status label
    statusLabel.frame = NSRect(x: 15, y: 105, width: 445, height: 20)
    statusLabel.isEditable = false
    statusLabel.isBordered = false
    statusLabel.drawsBackground = false
    statusLabel.textColor = .secondaryLabelColor
    statusLabel.font = NSFont.systemFont(ofSize: 11)
    content.addSubview(statusLabel)

    // Buttons
    testButton.frame = NSRect(x: 15, y: 70, width: 120, height: 28)
    testButton.title = NSLocalizedString("Test Connection", comment: "")
    testButton.bezelStyle = .rounded
    testButton.target = self
    testButton.action = #selector(testConnection)
    content.addSubview(testButton)

    saveButton.frame = NSRect(x: 270, y: 15, width: 90, height: 28)
    saveButton.title = NSLocalizedString("Save", comment: "")
    saveButton.bezelStyle = .rounded
    saveButton.keyEquivalent = "\r"
    saveButton.target = self
    saveButton.action = #selector(save)
    content.addSubview(saveButton)

    let cancelButton = NSButton()
    cancelButton.frame = NSRect(x: 370, y: 15, width: 90, height: 28)
    cancelButton.title = NSLocalizedString("Cancel", comment: "")
    cancelButton.bezelStyle = .rounded
    cancelButton.target = self
    cancelButton.action = #selector(cancel)
    content.addSubview(cancelButton)

    syncButton.frame = NSRect(x: 15, y: 15, width: 120, height: 28)
    syncButton.title = NSLocalizedString("Sync Now", comment: "")
    syncButton.bezelStyle = .rounded
    syncButton.target = self
    syncButton.action = #selector(syncNow)
    content.addSubview(syncButton)

    // Info text
    let info = NSTextField()
    info.frame = NSRect(x: 15, y: 45, width: 445, height: 14)
    info.isEditable = false
    info.isBordered = false
    info.drawsBackground = false
    info.textColor = .tertiaryLabelColor
    info.font = NSFont.systemFont(ofSize: 10)
    info.stringValue = NSLocalizedString("Saved in ~/Library/Rime/.qiwo-sync/webdav.plist. Password is stored in Keychain.", comment: "")
    content.addSubview(info)
  }

  private func makeLabel(_ text: String) -> NSTextField {
    let lbl = NSTextField()
    lbl.isEditable = false
    lbl.isBordered = false
    lbl.drawsBackground = false
    lbl.alignment = .right
    lbl.stringValue = text
    lbl.font = NSFont.systemFont(ofSize: 13)
    return lbl
  }

  // MARK: - Field helpers

  private func loadFields() {
    serverUrlField.stringValue = settings.serverUrl
    remotePathField.stringValue = settings.remotePath
    usernameField.stringValue = settings.username
    passwordField.stringValue = currentPassword
    deviceIdField.stringValue = settings.deviceId
    autoSyncCheckbox.state = settings.autoSync ? .on : .off
    intervalField.stringValue = String(settings.syncIntervalMinutes)
  }

  private func readFields() {
    settings.serverUrl = serverUrlField.stringValue.trimmingCharacters(in: .whitespaces)
    settings.remotePath = remotePathField.stringValue.trimmingCharacters(in: .whitespaces)
    settings.username = usernameField.stringValue.trimmingCharacters(in: .whitespaces)
    settings.deviceId = deviceIdField.stringValue.trimmingCharacters(in: .whitespaces)
    currentPassword = passwordField.stringValue
    settings.autoSync = autoSyncCheckbox.state == .on
    settings.syncIntervalMinutes = Int(intervalField.stringValue) ?? 60
  }

  // MARK: - Actions

  @objc private func testConnection() {
    readFields()
    let url = settings.buildRemoteUrl()
    if url.isEmpty {
      showStatus(NSLocalizedString("Please enter a WebDAV server URL.", comment: ""), isError: true)
      return
    }

    showStatus(NSLocalizedString("Testing connection...", comment: ""), isError: false)
    testButton.isEnabled = false

    guard let requestURL = URL(string: url) else {
      showStatus(NSLocalizedString("Invalid URL.", comment: ""), isError: true)
      testButton.isEnabled = true
      return
    }

    var request = URLRequest(url: requestURL)
    request.httpMethod = "PROPFIND"
    request.setValue("0", forHTTPHeaderField: "Depth")
    request.timeoutInterval = 10

    if !settings.username.isEmpty || !currentPassword.isEmpty {
      let login = "\(settings.username):\(currentPassword)"
      if let encoded = login.data(using: .utf8)?.base64EncodedString() {
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
      }
    }

    URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
      DispatchQueue.main.async {
        self?.testButton.isEnabled = true
        if let error = error {
          self?.showStatus(
            String(format: NSLocalizedString("Connection failed: %@", comment: ""), error.localizedDescription),
            isError: true
          )
        } else if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
          self?.showStatus(
            String(format: NSLocalizedString("Server returned HTTP %d.", comment: ""), http.statusCode),
            isError: true
          )
        } else {
          self?.showStatus(NSLocalizedString("Connection successful.", comment: ""), isError: false)
        }
      }
    }.resume()
  }

  @objc private func save() {
    readFields()
    if settings.save() {
      QiwoKeychain.savePassword(currentPassword)
      // 重启自动同步以应用新设置
      NSApp.qiwoAppDelegate.startAutoSync()
      showStatus(NSLocalizedString("Settings saved.", comment: ""), isError: false)
    } else {
      showStatus(NSLocalizedString("Failed to save settings.", comment: ""), isError: true)
    }
  }

  @objc private func cancel() {
    window?.close()
  }

  @objc private func syncNow() {
    readFields()
    let sync = QiwoWebDavSync(settings: settings, password: currentPassword)
    showStatus(NSLocalizedString("Syncing...", comment: ""), isError: false)
    syncButton.isEnabled = false

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let result = sync.run(mode: .sync)
      DispatchQueue.main.async {
        self?.syncButton.isEnabled = true
        if result.success {
          self?.showStatus(NSLocalizedString("Sync completed.", comment: ""), isError: false)
        } else {
          let msg = result.output.isEmpty
            ? String(format: NSLocalizedString("Sync failed (exit code %d).", comment: ""), result.exitCode)
            : result.output
          self?.showStatus(msg, isError: true)
        }
      }
    }
  }

  private func showStatus(_ text: String, isError: Bool) {
    statusLabel.stringValue = text
    statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
  }
}
