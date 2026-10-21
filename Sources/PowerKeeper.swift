import AppKit
import IOKit.pwr_mgt

/// Holds the power assertions that keep this Mac awake.
///
/// Two separate assertions are involved:
///
/// - `kIOPMAssertionTypePreventUserIdleSystemSleep` stops macOS from putting
///   the machine to sleep. Running jobs keep going.
/// - `kIOPMAssertionTypePreventUserIdleDisplaySleep` stops macOS from turning
///   the screen off. It is only held while the screen should stay lit.
///
/// Dropping the second one is how you get "Mac awake, screen off": the
/// machine stays up, but the display is free to sleep on its own.
///
/// Both assertions belong to this process. Quit the app and macOS resumes
/// normal sleep immediately, so there is never a stale setting left behind
/// and nothing to undo later.
@MainActor
final class PowerKeeper: ObservableObject {
    @Published var stayAwake: Bool {
        didSet {
            Settings.stayAwake = stayAwake
            apply()
        }
    }

    @Published var allowDisplaySleep: Bool {
        didSet {
            Settings.allowDisplaySleep = allowDisplaySleep
            apply()
        }
    }

    @Published private(set) var lastError: String?

    private var systemAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0

    init() {
        stayAwake = Settings.stayAwake
        allowDisplaySleep = Settings.allowDisplaySleep
        apply()
    }

    /// Drops the current assertions and creates the ones the current settings
    /// call for.
    ///
    /// Always release-then-recreate rather than toggling in place. It keeps
    /// the assertion set exactly in sync with the two toggles, so there is no
    /// path where the Mac is held awake by an assertion nobody asked for.
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
            if displayAssertion == 0 {
                lastError = "The screen could not be held on. The Mac itself is still protected."
            }
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
        guard status == kIOReturnSuccess else {
            NSLog("StayAwake: could not create \(type): status \(status)")
            return 0
        }
        return id
    }

    private func release(_ id: inout IOPMAssertionID) {
        guard id != 0 else { return }
        IOPMAssertionRelease(id)
        id = 0
    }

    /// SF Symbol shown in the menu bar.
    ///
    /// The mark tells you what the Mac is doing right now: a sleeping moon
    /// when it sleeps, a sun when everything is held on, and a coffee cup when
    /// the Mac is running but the screen is free to rest.
    var symbolName: String {
        if stayAwake {
            return allowDisplaySleep ? "cup.and.saucer.fill" : "sun.max.fill"
        }
        return "moon.zzz.fill"
    }

    /// One line describing what the Mac is doing right now.
    var statusText: String {
        if stayAwake {
            return allowDisplaySleep ? "Mac awake · screen may sleep" : "Mac awake · screen stays on"
        }
        return "Sleep normally"
    }
}
