// Verifies the power-assertion mechanism StayAwake relies on.
//
// Takes the same two assertions the app takes, checks that macOS reports them
// back by name, then releases them and checks that they go away.
//
// Build and run from the repo root:
//   swiftc -O -o verify Tools/verify.swift && ./verify
//
// Expected last line:
//   RESULT: PASS - mechanism works

import Foundation
import IOKit.pwr_mgt

/// Every assertion this script takes is named with this prefix, so the
/// verifier can find its own assertions in the output and ignore the ones
/// macOS and other apps hold.
let marker = "STAYAWAKE-VERIFY"

let displayType = kIOPMAssertionTypePreventUserIdleDisplaySleep as String
let systemType = kIOPMAssertionTypePreventUserIdleSystemSleep as String

func pmsetAssertions() -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["-g", "assertions"]
    let pipe = Pipe()
    process.standardOutput = pipe
    try! process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}

/// True when a process holds an assertion of `type` carrying `marker`.
///
/// This looks at the "Listed by owning process" section rather than the
/// summary counters at the top, because those counters are shared with every
/// other assertion on the machine. A Mac with the screen on already has
/// assertions we did not take.
func holds(_ output: String, type: String, marker: String) -> Bool {
    output.split(separator: "\n").contains { line in
        line.contains(marker) && line.contains(type)
    }
}

/// True when any assertion carrying `marker` is listed at all.
func listed(_ output: String, marker: String) -> Bool {
    output.contains(marker)
}

/// Reads a counter such as `PreventUserIdleSystemSleep` out of the summary
/// block pmset prints at the top.
///
/// The line looks like "   PreventUserIdleSystemSleep     1". The counter is
/// padded with runs of spaces, so match on the last two tokens rather than
/// on column positions.
///
/// These are flags, not counts. A Mac with the screen on already reports
/// `PreventUserIdleSystemSleep` as 1 because powerd holds one of its own, so
/// treat them as "something is holding this" rather than "how many".
func counter(_ output: String, _ name: String) -> Int? {
    for line in output.split(separator: "\n") {
        let tokens = line
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map(String.init)
        guard tokens.count >= 2, tokens[tokens.count - 2] == name else { continue }
        return Int(tokens[tokens.count - 1])
    }
    return nil
}

func hold(_ type: String, _ reason: String) -> IOPMAssertionID {
    var id: IOPMAssertionID = 0
    let status = IOPMAssertionCreateWithName(
        type as CFString,
        IOPMAssertionLevel(kIOPMAssertionLevelOn),
        reason as CFString,
        &id
    )
    print("   create \(type) -> status=\(status) id=\(id)")
    return id
}

var failures: [String] = []

func check(_ label: String, _ passed: Bool) {
    print("   \(passed ? "ok  " : "FAIL") \(label)")
    if !passed { failures.append(label) }
}

print("1. baseline, nothing held by us")
let before = pmsetAssertions()
let baseSystem = counter(before, "PreventUserIdleSystemSleep")
let baseDisplay = counter(before, "PreventUserIdleDisplaySleep")
print("   PreventUserIdleSystemSleep  = \(baseSystem.map(String.init) ?? "unknown")")
print("   PreventUserIdleDisplaySleep = \(baseDisplay.map(String.init) ?? "unknown")")
check("no assertion of ours is listed", !listed(before, marker: marker))

print("2. hold the display and system assertions")
let display = hold(displayType, "\(marker) display")
let system = hold(systemType, "\(marker) system")

print("3. macOS reports both back")
let during = pmsetAssertions()
check("our display assertion is listed as \(displayType)",
      holds(during, type: displayType, marker: "\(marker) display"))
check("our system assertion is listed as \(systemType)",
      holds(during, type: systemType, marker: "\(marker) system"))
check("the display sleep counter is up",
      (counter(during, "PreventUserIdleDisplaySleep") ?? 0) >= 1)
check("the system sleep counter is up",
      (counter(during, "PreventUserIdleSystemSleep") ?? 0) >= 1)

print("4. release the display assertion only")
IOPMAssertionRelease(display)
Thread.sleep(forTimeInterval: 0.5)
let mid = pmsetAssertions()
check("the display assertion is gone",
      !holds(mid, type: displayType, marker: "\(marker) display"))
check("the system assertion is still held",
      holds(mid, type: systemType, marker: "\(marker) system"))
check("the system sleep counter is still up",
      (counter(mid, "PreventUserIdleSystemSleep") ?? 0) >= 1)

print("5. release the system assertion")
IOPMAssertionRelease(system)
Thread.sleep(forTimeInterval: 1)
let after = pmsetAssertions()
check("none of our assertions are left", !listed(after, marker: marker))
check("the display sleep counter is back to where it started",
      counter(after, "PreventUserIdleDisplaySleep") == baseDisplay)
check("the system sleep counter is back to where it started",
      counter(after, "PreventUserIdleSystemSleep") == baseSystem)

if failures.isEmpty {
    print("\nRESULT: PASS - mechanism works")
    exit(0)
}

print("\nRESULT: FAIL - \(failures.joined(separator: ", "))")
exit(1)
