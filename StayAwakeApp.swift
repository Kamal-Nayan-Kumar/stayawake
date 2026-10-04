import AppKit
import IOKit.pwr_mgt
import ServiceManagement
import SwiftUI

@MainActor
final class PowerKeeper: ObservableObject {
    @Published var stayAwake = false {
        didSet { apply() }
    }

    @Published var allowDisplaySleep = false {
        didSet { apply() }
    }

    @Published private(set) var lastError: String?

    private var systemAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0

    func apply() {
        release(&systemAssertion)
        release(&displayAssertion)
        lastError = nil
        guard stayAwake else { return }

        if !allowDisplaySleep {
            displayAssertion = create(
                kIOPMAssertionTypePreventUserIdleDisplaySleep,
                reason: "StayAwake keeps the screen on while you work"
            )
        }

        systemAssertion = create(
            kIOPMAssertionTypePreventUserIdleSystemSleep,
            reason: "StayAwake keeps this Mac awake while you work"
        )

        if systemAssertion == 0 {
            lastError = "Could not prevent sleep. Check Privacy & Security permissions."
        }
    }

    private func create(_ type: String, reason: String) -> IOPMAssertionID {
        var id: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
        return status == kIOReturnSuccess ? id : 0
    }

    private func release(_ id: inout IOPMAssertionID) {
        guard id != 0 else { return }
        IOPMAssertionRelease(id)
        id = 0
    }

    var symbolName: String {
        if stayAwake {
            return allowDisplaySleep ? "cup.and.saucer.fill" : "moon.zzz.fill"
        }
        return "cup.and.saucer"
    }

    var statusText: String {
        if stayAwake {
            return allowDisplaySleep ? "Mac awake · screen may sleep" : "Mac and screen stay awake"
        }
        return "Sleep normally"
    }
}

@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published var enabled: Bool
    @Published private(set) var lastError: String?

    init() {
        enabled = SMAppService.mainApp.status == .enabled
    }

    func toggle() {
        do {
            if enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            enabled = SMAppService.mainApp.status == .enabled
        } catch {
            lastError = error.localizedDescription
            NSLog("StayAwake: launch at login failed: \(error.localizedDescription)")
        }
    }
}

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

private struct MenuBarContent: View {
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

        Divider()
        Toggle("Launch at Login", isOn: Binding(get: { login.enabled }, set: { _ in login.toggle() }))
        Button("Quit StayAwake") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}