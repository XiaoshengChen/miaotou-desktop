import SwiftUI
import AppKit
import MiaotouCore

enum Palette {
    static let ink = Color(red: 23/255, green: 63/255, blue: 59/255)
    static let aqua = Color(red: 164/255, green: 205/255, blue: 198/255)
    static let mint = Color(red: 218/255, green: 234/255, blue: 228/255)
    static let paper = Color(red: 250/255, green: 252/255, blue: 250/255)
    static let muted = Color(red: 94/255, green: 116/255, blue: 107/255)
}
struct Companion: View {
    var happy = false
    var body: some View {
        if happy { Palette.ink.mask(Image(nsImage: Assets.image("happy")).resizable().scaledToFit().luminanceToAlpha()) }
        else { Image(nsImage: Assets.image("companion")).resizable().scaledToFit() }
    }
}
struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 16).frame(height: 38).frame(maxWidth: .infinity)
            .foregroundStyle(Palette.paper).background(Palette.ink, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
struct DesktopRoot: View {
    @ObservedObject var model: DesktopModel
    var hide: () -> Void
    @FocusState private var writing: Bool
    var body: some View {
        Group {
            if model.collapsed { strip }
            else {
                VStack(spacing: 0) {
                    header
                    if let old = model.completed { celebration(old) }
                    else if model.route == "history" { history }
                    else if model.route == "settings" { settings }
                    else if model.route == "about" { about }
                    else if model.route == "write" || model.state.active == nil { editor }
                    else { active }
                }
            }
        }
        .frame(width: model.collapsed ? 280 : 360)
        .foregroundStyle(Palette.ink).background(Palette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .environment(\.locale, Locale(identifier: model.zh ? "zh-Hans" : "en"))
        .onChange(of: model.route) { _, route in writing = route == "write" }
        .alert(model.t("Something needs attention", "暂时遇到一点问题"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(model.t("OK", "知道了")) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var header: some View {
        HStack(spacing: 10) {
            if model.route != "home" && model.route != "write" {
                Button { model.home() } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain).help(model.t("Back", "返回"))
            }
            Text("小苗头").font(.system(size: 13, weight: .semibold))
            Spacer()
            Button { model.setPinned(!model.pinned) } label: { Image(systemName: model.pinned ? "pin.fill" : "pin") }
                .buttonStyle(.plain).help(model.t(model.pinned ? "Unpin" : "Keep on desktop", model.pinned ? "取消固定" : "固定在桌面"))
                .accessibilityIdentifier("pinCard")
            if model.pinned {
                Button { if model.state.active != nil { model.toggleCollapsed() } else { hide() } } label: { Image(systemName: "minus") }
                    .buttonStyle(.plain).help(model.t("Collapse", "收起"))
            }
            Menu {
                Button(model.t("Replace thing", "换一件")) { model.replace() }.disabled(model.state.active == nil)
                Button(model.t("History", "历史记录")) { model.navigate("history") }
                Button(model.t("Preferences", "偏好设置")) { model.navigate("settings") }
                Button(model.t("About", "关于")) { model.navigate("about") }
                Divider()
                Button(model.t("Hide card", "隐藏卡片"), action: hide)
                Button(model.t("Quit 小苗头", "退出小苗头")) { NSApp.terminate(nil) }
            } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().frame(width: 18)
                .accessibilityIdentifier("moreMenu")
        }.frame(height: 40).padding(.horizontal, 18)
    }
    private var strip: some View {
        HStack(spacing: 8) {
            Companion().frame(width: 25, height: 20).accessibilityHidden(true)
            Text(model.state.active?.text ?? "").font(.system(size: 13, weight: .medium)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 2)
            Button { model.toggleCollapsed() } label: { Image(systemName: "chevron.down") }.buttonStyle(.plain)
                .help(model.t("Expand", "展开"))
        }.padding(.horizontal, 13).frame(height: 44).background(Palette.aqua)
            .onTapGesture(count: 2) { model.toggleCollapsed() }
    }
    private var active: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(model.state.active?.text ?? "").font(.system(size: 29, weight: .medium)).tracking(-0.4)
                    .minimumScaleFactor(0.88).lineLimit(2).multilineTextAlignment(.center)
                    .padding(.horizontal, 22).frame(maxWidth: .infinity).frame(height: 115).background(Palette.aqua)
                    .accessibilityIdentifier("activeThing")
                if model.state.companionEnabled {
                    HStack(spacing: 8) {
                        Companion().frame(width: 34, height: 25).accessibilityHidden(true)
                        Text(model.tip).font(.system(size: 13)).lineLimit(1).minimumScaleFactor(0.85)
                    }.padding(.horizontal, 14).frame(maxWidth: .infinity).frame(height: 65).background(Palette.mint)
                }
            }.onTapGesture(count: 2) { if model.pinned { model.toggleCollapsed() } }
            Button(model.t("Done", "完成")) { model.complete() }.buttonStyle(QuietButton())
                .accessibilityIdentifier("completeThing").padding(.horizontal, 22).padding(.vertical, 16)
        }
    }
    private var placeholder: String {
        let n = model.state.completedCount + 1
        if n == 1 { return model.t("One thing you want to do", "写一件想做的事") }
        let names = [2: "第二", 3: "第三", 4: "第四", 5: "第五"]
        return model.t("What's the next thing?", "想做的\(names[n] ?? "第\(n)")件事是什么？")
    }
    private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.state.active != nil {
                Button(model.t("Cancel", "取消")) { model.home() }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
            TextField("", text: $model.draft, prompt: Text(placeholder).foregroundColor(Color(red: 0.56, green: 0.62, blue: 0.59)), axis: .vertical)
                .font(.system(size: 29, weight: .medium)).textFieldStyle(.plain).lineLimit(1...3)
                .focused($writing).onSubmit { model.save() }.accessibilityIdentifier("thingInput")
                .frame(minHeight: 90, alignment: .center)
            Rectangle().fill(Palette.ink.opacity(0.35)).frame(height: 1)
            HStack(alignment: .top, spacing: 8) {
                Text(model.t("Give it a place you'll see every day.", "给真正想做的事，留一个每天看得见的位置。"))
                    .font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                let excess = model.draft.count - TextBudget.limit(model.draft)
                if excess > 0 { Text("-\(excess)").font(.system(size: 11)).foregroundStyle(.red) }
            }.padding(.top, 4)
            if let toast = model.toast {
                Text(toast).font(.system(size: 12)).padding(10).frame(maxWidth: .infinity).background(Palette.mint.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            }
            Button(model.t("Save this", "写好了")) { model.save() }.buttonStyle(QuietButton())
                .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("saveThing").padding(.top, 18)
        }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24)
    }
    private func celebration(_ old: Thing) -> some View {
        VStack(spacing: 10) {
            DesktopCelebration(text: old.text).frame(height: 230).id(old.id)
            Button(model.t("Next thing", "下一件")) { model.nextThing(); writing = true }.buttonStyle(QuietButton()).padding(.horizontal, 24)
            Button(model.t("Back home", "返回首页")) { model.home() }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.muted).padding(.bottom, 18)
        }
    }
    private var history: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.t("History", "历史记录")).font(.system(size: 23, weight: .medium)).padding(.bottom, 22)
                if model.state.history.isEmpty { Text(model.t("Your finished things will be here.", "做过的事会留在这里。")).font(.system(size: 13)).foregroundStyle(Palette.muted) }
                ForEach(model.state.history.sorted { $0.date > $1.date }) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.text).font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
                            Text(item.date, style: .date).font(.system(size: 11)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        if !item.completed { Image(systemName: "pause").font(.system(size: 10)).foregroundStyle(Palette.muted).accessibilityLabel(model.t("Replaced unfinished", "未完成，已换下")) }
                    }.padding(.vertical, 14)
                    Divider().overlay(Palette.mint)
                }
            }.padding(24)
        }.frame(height: 350)
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 19) {
            Text(model.t("Preferences", "偏好设置")).font(.system(size: 23, weight: .medium))
            Picker(model.t("Language", "语言"), selection: Binding(get: { model.state.language }, set: model.setLanguage)) {
                Text("English").tag(AppLanguage.en); Text("简体中文").tag(AppLanguage.zh)
            }
            Toggle(model.t("Companion messages", "小家伙的话"), isOn: Binding(get: { model.state.companionEnabled }, set: model.setCompanion))
            Toggle(model.t("Open at login", "登录后启动"), isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
            Divider()
            Text(model.modelStatus).font(.system(size: 11)).foregroundStyle(Palette.muted)
            Text(model.t("Saved on this Mac. Phone and Windows records don't sync automatically yet.", "记录保存在这台 Mac，暂未与手机和 Windows 自动同步。"))
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
            HStack { Button(model.t("Export record", "导出记录"), action: model.exportRecord); Button(model.t("Import record", "导入记录"), action: model.importRecord) }
        }.toggleStyle(.switch).font(.system(size: 13)).padding(24).frame(height: 340, alignment: .top)
    }
    private var about: some View {
        VStack(spacing: 16) {
            Image(nsImage: Assets.image("icon")).resizable().scaledToFit().frame(width: 62, height: 62).clipShape(RoundedRectangle(cornerRadius: 14))
            Text("小苗头").font(.system(size: 24, weight: .medium))
            Text("1.0 (1) · Mac").font(.system(size: 11)).foregroundStyle(Palette.muted)
            Text(model.t("Keep one thing you want to do in sight.", "让自己想做的那件事，每天看得见。"))
                .font(.system(size: 13)).multilineTextAlignment(.center)
            Text(model.t("Your record stays on this Mac. No account, analytics or cloud upload. This version is free.", "记录保存在这台 Mac。无需账号，没有分析追踪或云端上传。此版本免费。"))
                .font(.system(size: 11)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }.padding(28).frame(height: 300)
    }
}

enum Assets {
    static func image(_ name: String) -> NSImage {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png"), let image = NSImage(contentsOf: url) else { return NSImage(size: NSSize(width: 1, height: 1)) }
        return image
    }
}

struct DesktopCelebration: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var finished = false
    var body: some View {
        ZStack {
            if !reduceMotion {
                TimelineView(.animation(paused: finished)) { context in FireworksCanvas(time: context.date.timeIntervalSince(start)) }
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            VStack(spacing: 20) {
                Text(text).font(.system(size: 27, weight: .medium)).multilineTextAlignment(.center).lineLimit(2).padding(.horizontal, 24)
                TimelineView(.animation(paused: finished || reduceMotion)) { context in
                    let t = context.date.timeIntervalSince(start)
                    let a = max(0, min(1, (t - 0.5)/0.65)), b = max(0, min(1, (t - 1.15)/0.5))
                    Companion(happy: true).frame(width: 64, height: 64).offset(y: reduceMotion ? 0 : -18*sin(a * .pi)-8*sin(b * .pi))
                }.accessibilityLabel("You did it. 你做到了。")
            }
        }.task { start = .now; try? await Task.sleep(for: .seconds(4.3)); finished = true }
    }
}
