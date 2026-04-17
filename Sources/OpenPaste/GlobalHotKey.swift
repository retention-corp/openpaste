import Carbon
import Foundation
import OSLog

enum GlobalHotKeyError: Error {
  case handlerInstall(OSStatus)
  case registration(OSStatus)
}

final class GlobalHotKeyRegistry: @unchecked Sendable {
  static let shared = GlobalHotKeyRegistry()

  private let log = Logger(subsystem: "io.local.openpaste", category: "hotkey")
  private let signature = GlobalHotKeyRegistry.fourCharCode("OPst")
  private var handlerRef: EventHandlerRef?
  private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
  private var callbacks: [UInt32: () -> Void] = [:]

  private init() {}

  func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) throws {
    try ensureHandlerInstalled()

    if let existing = hotKeyRefs.removeValue(forKey: id) {
      UnregisterEventHotKey(existing)
    }

    var ref: EventHotKeyRef?
    let status = RegisterEventHotKey(
      keyCode,
      modifiers,
      EventHotKeyID(signature: signature, id: id),
      GetApplicationEventTarget(),
      0,
      &ref
    )

    guard status == noErr, let ref else {
      throw GlobalHotKeyError.registration(status)
    }

    hotKeyRefs[id] = ref
    callbacks[id] = callback
    log.info("registered hotkey id=\(id) keyCode=\(keyCode) modifiers=\(modifiers)")
  }

  func unregisterAll() {
    for (_, ref) in hotKeyRefs {
      UnregisterEventHotKey(ref)
    }
    hotKeyRefs.removeAll()
    callbacks.removeAll()
  }

  fileprivate func dispatch(id: UInt32) {
    log.info("hotkey dispatched: id=\(id)")
    callbacks[id]?()
  }

  private func ensureHandlerInstalled() throws {
    if handlerRef != nil { return }

    var eventSpec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )

    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, eventRef, _ in
        guard let eventRef else { return noErr }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
          eventRef,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &hotKeyID
        )
        guard status == noErr else { return noErr }
        GlobalHotKeyRegistry.shared.dispatch(id: hotKeyID.id)
        return noErr
      },
      1,
      &eventSpec,
      nil,
      &handlerRef
    )

    if status != noErr {
      throw GlobalHotKeyError.handlerInstall(status)
    }
    log.info("installed global hotkey event handler")
  }

  private static func fourCharCode(_ value: String) -> OSType {
    value.utf8.reduce(0) { result, scalar in
      (result << 8) + OSType(scalar)
    }
  }
}
