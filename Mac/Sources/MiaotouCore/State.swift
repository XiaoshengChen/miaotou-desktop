import Foundation

public enum AppLanguage: String, Codable, CaseIterable {
    case en, zh
    public func text(_ en: String, _ zh: String) -> String { self == .zh ? zh : en }
}
public struct Thing: Codable, Identifiable, Equatable {
    public var id: UUID
    public var text: String
    public var createdAt: Date
    public init(text: String, now: Date = .now) { id = UUID(); self.text = text; createdAt = now }
}
public struct PastThing: Codable, Identifiable, Equatable {
    public var id: UUID
    public var text: String
    public var date: Date
    public var completed: Bool
}
public struct ThingState: Codable, Equatable {
    public var schema = 1
    public var active: Thing?
    public var history: [PastThing] = []
    public var language = AppLanguage.en
    public var companionEnabled = true
    public var guidanceDismissed = true
    public var generatedTips: [String: String] = [:]
    public var completedCount: Int { history.filter(\.completed).count }
    public init() {}
    public mutating func save(_ input: String, now: Date = .now) throws {
        let text = TextBudget.normalize(input)
        guard TextBudget.valid(text) else { throw StoreError.invalidText }
        if let old = active { history.insert(PastThing(id: old.id, text: old.text, date: now, completed: false), at: 0) }
        active = Thing(text: text, now: now); generatedTips = [:]
    }
    public mutating func complete(now: Date = .now) -> Thing? {
        guard let old = active else { return nil }
        history.insert(PastThing(id: old.id, text: old.text, date: now, completed: true), at: 0)
        active = nil; generatedTips = [:]; return old
    }
}
public enum StoreError: Error { case invalidText, unsupportedSchema }
public enum TextBudget {
    public static func normalize(_ text: String) -> String { text.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
    public static func limit(_ text: String) -> Int {
        text.unicodeScalars.contains { s in
            (0x2E80...0x9FFF).contains(s.value) || (0xAC00...0xD7AF).contains(s.value) || (0xF900...0xFAFF).contains(s.value)
            || (0xFF00...0xFFEF).contains(s.value) || (0x20000...0x3134F).contains(s.value) || s.properties.isEmojiPresentation
        } ? 16 : 36
    }
    public static func valid(_ text: String) -> Bool { !text.isEmpty && text.count <= limit(text) }
    public static func tipFits(_ text: String) -> Bool { !text.isEmpty && !text.contains("\n") && text.count <= (limit(text) == 16 ? 18 : 38) }
}
public struct DesktopPreferences: Codable, Equatable {
    public var pinned = false
    public var collapsed = false
    public var x: Double?
    public var y: Double?
    public init() {}
}
public struct DesktopDocument: Codable, Equatable {
    public var version = 1
    public var state = ThingState()
    public var preferences = DesktopPreferences()
    public init() {}
}
public struct DesktopDisk {
    public let directory: URL
    public var file: URL { directory.appendingPathComponent("desktop-v1.json") }
    public init(directory: URL) { self.directory = directory }
    public func load() throws -> DesktopDocument {
        guard FileManager.default.fileExists(atPath: file.path) else { return DesktopDocument() }
        let value = try JSONDecoder().decode(DesktopDocument.self, from: Data(contentsOf: file))
        guard value.version == 1, value.state.schema == 1 else { throw StoreError.unsupportedSchema }
        return value
    }
    public func write(_ value: DesktopDocument) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: file, options: .atomic)
    }
}
