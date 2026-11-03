import AppKit
import SwiftUI
import MiaotouCore

/// Offscreen native rendering and model integration checks. No OS UI automation.
@MainActor enum RenderQA {
    static func run(to folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        func require(_ condition: @autoclosure () -> Bool) throws { if !condition() { throw StoreError.invalidText } }
        let model = DesktopModel()
        model.setLanguage(.zh)
        if model.state.active == nil { model.draft = "上线我的第一个网站"; model.save() }
        func render(_ name: String, height: CGFloat, width: CGFloat = 360) throws {
            let root = DesktopRoot(model: model, hide: {}).frame(width: width, height: height).environment(\.colorScheme, .light)
            let host = NSHostingView(rootView: root)
            let window = NSWindow(contentRect: NSRect(x: -2000, y: -2000, width: width, height: height), styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = host
            host.frame = NSRect(x: 0, y: 0, width: width, height: height)
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw StoreError.invalidText }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { throw StoreError.invalidText }
            try png.write(to: folder.appendingPathComponent(name + ".png"))
        }
        model.setPinned(false); model.home(); try render("01-active", height: 290)
        model.setPinned(true); model.toggleCollapsed(); try require(model.collapsed); try render("02-strip", height: 44, width: 280)
        model.toggleCollapsed(); try require(!model.collapsed)
        model.replace(); model.draft = String(repeating: "字", count: 19)
        try require(model.toast == nil); let old = model.state.active; model.save()
        try require(model.toast != nil && model.state.active == old)
        try render("03-submit-toast", height: 330)
        model.toast = nil; model.draft = "写完第一篇文章"; model.save()
        try require(model.state.active?.text == "写完第一篇文章" && model.state.history.contains { !$0.completed })
        model.navigate("history"); try render("04-history", height: 390)
        model.home(); model.complete(); try require(model.completed?.text == "写完第一篇文章" && model.state.active == nil)
        try render("05-completion", height: 350)
        model.nextThing(); try render("06-next", height: 285)
        model.navigate("settings"); try render("07-settings", height: 380)
        model.navigate("about"); try render("08-about", height: 340)
        let saved = try model.disk.load(); try require(saved.state == model.state)
        try JSONEncoder().encode(model.state).write(to: folder.appendingPathComponent("state.json"))
        try Data("Native model integration checks passed; screenshots rendered from SwiftUI, not OS interaction tests.\n".utf8).write(to: folder.appendingPathComponent("result.txt"))
        print("Native model/render checks passed: \(folder.path)")
    }
}
