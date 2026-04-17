import AppKit
import Carbon
import Foundation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "io.local.openpaste", category: "app")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let formatter = ClipboardFormatter()
  private let clipboardService = ClipboardService()

  private var statusItem: NSStatusItem?
  private var lastResult: CleanResult?
  private var previewWindowController: NSWindowController?
  private weak var previewTextView: NSTextView?
  private var rawWindowController: NSWindowController?
  private weak var rawTextView: NSTextView?

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard !shouldTerminateForDuplicateInstance() else {
      NSApp.terminate(nil)
      return
    }
    NSApp.setActivationPolicy(.accessory)
    configureStatusItem()
    registerGlobalHotKey()
  }

  func applicationWillTerminate(_ notification: Notification) {
    GlobalHotKeyRegistry.shared.unregisterAll()
  }

  private func configureStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.title = "OP"
    item.button?.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
    item.button?.toolTip = "OpenPaste"

    let menu = NSMenu()
    menu.addItem(
      withTitle: "Paste Keeping Structure  (⌃⌥⌘P)",
      action: #selector(handlePasteKeepStructure),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Paste as One Line  (⌃⇧⌥⌘P)",
      action: #selector(handlePasteOneLine),
      keyEquivalent: ""
    )
    menu.addItem(.separator())
    menu.addItem(
      withTitle: "Clean Clipboard (Keep Structure)",
      action: #selector(handleCleanKeepStructure),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Clean Clipboard (One Line)",
      action: #selector(handleCleanOneLine),
      keyEquivalent: ""
    )
    menu.addItem(.separator())
    menu.addItem(
      withTitle: "Show Last Result",
      action: #selector(showLastResult),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Show Raw Clipboard",
      action: #selector(showRawClipboard),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Open Accessibility Settings",
      action: #selector(openAccessibilitySettings),
      keyEquivalent: ""
    )
    menu.addItem(.separator())
    menu.addItem(
      withTitle: "Quit OpenPaste",
      action: #selector(quitApp),
      keyEquivalent: "q"
    )

    menu.items.forEach { $0.target = self }
    item.menu = menu
    statusItem = item
  }

  private func registerGlobalHotKey() {
    let registry = GlobalHotKeyRegistry.shared
    do {
      try registry.register(
        id: 1,
        keyCode: UInt32(kVK_ANSI_P),
        modifiers: UInt32(cmdKey | controlKey)
      ) { [weak self] in
        log.info("hotkey fired: keep-structure")
        Task { @MainActor in
          self?.pasteCleaned(mode: .keepStructure)
        }
      }

      try registry.register(
        id: 2,
        keyCode: UInt32(kVK_ANSI_P),
        modifiers: UInt32(cmdKey | controlKey | shiftKey)
      ) { [weak self] in
        log.info("hotkey fired: one-line")
        Task { @MainActor in
          self?.pasteCleaned(mode: .oneLine)
        }
      }
    } catch {
      log.error("hotkey registration failed: \(String(describing: error))")
      showAlert(
        title: "Hotkey registration failed",
        message: "OpenPaste could not register the global paste shortcut(s).\n\n\(error)"
      )
    }
  }

  @objc private func handlePasteKeepStructure() {
    pasteCleaned(mode: .keepStructure)
  }

  @objc private func handlePasteOneLine() {
    pasteCleaned(mode: .oneLine)
  }

  @objc private func handleCleanKeepStructure() {
    _ = cleanCurrentClipboard(mode: .keepStructure)
  }

  @objc private func handleCleanOneLine() {
    _ = cleanCurrentClipboard(mode: .oneLine)
  }

  private func pasteCleaned(mode: CleaningMode) {
    log.info("pasteCleaned: mode=\(String(describing: mode))")
    guard let result = cleanCurrentClipboard(mode: mode) else {
      log.info("pasteCleaned: no result; aborting")
      return
    }

    let trusted = clipboardService.accessibilityTrusted(prompt: true)
    log.info("pasteCleaned: accessibility trusted=\(trusted)")
    if trusted {
      let didPaste = clipboardService.simulatePaste()
      log.info("pasteCleaned: simulatePaste returned \(didPaste)")
      if !didPaste {
        showAlert(
          title: "Paste simulation failed",
          message: "OpenPaste cleaned your clipboard, but macOS did not allow the synthetic paste event."
        )
      }
      return
    }

    showAlert(
      title: "Accessibility permission required",
      message: """
      OpenPaste cleaned your clipboard and copied the result.

      To paste into the frontmost app automatically, enable Accessibility access for OpenPaste in System Settings.
      """
    )
    lastResult = result
  }

  @discardableResult
  private func cleanCurrentClipboard(mode: CleaningMode) -> CleanResult? {
    guard let payload = clipboardService.readPayload() else {
      showAlert(
        title: "Clipboard is empty",
        message: "Copy some text or HTML first, then try again."
      )
      return nil
    }

    guard let result = formatter.clean(payload: payload, mode: mode) else {
      showAlert(
        title: "Nothing to clean",
        message: "OpenPaste could not find a text or HTML payload in the clipboard."
      )
      return nil
    }

    clipboardService.write(result: result)
    lastResult = result
    refreshPreviewWindowIfNeeded(result)
    return result
  }

  @objc private func showLastResult() {
    guard let result = lastResult else {
      showAlert(
        title: "No cleaned output yet",
        message: "Use the global hotkey or the Clean Clipboard menu item first."
      )
      return
    }

    let controller = ensurePreviewWindow()
    previewTextView?.string = result.previewSummary
    controller.showWindow(nil)
    controller.window?.title = "OpenPaste Last Result"
    NSApp.activate(ignoringOtherApps: true)
  }

  private func ensurePreviewWindow() -> NSWindowController {
    if let previewWindowController {
      return previewWindowController
    }

    let textView = NSTextView(frame: .zero)
    textView.isEditable = false
    textView.isRichText = false
    textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    textView.textColor = .labelColor
    textView.backgroundColor = NSColor.windowBackgroundColor
    textView.string = "OpenPaste has not cleaned anything yet."

    let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 720, height: 520))
    scrollView.hasVerticalScroller = true
    scrollView.documentView = textView

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.center()
    window.contentView = scrollView
    window.title = "OpenPaste Last Result"

    let controller = NSWindowController(window: window)
    previewTextView = textView
    previewWindowController = controller
    return controller
  }

  private func refreshPreviewWindowIfNeeded(_ result: CleanResult) {
    guard previewWindowController?.window?.isVisible == true else {
      return
    }
    previewTextView?.string = result.previewSummary
  }

  @objc private func showRawClipboard() {
    let controller = ensureRawWindow()
    rawTextView?.string = rawClipboardSnapshot()
    controller.showWindow(nil)
    controller.window?.title = "OpenPaste Raw Clipboard"
    NSApp.activate(ignoringOtherApps: true)
  }

  private func rawClipboardSnapshot() -> String {
    let payload = clipboardService.readPayload()
    let plainText = payload?.plainText ?? "<no text/plain>"
    let html = payload?.html ?? "<no text/html>"

    let keepStructure = payload
      .flatMap { formatter.clean(payload: $0, mode: .keepStructure)?.cleanText }
      ?? "<nothing to clean>"
    let oneLine = payload
      .flatMap { formatter.clean(payload: $0, mode: .oneLine)?.cleanText }
      ?? "<nothing to clean>"

    return """
    === text/plain ===
    \(plainText)

    === text/html ===
    \(html)

    === keep-structure dry run ===
    \(keepStructure)

    === one-line dry run ===
    \(oneLine)
    """
  }

  private func ensureRawWindow() -> NSWindowController {
    if let rawWindowController {
      return rawWindowController
    }

    let textView = NSTextView(frame: .zero)
    textView.isEditable = false
    textView.isRichText = false
    textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    textView.textColor = .labelColor
    textView.backgroundColor = NSColor.windowBackgroundColor
    textView.string = "OpenPaste has not inspected the clipboard yet."

    let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 720, height: 520))
    scrollView.hasVerticalScroller = true
    scrollView.documentView = textView

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.center()
    window.contentView = scrollView
    window.title = "OpenPaste Raw Clipboard"

    let controller = NSWindowController(window: window)
    rawTextView = textView
    rawWindowController = controller
    return controller
  }

  @objc private func openAccessibilitySettings() {
    let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    if let url = URL(string: urlString) {
      NSWorkspace.shared.open(url)
    }
  }

  @objc private func quitApp() {
    NSApp.terminate(nil)
  }

  private func shouldTerminateForDuplicateInstance() -> Bool {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
      return false
    }

    let currentPID = ProcessInfo.processInfo.processIdentifier
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    return running.contains { application in
      application.processIdentifier != currentPID
    }
  }

  private func showAlert(title: String, message: String) {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = title
    alert.informativeText = message
    alert.runModal()
  }
}
