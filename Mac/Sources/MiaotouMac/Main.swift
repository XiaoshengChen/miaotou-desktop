import AppKit
import SwiftUI
import Combine

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var model: DesktopModel!
    var status: NSStatusItem!
    let popover = NSPopover()
    var panel: FloatingPanel!
    var monitor: Any?
    var programmaticMove = false
    var wasPinned = false
    var userHidden = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("Miaotou: starting menu bar and panel")
        NSApp.setActivationPolicy(.accessory)
        model = DesktopModel()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.target = self; status.button?.action = #selector(toggle)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        if let url = Bundle.module.url(forResource: "companion", withExtension: "png"), let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 21, height: 15); image.isTemplate = true; status.button?.image = image; status.button?.imagePosition = .imageLeading
        }
        let content = DesktopRoot(model: model, hide: { [weak self] in self?.hideCard() })
        popover.contentViewController = NSHostingController(rootView: content)
        popover.behavior = .transient; popover.animates = false
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 290), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: content); panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true
        panel.level = .floating; panel.isFloatingPanel = true; panel.hidesOnDeactivate = false; panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; panel.delegate = self
        panel.setAccessibilityLabel("小苗头")
        panel.title = "小苗头"
        panel.setAccessibilityRole(.window)
        panel.setAccessibilitySubrole(.standardWindow)
        model.changed = { [weak self] in self?.update() }
        update()
        if model.state.active == nil || model.error != nil { showPopover() }
        model.refreshIdeas()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if CommandLine.arguments.contains("--diagnostics") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                let result: [String: Any] = ["menuTitle": status.button?.title ?? "", "pinned": model.pinned,
                    "panelVisible": panel.isVisible, "panelWidth": panel.frame.width, "panelHeight": panel.frame.height,
                    "panelLevel": panel.level.rawValue, "error": model.error ?? ""]
                if let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), let value = String(data: data, encoding: .utf8) { print(value) }
                NSApp.terminate(nil)
            }
        }
    }
    func height() -> CGFloat {
        if model.collapsed { return 44 }
        if model.completed != nil { return 350 }
        if ["settings", "history"].contains(model.route) { return model.route == "history" ? 390 : 380 }
        if model.route == "about" { return 340 }
        if model.route == "write" || model.state.active == nil { return model.toast == nil ? 285 : 330 }
        return model.state.companionEnabled ? 290 : 225
    }
    func update() {
        guard status != nil, panel != nil else { return }
        let title = model.state.active?.text ?? model.t("One thing", "写一件想做的事")
        var compact = title
        while (compact as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width > 172 { compact.removeLast() }
        if compact != title { compact += "…" }
        status.button?.title = " " + compact; status.button?.toolTip = "小苗头 · " + title
        status.button?.setAccessibilityLabel("小苗头 · " + title)
        popover.contentSize = NSSize(width: 360, height: height())
        if model.pinned {
            if !wasPinned { userHidden = false }
            popover.performClose(nil)
            let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
            let visible = screen.visibleFrame
            let width: CGFloat = model.collapsed ? 280 : 360
            var origin = panel.isVisible ? panel.frame.origin : NSPoint(x: model.document.preferences.x ?? visible.maxX-width-28, y: model.document.preferences.y ?? visible.maxY-height()-28)
            if panel.isVisible { origin.y += panel.frame.height - height() }
            origin.x = min(max(origin.x, visible.minX), visible.maxX-width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY-height())
            programmaticMove = true
            panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height())), display: true)
            programmaticMove = false
            if !panel.isVisible && !userHidden { panel.orderFrontRegardless() }
        } else if wasPinned {
            panel.orderOut(nil); showPopover()
        }
        wasPinned = model.pinned
    }
    @objc func toggle() {
        if NSApp.currentEvent?.type == .rightMouseUp { contextMenu(); return }
        if model.pinned {
            if panel.isVisible { userHidden = true; panel.orderOut(nil) } else { userHidden = false; update() }
        } else if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }
    func showPopover() {
        guard let button = status.button else { return }
        popover.contentSize = NSSize(width: 360, height: height())
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    func hideCard() { userHidden = true; popover.performClose(nil); panel.orderOut(nil) }
    func windowDidMove(_ notification: Notification) { if !programmaticMove { model.moved(to: panel.frame.origin) } }
    @objc func screensChanged() { if model.pinned { update() } }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { if let monitor { NSEvent.removeMonitor(monitor) } }
    func contextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: model.t("Show card", "显示卡片"), action: #selector(showFromMenu), keyEquivalent: "")
        menu.addItem(withTitle: model.t("History", "历史记录"), action: #selector(historyFromMenu), keyEquivalent: "")
        menu.addItem(withTitle: model.t("Preferences", "偏好设置"), action: #selector(settingsFromMenu), keyEquivalent: "")
        menu.addItem(.separator()); menu.addItem(withTitle: model.t("Quit 小苗头", "退出小苗头"), action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        status.menu = menu; status.button?.performClick(nil); status.menu = nil
    }
    @objc func showFromMenu() { userHidden = false; if model.pinned { update() } else { showPopover() } }
    @objc func historyFromMenu() { model.navigate("history"); showFromMenu() }
    @objc func settingsFromMenu() { model.navigate("settings"); showFromMenu() }
    @objc func quit() { NSApp.terminate(nil) }
}

@main struct Main {
    @MainActor static func main() {
        let app = NSApplication.shared
        if let i = CommandLine.arguments.firstIndex(of: "--render-qa"), CommandLine.arguments.count > i+1 {
            app.setActivationPolicy(.prohibited)
            do { try RenderQA.run(to: URL(fileURLWithPath: CommandLine.arguments[i+1])) }
            catch { fputs("QA failed: \(error)\n", stderr); exit(1) }
            return
        }
        let delegate = AppDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
