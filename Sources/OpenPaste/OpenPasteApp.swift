import SwiftUI

@main
struct OpenPasteApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      VStack(alignment: .leading, spacing: 12) {
        Text("OpenPaste")
          .font(.title2.bold())
        Text("Menu bar clipboard cleaner")
          .foregroundStyle(.secondary)
        Divider()
        Text("Global shortcut: Control+Command+P (Shift for one-line)")
        Text("Use the menu bar item to clean the clipboard without pasting.")
        Text("Automatic paste requires Accessibility permission in System Settings.")
          .foregroundStyle(.secondary)
      }
      .padding(20)
      .frame(width: 360)
    }
  }
}
