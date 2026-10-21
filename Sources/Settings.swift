import Foundation

/// Menu state that survives a relaunch.
///
/// The app remembers how you left it. Without this, quitting and reopening
/// StayAwake (or a reboot, or a crash) would drop the Mac back to normal
/// sleep, and anything you had running overnight would go with it.
enum Settings {
    private enum Key {
        static let stayAwake = "com.nayan.stayawake.stayAwake"
        static let allowDisplaySleep = "com.nayan.stayawake.allowDisplaySleep"
    }

    /// Whether the Mac is being held awake.
    static var stayAwake: Bool {
        get { UserDefaults.standard.bool(forKey: Key.stayAwake) }
        set { UserDefaults.standard.set(newValue, forKey: Key.stayAwake) }
    }

    /// Whether the display is allowed to sleep while the Mac stays awake.
    ///
    /// This is stored separately from `stayAwake` on purpose. It is the
    /// setting most people change right before leaving, so it should survive
    /// a restart of the app and should not be reset just because the main
    /// toggle was flipped off and on again.
    static var allowDisplaySleep: Bool {
        get { UserDefaults.standard.bool(forKey: Key.allowDisplaySleep) }
        set { UserDefaults.standard.set(newValue, forKey: Key.allowDisplaySleep) }
    }
}
