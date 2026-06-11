//
//  QiwoApplicationDelegate.swift
//  Qiwo
//
//  Created by Leo Liu on 5/6/24.
//

import UserNotifications
import Sparkle
import AppKit

final class QiwoApplicationDelegate: NSObject, NSApplicationDelegate, SPUStandardUserDriverDelegate, UNUserNotificationCenterDelegate {
  static let rimeWikiURL = URL(string: "https://github.com/rime/home/wiki")!
  static let updateNotificationIdentifier = "QiwoUpdateNotification"
  static let notificationIdentifier = "QiwoNotification"

  let rimeAPI: RimeApi_stdbool = rime_get_api_stdbool().pointee
  var config: QiwoConfig?
  var panel: QiwoPanel?
  var enableNotifications = false
  let updateController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
  var supportsGentleScheduledUpdateReminders: Bool {
    true
  }

  func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
    NSApp.setActivationPolicy(.regular)
    if !state.userInitiated {
      NSApp.dockTile.badgeLabel = "1"
      let content = UNMutableNotificationContent()
      content.title = NSLocalizedString("A new update is available", comment: "Update")
      content.body = NSLocalizedString("Version [version] is now available", comment: "Update").replacingOccurrences(of: "[version]", with: update.displayVersionString)
      let request = UNNotificationRequest(identifier: Self.updateNotificationIdentifier, content: content, trigger: nil)
      UNUserNotificationCenter.current().add(request)
    }
  }

  func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
    NSApp.dockTile.badgeLabel = ""
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.updateNotificationIdentifier])
  }

  func standardUserDriverWillFinishUpdateSession() {
    NSApp.setActivationPolicy(.accessory)
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    if response.notification.request.identifier == Self.updateNotificationIdentifier && response.actionIdentifier == UNNotificationDefaultActionIdentifier {
      updateController.updater.checkForUpdates()
    }

    completionHandler()
  }

  func applicationWillFinishLaunching(_ notification: Notification) {
    panel = QiwoPanel(position: .zero)
    addObservers()
    startAutoSync()
  }

  func applicationWillTerminate(_ notification: Notification) {
    // swiftlint:disable:next notification_center_detachment
    NotificationCenter.default.removeObserver(self)
    DistributedNotificationCenter.default().removeObserver(self)
    panel?.hide()
  }

  func deploy() {
    print("Start maintenance...")
    self.shutdownRime()
    self.startRime(fullCheck: true)
    self.loadSettings()
  }

  func syncUserData() {
    print("Sync user data")
    _ = rimeAPI.sync_user_data()
  }

  // MARK: - WebDAV sync

  typealias WebDavSyncCompletion = (_ success: Bool, _ message: String) -> Void

  private var webdavSettingsController: QiwoSyncSettingsController?
  private var autoSyncTimer: Timer?

  func qiwoWebDavSync() {
    let settings = QiwoWebDavSettings.load()
    let password = QiwoKeychain.loadPassword()
    runWebDavSync(settings: settings, password: password, notify: true)
  }

  func qiwoWebDavSync(
    settings: QiwoWebDavSettings,
    password: String,
    completion: @escaping WebDavSyncCompletion
  ) {
    runWebDavSync(settings: settings, password: password, notify: false, completion: completion)
  }

  private func runWebDavSync(
    settings: QiwoWebDavSettings,
    password: String,
    notify: Bool,
    completion: WebDavSyncCompletion? = nil
  ) {
    DispatchQueue.global(qos: .userInitiated).async { [self] in
      if notify {
        QiwoApplicationDelegate.showMessage(msgText:
          NSLocalizedString("WebDAV sync starting...", comment: ""))
      }

      // 1. 确保 installation.yaml 配置了 sync_dir 和 installation_id
      let deviceId = settings.resolvedDeviceId
      QiwoInstallationHelper.ensure(
        rimeUserDir: QiwoApp.userDir.path,
        deviceId: deviceId
      )
      QiwoInstallationHelper.ensureSyncExportDir(
        rimeUserDir: QiwoApp.userDir.path,
        deviceId: deviceId
      )

      // 2. 先导出用户词库
      _ = self.rimeAPI.sync_user_data()

      // 3. WebDAV 同步（配置 + 用户词库）
      let sync = QiwoWebDavSync(settings: settings, password: password)
      let result = sync.run(mode: .sync)

      let message: String
      if result.success {
        // 4. 导入合并用户词库
        _ = self.rimeAPI.sync_user_data()

        // 5. 重新部署
        self.deploy()

        message = NSLocalizedString("WebDAV sync completed.", comment: "")
      } else {
        message = result.output.isEmpty
          ? "WebDAV sync failed (exit code \(result.exitCode))."
          : result.output
      }

      if notify {
        QiwoApplicationDelegate.showMessage(msgText: message)
      }
      completion?(result.success, message)
    }
  }

  func startAutoSync() {
    let settings = QiwoWebDavSettings.load()
    guard settings.autoSync, settings.syncIntervalMinutes > 0 else {
      stopAutoSync()
      return
    }

    let interval = TimeInterval(settings.syncIntervalMinutes * 60)
    autoSyncTimer?.invalidate()
    autoSyncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      self?.performAutoSync()
    }
    // 立即执行一次
    performAutoSync()
  }

  func stopAutoSync() {
    autoSyncTimer?.invalidate()
    autoSyncTimer = nil
  }

  private func performAutoSync() {
    let settings = QiwoWebDavSettings.load()
    let password = QiwoKeychain.loadPassword()
    let deviceId = settings.resolvedDeviceId

    QiwoInstallationHelper.ensure(
      rimeUserDir: QiwoApp.userDir.path,
      deviceId: deviceId
    )
    QiwoInstallationHelper.ensureSyncExportDir(
      rimeUserDir: QiwoApp.userDir.path,
      deviceId: deviceId
    )

    // 先导出词库
    _ = rimeAPI.sync_user_data()

    let sync = QiwoWebDavSync(settings: settings, password: password)

    DispatchQueue.global(qos: .utility).async {
      let result = sync.run(mode: .syncUserDict)
      if result.success {
        // 导入词库
        _ = self.rimeAPI.sync_user_data()
        print("Auto sync user dict completed")
      } else {
        print("Auto sync user dict failed: \(result.output)")
      }
    }
  }

  func openWebDavSettings() {
    if webdavSettingsController == nil {
      webdavSettingsController = QiwoSyncSettingsController()
    }
    webdavSettingsController?.showWindow(nil)
    webdavSettingsController?.window?.makeKeyAndOrderFront(nil)
  }

  func openLogFolder() {
    NSWorkspace.shared.open(QiwoApp.logDir)
  }

  func openRimeFolder() {
    NSWorkspace.shared.open(QiwoApp.userDir)
  }

  func checkForUpdates() {
    if updateController.updater.canCheckForUpdates {
      print("Checking for updates")
      updateController.updater.checkForUpdates()
    } else {
      print("Cannot check for updates")
    }
  }

  func openWiki() {
    NSWorkspace.shared.open(Self.rimeWikiURL)
  }

  static func showMessage(msgText: String?) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .provisional]) { _, error in
      if let error = error {
        print("User notification authorization error: \(error.localizedDescription)")
      }
    }
    center.getNotificationSettings { settings in
      if (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional) && settings.alertSetting == .enabled {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Qiwo", comment: "")
        if let msgText = msgText {
          content.subtitle = msgText
        }
        content.interruptionLevel = .active
        let request = UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: nil)
        center.add(request) { error in
          if let error = error {
            print("User notification request error: \(error.localizedDescription)")
          }
        }
      }
    }
  }

  func setupRime() {
    createDirIfNotExist(path: QiwoApp.userDir)
    createDirIfNotExist(path: QiwoApp.logDir)
    initializeBundledFrostIfNeeded()
    // swiftlint:disable identifier_name
    let notification_handler: @convention(c) (UnsafeMutableRawPointer?, RimeSessionId, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void = notificationHandler
    let context_object = Unmanaged.passUnretained(self).toOpaque()
    // swiftlint:enable identifier_name
    rimeAPI.set_notification_handler(notification_handler, context_object)

    var qiwoTraits = RimeTraits.rimeStructInit()
    qiwoTraits.setCString(Bundle.main.sharedSupportPath!, to: \.shared_data_dir)
    qiwoTraits.setCString(QiwoApp.userDir.path(), to: \.user_data_dir)
    qiwoTraits.setCString(QiwoApp.logDir.path(), to: \.log_dir)
    qiwoTraits.setCString("Qiwo", to: \.distribution_code_name)
    qiwoTraits.setCString("齐我输入法", to: \.distribution_name)
    qiwoTraits.setCString(Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String, to: \.distribution_version)
    qiwoTraits.setCString("rime.qiwo", to: \.app_name)
    rimeAPI.setup(&qiwoTraits)
  }

  func initializeBundledFrostIfNeeded() {
    guard let sharedSupportPath = Bundle.main.sharedSupportPath else {
      return
    }

    let fileManager = FileManager.default
    let bundledFrostDir = URL(fileURLWithPath: sharedSupportPath, isDirectory: true)
      .appendingPathComponent("rime-frost", isDirectory: true)
    let bundledSchema = bundledFrostDir.appendingPathComponent("rime_frost.schema.yaml")
    guard fileManager.fileExists(atPath: bundledSchema.path()) else {
      return
    }

    let userSchema = QiwoApp.userDir.appendingPathComponent("rime_frost.schema.yaml")
    if !fileManager.fileExists(atPath: userSchema.path()) {
      copyBundledFrostResources(from: bundledFrostDir, to: QiwoApp.userDir)
    }
    ensureDefaultFrostCustomYaml()
    ensureFrostSchemaCustomYamls(from: bundledFrostDir)
  }

  func startRime(fullCheck: Bool) {
    print("Initializing la rime...")
    rimeAPI.initialize(nil)
    // check for configuration updates
    if rimeAPI.start_maintenance(fullCheck) {
      // update squirrel config
      // print("[DEBUG] maintenance suceeds")
      _ = rimeAPI.deploy_config_file("squirrel.yaml", "config_version")
    } else {
      // print("[DEBUG] maintenance fails")
    }
  }

  func loadSettings() {
    config = QiwoConfig()
    if !config!.openBaseConfig() {
      return
    }

    enableNotifications = config!.getString("show_notifications_when") != "never"
    if let panel = panel, let config = self.config {
      panel.load(config: config, forDarkMode: false)
      panel.load(config: config, forDarkMode: true)
    }
  }

  func loadSettings(for schemaID: String) {
    if schemaID.count == 0 || schemaID.first == "." {
      return
    }
    let schema = QiwoConfig()
    if let panel = panel, let config = self.config {
      if schema.open(schemaID: schemaID, baseConfig: config) && schema.has(section: "style") {
        panel.load(config: schema, forDarkMode: false)
        panel.load(config: schema, forDarkMode: true)
      } else {
        panel.load(config: config, forDarkMode: false)
        panel.load(config: config, forDarkMode: true)
      }
    }
    schema.close()
  }

  // prevent freezing the system
  func problematicLaunchDetected() -> Bool {
    var detected = false
    let logFile = FileManager.default.temporaryDirectory.appendingPathComponent("squirrel_launch.json", conformingTo: .json)
    // print("[DEBUG] archive: \(logFile)")
    do {
      let archive = try Data(contentsOf: logFile, options: [.uncached])
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .millisecondsSince1970
      let previousLaunch = try decoder.decode(Date.self, from: archive)
      if previousLaunch.timeIntervalSinceNow >= -2 {
        detected = true
      }
    } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {

    } catch {
      print("Error occurred during processing launch time archive: \(error.localizedDescription)")
      return detected
    }
    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .millisecondsSince1970
      let record = try encoder.encode(Date.now)
      try record.write(to: logFile)
    } catch {
      print("Error occurred during saving launch time to archive: \(error.localizedDescription)")
    }
    return detected
  }

  // add an awakeFromNib item so that we can set the action method.  Note that
  // any menuItems without an action will be disabled when displayed in the Text
  // Input Menu.
  func addObservers() {
    let center = NSWorkspace.shared.notificationCenter
    center.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: nil, using: workspaceWillPowerOff)

    let notifCenter = DistributedNotificationCenter.default()
    notifCenter.addObserver(forName: .init("QiwoReloadNotification"), object: nil, queue: nil, using: rimeNeedsReload)
    notifCenter.addObserver(forName: .init("QiwoSyncNotification"), object: nil, queue: nil, using: rimeNeedsSync)
    notifCenter.addObserver(forName: .init("QiwoWebDavSyncNotification"), object: nil, queue: nil, using: webDavSyncRequested)
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    print("Qiwo is quitting.")
    rimeAPI.cleanup_all_sessions()
    return .terminateNow
  }

}

private func notificationHandler(contextObject: UnsafeMutableRawPointer?, sessionId: RimeSessionId, messageTypeC: UnsafePointer<CChar>?, messageValueC: UnsafePointer<CChar>?) {
  let delegate: QiwoApplicationDelegate = Unmanaged<QiwoApplicationDelegate>.fromOpaque(contextObject!).takeUnretainedValue()

  let messageType = messageTypeC.map { String(cString: $0) }
  let messageValue = messageValueC.map { String(cString: $0) }
  if messageType == "deploy" {
    switch messageValue {
    case "start":
      QiwoApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_start", comment: ""))
    case "success":
      QiwoApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_success", comment: ""))
    case "failure":
      QiwoApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_failure", comment: ""))
    default:
      break
    }
    return
  }
  // off
  if !delegate.enableNotifications {
    return
  }

  if messageType == "schema", let messageValue = messageValue, let schemaName = try? /^[^\/]*\/(.*)$/.firstMatch(in: messageValue)?.output.1 {
    delegate.showStatusMessage(msgTextLong: String(schemaName), msgTextShort: String(schemaName))
    return
  } else if messageType == "option" {
    let state = messageValue?.first != "!"
    let optionName = if state {
      messageValue
    } else {
      String(messageValue![messageValue!.index(after: messageValue!.startIndex)...])
    }
    if let optionName = optionName {
      optionName.withCString { name in
        let stateLabelLong = delegate.rimeAPI.get_state_label_abbreviated(sessionId, name, state, false)
        let stateLabelShort = delegate.rimeAPI.get_state_label_abbreviated(sessionId, name, state, true)
        let longLabel = stateLabelLong.str.map { String(cString: $0) }
        let shortLabel = stateLabelShort.str.map { String(cString: $0) }
        delegate.showStatusMessage(msgTextLong: longLabel, msgTextShort: shortLabel)
      }
    }
  }
}

private extension QiwoApplicationDelegate {
  func showStatusMessage(msgTextLong: String?, msgTextShort: String?) {
    if !(msgTextLong ?? "").isEmpty || !(msgTextShort ?? "").isEmpty {
      panel?.updateStatus(long: msgTextLong ?? "", short: msgTextShort ?? "")
    }
  }

  func shutdownRime() {
    config?.close()
    rimeAPI.finalize()
  }

  func workspaceWillPowerOff(_: Notification) {
    print("Finalizing before logging out.")
    self.shutdownRime()
  }

  func rimeNeedsReload(_: Notification) {
    print("Reloading rime on demand.")
    self.deploy()
  }

  func rimeNeedsSync(_: Notification) {
    print("Sync rime on demand.")
    self.syncUserData()
  }

  func webDavSyncRequested(_: Notification) {
    print("WebDAV sync on demand.")
    self.qiwoWebDavSync()
  }

  func createDirIfNotExist(path: URL) {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path.path()) {
      do {
        try fileManager.createDirectory(at: path, withIntermediateDirectories: true)
      } catch {
        print("Error creating user data directory: \(path.path())")
      }
    }
  }

  private func copyBundledFrostResources(from bundledFrostDir: URL, to userDir: URL) {
    let fileManager = FileManager.default
    let basePath = bundledFrostDir.path().hasSuffix("/") ?
      bundledFrostDir.path() :
      bundledFrostDir.path() + "/"

    guard let enumerator = fileManager.enumerator(
      at: bundledFrostDir,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else {
      return
    }

    for case let source as URL in enumerator {
      let sourcePath = source.path()
      guard sourcePath.hasPrefix(basePath) else {
        continue
      }

      let relativePath = String(sourcePath.dropFirst(basePath.count))
      if relativePath == ".git" || relativePath.hasPrefix(".git/") {
        continue
      }

      let target = userDir.appendingPathComponent(relativePath)
      do {
        let values = try source.resourceValues(forKeys: [.isDirectoryKey])
        if values.isDirectory == true {
          try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        } else if !fileManager.fileExists(atPath: target.path()) {
          try fileManager.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
          )
          try fileManager.copyItem(at: source, to: target)
        }
      } catch {
        print("Error copying bundled rime-frost resource \(relativePath): \(error.localizedDescription)")
      }
    }
  }

  private func ensureCustomYaml(
    file: URL,
    initialContent: String,
    patchEntries: [String],
    requiredNeedles: [String]
  ) {
    let fileManager = FileManager.default
    let existingContent = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
    let hasContent = fileManager.fileExists(atPath: file.path()) &&
      !existingContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

    if !hasContent {
      do {
        try initialContent.write(to: file, atomically: true, encoding: .utf8)
      } catch {
        print("Error creating \(file.lastPathComponent): \(error.localizedDescription)")
      }
      return
    }

    let missingPatchEntries = zip(requiredNeedles, patchEntries)
      .compactMap { pair in existingContent.contains(pair.0) ? nil : pair.1 }
    guard !missingPatchEntries.isEmpty else {
      return
    }

    let updatedContent = appendYamlPatchEntries(missingPatchEntries, to: existingContent)
    do {
      try updatedContent.write(to: file, atomically: true, encoding: .utf8)
    } catch {
      print("Error updating \(file.lastPathComponent): \(error.localizedDescription)")
    }
  }

  private func appendYamlPatchEntries(_ entries: [String], to content: String) -> String {
    var lines = content.components(separatedBy: "\n")
    if lines.last == "" {
      lines.removeLast()
    }

    guard let patchIndex = lines.firstIndex(where: { $0 == "patch:" }) else {
      var output = content
      if !output.hasSuffix("\n") {
        output += "\n"
      }
      if !output.isEmpty {
        output += "\n"
      }
      output += "patch:\n"
      output += entries.joined(separator: "\n")
      output += "\n"
      return output
    }

    let insertionIndex = lines[(patchIndex + 1)...].firstIndex { line in
      !line.isEmpty &&
        !line.hasPrefix(" ") &&
        !line.hasPrefix("\t") &&
        !line.hasPrefix("#")
    } ?? lines.endIndex

    lines.insert(contentsOf: entries, at: insertionIndex)
    return lines.joined(separator: "\n") + "\n"
  }

  private func ensureDefaultFrostCustomYaml() {
    let file = QiwoApp.userDir.appendingPathComponent("default.custom.yaml")
    let initialContent = """
    patch:
      schema_list:
        - schema: rime_frost
      switcher/hotkeys/@next: F4
      switcher/save_options/@next: auto_commit_spacing
    """
    ensureCustomYaml(
      file: file,
      initialContent: initialContent,
      patchEntries: [
        "  switcher/hotkeys/@next: F4",
        "  switcher/save_options/@next: auto_commit_spacing"
      ],
      requiredNeedles: [
        "switcher/hotkeys/@next: F4",
        "switcher/save_options/@next: auto_commit_spacing"
      ]
    )
  }

  private func ensureFrostSchemaCustomYamls(from bundledFrostDir: URL) {
    let fileManager = FileManager.default
    guard let entries = try? fileManager.contentsOfDirectory(
      at: bundledFrostDir,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      return
    }

    let initialContent = """
    patch:
      switches/@next:
        name: auto_commit_spacing
        states: [ 关闭中英数字自动空格, 开启中英数字自动空格 ]
    """
    let patchEntry = """
      switches/@next:
        name: auto_commit_spacing
        states: [ 关闭中英数字自动空格, 开启中英数字自动空格 ]
    """

    for entry in entries {
      let fileName = entry.lastPathComponent
      guard fileName.hasPrefix("rime_frost"),
            fileName.hasSuffix(".schema.yaml") else {
        continue
      }

      let schemaID = String(fileName.dropLast(".schema.yaml".count))
      let customFile = QiwoApp.userDir.appendingPathComponent("\(schemaID).custom.yaml")
      ensureCustomYaml(
        file: customFile,
        initialContent: initialContent,
        patchEntries: [patchEntry],
        requiredNeedles: ["auto_commit_spacing"]
      )
    }
  }
}

extension NSApplication {
  var qiwoAppDelegate: QiwoApplicationDelegate {
    self.delegate as! QiwoApplicationDelegate
  }
}
