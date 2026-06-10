//
//  QiwoInputFormatter.swift
//  Qiwo
//

import Foundation

enum QiwoInputFormatter {
  static func formatCommitText(_ commitText: String,
                               beforeCursor: String? = nil,
                               afterCursor: String? = nil,
                               enabled: Bool = true) -> String {
    var options = QiwoInputFormatOptions()
    options.auto_spacing_enabled = enabled

    let result = commitText.withCString { commitPointer in
      withOptionalCString(beforeCursor) { beforePointer in
        withOptionalCString(afterCursor) { afterPointer in
          qiwo_input_format_commit_text(commitPointer, beforePointer, afterPointer, options)
        }
      }
    }

    guard let result else {
      return commitText
    }
    defer {
      qiwo_input_format_free_string(result)
    }
    return String(cString: result)
  }

  private static func withOptionalCString<T>(_ value: String?, _ body: (UnsafePointer<CChar>?) -> T) -> T {
    guard let value else {
      return body(nil)
    }
    return value.withCString { pointer in
      body(pointer)
    }
  }
}
