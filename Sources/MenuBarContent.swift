import SwiftUI

/// The menu that drops down from the menu bar icon.
struct MenuBarContent: View {
    @ObservedObject var keeper: PowerKeeper
    @ObservedObject var login: LaunchAtLogin

    var body: some View {
        Toggle("Stay Awake", isOn: $keeper.stayAwake)
        Toggle("Allow Screen to Sleep", isOn: $keeper.allowDisplaySleep)
            .disabled(!keeper.stayAwake)

        if let error = keeper.lastError {
            Text(error).foregroundStyle(.red)
        } else {
            Text(keeper.statusText).foregroundStyle(.secondary)
        }

        if let error = login.lastError {
            Text(error).foregroundStyle(.red)
        }

        Divider()

        Toggle("Launch at Login", isOn: Binding(get: { login.enabled }, set: { _ in login.toggle() }))
        Button("Quit StayAwake") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
