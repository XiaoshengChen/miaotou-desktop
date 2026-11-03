import XCTest
@testable import MiaotouCore

final class StateTests: XCTestCase {
    func testReplaceAndCompleteAreTransactional() throws {
        var state = ThingState(); try state.save("Launch my first website")
        let old = state.active!
        XCTAssertThrowsError(try state.save(String(repeating: "字", count: 17)))
        XCTAssertEqual(state.active, old); XCTAssertTrue(state.history.isEmpty)
        try state.save("Write my first essay")
        XCTAssertEqual(state.history.count, 1); XCTAssertFalse(state.history[0].completed)
        XCTAssertNotNil(state.complete()); XCTAssertNil(state.complete())
        XCTAssertEqual(state.history.count, 2); XCTAssertEqual(state.completedCount, 1)
    }
    func testGraphemesAndMixedBudget() {
        XCTAssertEqual("👨‍👩‍👧‍👦".count, 1)
        XCTAssertEqual(TextBudget.limit("Build an app"), 36)
        XCTAssertEqual(TextBudget.limit("做个 app"), 16)
        XCTAssertTrue(TextBudget.valid(String(repeating: "a", count: 36)))
        XCTAssertFalse(TextBudget.valid(String(repeating: "a", count: 37)))
    }
    func testDiskRoundTripAndCorruptionNeverOverwrites() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let disk = DesktopDisk(directory: folder)
        var doc = DesktopDocument(); try doc.state.save("Build my first app"); doc.preferences.pinned = true; doc.preferences.x = 250
        try disk.write(doc); XCTAssertEqual(try disk.load(), doc)
        try Data("broken".utf8).write(to: disk.file)
        XCTAssertThrowsError(try disk.load()); XCTAssertEqual(try String(contentsOf: disk.file), "broken")
    }
    func testDailyFallbackIsStableAndChangesAtMidnight() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_793_664_000)
        var state = ThingState(); state.language = .zh; try state.save("上线我的第一个网站", now: start)
        let first = TipLibrary.line(for: state, at: start, calendar: calendar)
        XCTAssertEqual(first, TipLibrary.line(for: state, at: start.addingTimeInterval(100), calendar: calendar))
        XCTAssertNotEqual(first, TipLibrary.line(for: state, at: start.addingTimeInterval(86400), calendar: calendar))
        state.generatedTips[TipLibrary.dayKey(start, calendar: calendar)] = "把链接发给一位朋友试试。"
        XCTAssertEqual(TipLibrary.line(for: state, at: start, calendar: calendar), "把链接发给一位朋友试试。")
    }
    func testUnknownVersionIsRejected() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let disk = DesktopDisk(directory: folder); var doc = DesktopDocument(); doc.version = 99
        try disk.write(doc); XCTAssertThrowsError(try disk.load())
    }
}
