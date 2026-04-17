import AppKit
import ApplicationServices
import Foundation

final class ClipboardService {
  private let pasteboard = NSPasteboard.general

  func readPayload() -> ClipboardPayload? {
    let plainText = pasteboard.string(forType: .string)

    var htmlString: String?
    if let htmlData = pasteboard.data(forType: .html) {
      htmlString = String(data: htmlData, encoding: .utf8)
    } else {
      htmlString = pasteboard.string(forType: .html)
    }

    guard plainText != nil || htmlString != nil else {
      return nil
    }

    return ClipboardPayload(plainText: plainText, html: htmlString)
  }

  func write(result: CleanResult) {
    pasteboard.clearContents()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(result.cleanText, forType: .string)
  }

  func accessibilityTrusted(prompt: Bool) -> Bool {
    let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  func simulatePaste() -> Bool {
    guard accessibilityTrusted(prompt: false) else {
      return false
    }

    guard
      let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true),
      let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
    else {
      return false
    }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand

    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
    return true
  }
}
