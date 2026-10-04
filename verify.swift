// Verifies the power-assertion mechanism StayAwake relies on.
// Builds, holds an assertion, and confirms macOS actually reports it.
import Foundation
import IOKit.pwr_mgt

func pmset(_ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    p.arguments = ["-g", "assertions"]
    let pipe = Pipe()
    p.standardOutput = pipe
    try! p.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}

func hold(_ type: String, _ reason: String) -> IOPMAssertionID {
    var id: IOPMAssertionID = 0
    let s = IOPMAssertionCreateWithName(
        type as CFString,
        IOPMAssertionLevel(kIOPMAssertionLevelOn),
        reason as CFString,
        &id
    )
    print("  create \(type) -> status=\(s) id=\(id)")
    return id
}

// pmset pads counters with runs of spaces, e.g.
// "...PreventUserIdleSystemSleep.....1". Match the last two whitespace-separated
// tokens so column widths don't matter.
func counter(_ out: String, _ name: String, is value: Int) -> Bool {
    for line in out.split(separator: "\n") {
        let tokens = line.split(whereSeparator: { $0 == " " }).map(String.init)
        guard tokens.count >= 2, tokens[tokens.count - 2] == name else { continue }
        return tokens[tokens.count - 1] == String(value)
    }
    return false
}

func named(_ text: String, in out: String) -> Bool { out.contains(text) }

print("1. baseline (nothing held by us)")
let before = pmset([])
print("   baseline mentions test marker: \(named("STAYAWAKE-VERIFY", in: before))")

print("2. hold display + system assertions")
// Same constant names the app uses in StayAwakeApp.swift.
let d = hold(kIOPMAssertionTypePreventUserIdleDisplaySleep as String, "STAYAWAKE-VERIFY display")
let sy = hold(kIOPMAssertionTypePreventUserIdleSystemSleep as String, "STAYAWAKE-VERIFY system")

print("3. re-read assertions while held")
let during = pmset([])
print("   marker visible: \(named("STAYAWAKE-VERIFY", in: during))")
// Note: a display-preventing assertion is reported by macOS as
// InternalPreventDisplaySleep, not PreventUserIdleDisplaySleep.
print("   InternalPreventDisplaySleep  == 1: \(counter(during, "InternalPreventDisplaySleep", is: 1))")
print("   PreventUserIdleSystemSleep  == 1: \(counter(during, "PreventUserIdleSystemSleep", is: 1))")

print("4. release display assertion only")
IOPMAssertionRelease(d)
Thread.sleep(forTimeInterval: 0.5)
let mid = pmset([])
print("   system still prevented: \(counter(mid, "PreventUserIdleSystemSleep", is: 1))")
print("   display no longer prevented: \(!counter(mid, "InternalPreventDisplaySleep", is: 1))")

print("5. release the rest")
IOPMAssertionRelease(sy)
Thread.sleep(forTimeInterval: 1)
let after = pmset([])
print("   marker gone: \(!named("STAYAWAKE-VERIFY", in: after))")

let pass = named("STAYAWAKE-VERIFY", in: during)
    && !named("STAYAWAKE-VERIFY", in: after)
    && counter(during, "PreventUserIdleSystemSleep", is: 1)
    && counter(during, "InternalPreventDisplaySleep", is: 1)
print(pass ? "\nRESULT: PASS — mechanism works" : "\nRESULT: FAIL")
exit(pass ? 0 : 1)