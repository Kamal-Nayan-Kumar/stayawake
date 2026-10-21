import AppKit
import ServiceManagement

/// Wraps `SMAppService` so the app can register itself as a login item.
///
/// macOS keeps the registration, so the toggle in the menu stays honest
/// across restarts instead of reflecting only what this process did.
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
            lastError = nil
        } catch {
            lastError = Self.message(for: SMAppService.mainApp.status)
            NSLog("StayAwake: launch at login failed: \(error.localizedDescription)")
        }
    }

    /// macOS reports login item failures as opaque errors, so use the service
    /// status after the failure to work out what actually went wrong.
    private static func message(for status: SMAppService.Status) -> String {
        switch status {
        case .requiresApproval:
            return "macOS needs your approval. Enable StayAwake in System Settings › General › Login Items."
        case .notRegistered, .notFound:
            return "Could not register the login item. Move StayAwake to /Applications and try again."
        default:
            return "Could not update the login item."
        }
    }
}
