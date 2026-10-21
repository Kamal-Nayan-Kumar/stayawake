import SwiftUI

@main
struct StayAwakeApp: App {
    @StateObject private var keeper = PowerKeeper()
    @StateObject private var login = LaunchAtLogin()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(keeper: keeper, login: login)
        } label: {
            Label("StayAwake", systemImage: keeper.symbolName)
        }
        .menuBarExtraStyle(.menu)
    }
}
