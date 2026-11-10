import SwiftUI
import AVFoundation

struct MainView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var speech: SpeechEngine
    @ObservedObject var ruler: RulerController
    @State private var mode = "focus"
    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 28).padding(.top, 22).padding(.bottom, 23)
            if model.page == .home {
                home.padding(.horizontal, 28)
                if mode != "focus" { Spacer(minLength: 18) }
            } else {
                Picker(L("设置分类"), selection: $model.page) { Text(L("语音")).tag(Page.voice); Text(L("标尺")).tag(Page.ruler); Text(L("窗口聚焦")).tag(Page.focus); Text(L("快捷键")).tag(Page.shortcuts) }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 28).padding(.bottom, 22)
                ScrollView {
                    Group {
                        switch model.page {
                        case .voice: VoiceSettings(model: model, speech: speech)
                        case .ruler: rulerSettings
                        case .focus: WindowFocusSettings(model: model, focus: model.focus)
                        case .shortcuts: shortcutSettings
                        case .home: EmptyView()
                        }
                    }.padding(.horizontal, 28).padding(.bottom, 22)
                }
            }
            footer
        }
        .background(Ink.paper).foregroundStyle(Ink.dark).tint(Ink.dark)
        .frame(minWidth: 460, minHeight: 540).preferredColorScheme(.light)
        .sheet(isPresented: Binding(get: { model.recording != nil }, set: { if !$0 { model.recording = nil } }), onDismiss: { model.registerShortcuts(); model.recordingError = "" }) {
            VStack(spacing: 18) {
                Text(L("设置快捷键")).font(.system(size: 20, weight: .semibold))
                Text(L("按下想用的快捷键，松开即可保存。")).font(.system(size: 12)).foregroundStyle(Ink.muted)
                KeyCap(text: L("等待按键…"))
                if !model.recordingError.isEmpty { Text(model.recordingError).font(.system(size: 12)).foregroundStyle(.orange) }
                ShortcutCapture(onShortcut: { shortcut in
                    guard let id = model.recording else { return }
                    model.recordingError = model.acceptShortcut(shortcut, id: id) ?? ""
                }, onCancel: { model.recording = nil }).frame(width: 1, height: 1)
                Button(L("取消")) { model.recording = nil }.buttonStyle(ReaderButtonStyle()).keyboardShortcut(.cancelAction)
            }.padding(30).frame(width: 390).background(Ink.paper)
        }
    }
    private var header: some View {
        HStack(spacing: 10) {
            ReaderMark().frame(width: 32, height: 32)
            if model.page == .home {
                ReaderWordmark(width: 150)
                Spacer()
                Button { model.page = .voice } label: { Image(systemName: "gearshape").font(.system(size: 17)).foregroundStyle(Ink.muted).frame(width: 30, height: 30) }.buttonStyle(.plain).help(L("设置")).accessibilityLabel(L("设置"))
            } else {
                ReaderWordmark(width: 150)
                Spacer()
                Button { model.page = .home } label: { Image(systemName: "xmark").font(.system(size: 15, weight: .medium)).foregroundStyle(Ink.muted).frame(width: 30, height: 30) }.buttonStyle(.plain).help(L("返回阅读")).accessibilityLabel(L("返回阅读"))
            }
        }
    }
    private var home: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 22) { modeButton(L("窗口聚焦"), symbol: "rectangle", value: "focus"); modeButton(L("朗读"), symbol: "speaker.wave.2", value: "read"); modeButton(L("标尺"), symbol: "line.3.horizontal", value: "ruler"); Spacer() }
            if mode == "focus" {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        WindowFocusControl(model: model, focus: model.focus)
                        WindowFocusSettings(model: model, focus: model.focus)
                    }.padding(.bottom, 18)
                }
            } else if mode == "read" {
                VStack(spacing: 0) {
                    TextEditor(text: $model.sample).font(.system(size: 16)).lineSpacing(8).scrollContentBackground(.hidden).padding(16).frame(height: 152).accessibilityLabel(L("朗读文字"))
                    HStack(spacing: 12) {
                        Button { model.page = .voice } label: { Label(model.preferences.provider == "system" ? L("系统语音") : L("外部语音"), systemImage: "waveform").font(.system(size: 11)).foregroundStyle(Ink.muted) }.buttonStyle(.plain)
                        Menu {
                            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { rate in Button(String(format: "%.2g×", rate)) { model.preferences.speed = rate } }
                        } label: { Text(String(format: "%.2g×", model.preferences.speed)).font(.system(size: 11, weight: .medium)) }.menuStyle(.borderlessButton).fixedSize().help(L("朗读速度"))
                        Spacer()
                        if speech.busy {
                            if speech.state != .loading {
                                Button { speech.togglePause() } label: { Image(systemName: speech.state == .paused ? "play.fill" : "pause.fill") }.buttonStyle(ReaderButtonStyle()).accessibilityLabel(speech.state == .paused ? L("继续") : L("暂停"))
                            }
                            Button(L("停止")) { speech.stop() }.buttonStyle(ReaderButtonStyle(primary: true))
                        } else {
                            Button { speech.speak(model.sample, preferences: model.preferences) } label: { Label(L("朗读"), systemImage: "play.fill") }.buttonStyle(ReaderButtonStyle(primary: true)).disabled(model.sample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }.padding(14)
                }.background(Ink.card, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Ink.faint))
                shortcutHint(L("选中文字后，随时朗读"), key: model.preferences.readShortcut.display, id: 1)
            } else {
                VStack(spacing: 18) {
                    RulerPreview(opacity: model.preferences.dimOpacity, width: model.preferences.lineWidth, amber: model.preferences.lineColor == "amber")
                    HStack {
                        Text(L("点击两次，固定上下边界。")).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true).foregroundStyle(Ink.muted); Spacer()
                        Button(ruler.active ? L("收起标尺") : L("开启标尺")) { model.toggleRuler() }.buttonStyle(ReaderButtonStyle(primary: true))
                    }
                }.padding(16).background(Ink.card, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Ink.faint))
                shortcutHint(L("固定后照常滚动，Esc 退出"), key: model.preferences.rulerShortcut.display, id: 2)
            }
            if !model.permission {
                HStack(spacing: 9) {
                    Image(systemName: "hand.raised").font(.system(size: 12))
                    Text(L("开启权限，即可跨应用使用")).font(.system(size: 11)); Spacer()
                    Button(L("开启")) { SelectionReader.requestPermission() }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).underline()
                }.foregroundStyle(Ink.muted).padding(.top, 4)
            }
        }
    }
    private func modeButton(_ title: String, symbol: String, value: String) -> some View {
        Button { mode = value } label: {
            VStack(spacing: 10) {
                Label(title, systemImage: symbol).font(.system(size: 14, weight: mode == value ? .semibold : .regular))
                Capsule().fill(mode == value ? Ink.dark : .clear).frame(height: 2)
            }.foregroundStyle(mode == value ? Ink.dark : Ink.muted).fixedSize(horizontal: true, vertical: false)
        }.buttonStyle(.plain)
    }
    private func shortcutHint(_ text: String, key: String, id: UInt32) -> some View {
        HStack { Text(text).font(.system(size: 12)).foregroundStyle(Ink.muted); Spacer(); Button { model.beginRecording(id) } label: { KeyCap(text: key) }.buttonStyle(.plain).help(L("修改快捷键")) }
    }
    private var rulerSettings: some View {
        VStack(alignment: .leading, spacing: 25) {
            RulerPreview(opacity: model.preferences.dimOpacity, width: model.preferences.lineWidth, amber: model.preferences.lineColor == "amber")
            sliderRow(L("遮罩深浅"), value: $model.preferences.dimOpacity, range: 0.2...0.9, label: "\(Int(model.preferences.dimOpacity * 100))%")
            sliderRow(L("横线粗细"), value: $model.preferences.lineWidth, range: 1...4, label: "\(Int(model.preferences.lineWidth)) pt", step: 1)
            HStack { Text(L("横线颜色")).font(.system(size: 13)); Spacer(); Picker(L("横线颜色"), selection: $model.preferences.lineColor) { Text(L("柔和绿")).tag("sage"); Text(L("琥珀色")).tag("amber") }.labelsHidden().frame(width: 130) }
            Text(L("下次开启时生效。只覆盖鼠标所在的显示器。")).font(.system(size: 11)).foregroundStyle(Ink.muted)
        }
    }
    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingGroup(title: L("界面语言")) {
                Picker(L("界面语言"), selection: $model.language) {
                    ForEach(AppLanguage.allCases) { language in Text(language.title).tag(language) }
                }.labelsHidden()
                Text(L("立即生效，不改变语音、快捷键或 API 配置。")).font(.system(size: 11)).foregroundStyle(Ink.muted)
            }
            Divider()
            SettingGroup(title: L("快捷键")) {
                shortcutHint(L("选区朗读 / 停止"), key: model.preferences.readShortcut.display, id: 1); Divider()
                shortcutHint(L("开启 / 收起标尺"), key: model.preferences.rulerShortcut.display, id: 2); Divider()
                shortcutHint(L("开启 / 收起窗口聚焦"), key: model.preferences.focusShortcut.display, id: 3)
            }
            Divider()
            SettingGroup(title: L("权限")) {
                HStack {
                    Label(model.permission ? L("辅助功能已开启") : L("辅助功能未开启"), systemImage: model.permission ? "checkmark.circle" : "hand.raised").font(.system(size: 13)); Spacer()
                    Button(model.permission ? L("系统设置") : L("开启")) { SelectionReader.requestPermission() }.buttonStyle(ReaderButtonStyle())
                }
                HStack { Text(L("用于读取选区、鼠标侧键和 Esc。")).font(.system(size: 11)).foregroundStyle(Ink.muted); Spacer(); Button(L("重新检查")) { model.refreshPermission() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Ink.muted) }
                if !model.permission {
                    Text(L("系统开关已开？请移除旧的 Reeeead 记录，再添加当前应用，然后退出重开。")).font(.system(size: 11)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
                    Button(L("在访达中定位当前应用")) { NSWorkspace.shared.selectFile(Bundle.main.bundlePath, inFileViewerRootedAtPath: "") }.buttonStyle(.plain).font(.system(size: 11)).underline()
                }
            }
            Divider()
            SettingGroup(title: L("兼容性")) {
                Toggle(L("复制兼容模式"), isOn: $model.preferences.copyFallback).font(.system(size: 13)).toggleStyle(.switch).controlSize(.small)
                Text(L("读取选区失败时模拟 ⌘C，并尝试恢复剪贴板。")).font(.system(size: 11)).foregroundStyle(Ink.muted).lineSpacing(4)
            }
        }
    }
    private var footer: some View {
        HStack(spacing: 8) {
            if speech.state == .loading { ProgressView().controlSize(.mini) }
            else { Circle().fill(speech.busy || ruler.active ? Ink.accent : Ink.muted.opacity(0.55)).frame(width: 5, height: 5) }
            Text(L(model.notice.isEmpty ? speech.message : model.notice)).font(.system(size: 10)).foregroundStyle(Ink.muted).lineLimit(2).textSelection(.enabled)
            Spacer(minLength: 0)
            if !model.notice.isEmpty { Button(L("关闭")) { model.notice = "" }.buttonStyle(.plain).font(.system(size: 10)) }
            if ruler.active { Button(L("收起")) { ruler.stop() }.buttonStyle(.plain).font(.system(size: 10, weight: .medium)) }
            if speech.busy { Button(L("停止")) { speech.stop() }.buttonStyle(.plain).font(.system(size: 10, weight: .medium)) }
        }.frame(minHeight: 38).padding(.horizontal, 28).padding(.bottom, 5)
    }
}

func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, label: String, step: Double = 0.05) -> some View {
    HStack(spacing: 12) {
        Text(title).font(.system(size: 13)).frame(width: 86, alignment: .leading)
        Slider(value: value, in: range, step: step).accessibilityLabel(title)
        Text(label).font(.system(size: 11, design: .monospaced)).frame(width: 43, alignment: .trailing)
    }
}
struct ShortcutCapture: NSViewRepresentable {
    let onShortcut: (Shortcut) -> Void
    let onCancel: () -> Void
    func makeNSView(context: Context) -> ShortcutRecorderView { let v = ShortcutRecorderView(); v.onShortcut = onShortcut; v.onCancel = onCancel; return v }
    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) { nsView.onShortcut = onShortcut; nsView.onCancel = onCancel }
    static func dismantleNSView(_ nsView: ShortcutRecorderView, coordinator: ()) { nsView.stopMonitoring() }
}
struct RulerPreview: View {
    let opacity: Double
    let width: Double
    let amber: Bool
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 13) {
                Text(L("其他内容，暂时退后。")); Text(L("把目光留在正在读的这一行。")); Text(L("向下滚动，接着读。"))
            }.font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
            VStack(spacing: 0) {
                Color.black.opacity(opacity).frame(height: 43)
                Rectangle().fill(amber ? Color(hex: 0xE8914A) : Color(hex: 0xADD69E)).frame(height: width)
                Color.clear.frame(height: 38)
                Rectangle().fill(amber ? Color(hex: 0xE8914A) : Color(hex: 0xADD69E)).frame(height: width)
                Color.black.opacity(opacity)
            }
        }.frame(height: 130).background(Ink.paper).clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .ignore).accessibilityLabel(L("阅读带预览：中间清晰，上下变暗"))
    }
}
struct VoiceSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject var speech: SpeechEngine
    @State private var key = ""
    @State private var keyStatus = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingGroup(title: L("语音来源")) { Picker(L("语音来源"), selection: Binding(get: { model.preferences.provider }, set: { model.preferences.selectProvider($0) })) { Text(L("系统语音")).tag("system"); Text("MiniMax").tag("minimax"); Text(L("兼容 API")).tag("api") }.pickerStyle(.segmented).labelsHidden() }
            if model.preferences.provider == "system" {
                SettingGroup(title: L("声音")) {
                    Picker(L("声音"), selection: $model.preferences.systemVoice) {
                        Text(L("自动选择 · 中文 / English")).tag("")
                        ForEach(model.voices, id: \.identifier) { voice in Text("\(voice.name) · \(voice.language)").tag(voice.identifier) }
                    }.labelsHidden()
                    Text(L("本机朗读，无需 API Key。")).font(.system(size: 11)).foregroundStyle(Ink.muted)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    input(L("完整接口地址"), text: $model.preferences.endpoint, prompt: "https://…/v1/audio/speech")
                    HStack(spacing: 12) { input(L("模型"), text: $model.preferences.model, prompt: "tts-1"); input(L("音色"), text: $model.preferences.voice, prompt: "alloy") }
                    SettingGroup(title: "API Key") {
                        SecureField(L("仅存于本机钥匙串"), text: $key).modifier(QuietField()).accessibilityLabel("API Key")
                        HStack {
                            Button(L("保存")) {
                                do { guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { keyStatus = L("请先输入密钥。"); return }; try KeyStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines), endpoint: model.preferences.endpoint); key = ""; keyStatus = L("已保存到此地址对应的钥匙串。") }
                                catch { keyStatus = error.localizedDescription }
                            }.buttonStyle(ReaderButtonStyle())
                            Button(L("删除已存密钥")) { do { try KeyStore.delete(endpoint: model.preferences.endpoint); keyStatus = L("已删除。") } catch { keyStatus = error.localizedDescription } }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Ink.muted)
                        }
                        if !keyStatus.isEmpty { Text(keyStatus).font(.system(size: 11)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true) }
                    }
                    Text(model.preferences.provider == "minimax" ? L("使用 MiniMax 原生语音接口。朗读文字将发送至该服务，费用由你的账户承担。") : L("支持 OpenAI 兼容语音接口。朗读文字将发送至此服务，费用由你的账户承担。")).font(.system(size: 11)).foregroundStyle(Ink.muted).lineSpacing(4)
                }
            }
            Divider()
            sliderRow(L("语速"), value: $model.preferences.speed, range: 0.5...2, label: String(format: "%.2g×", model.preferences.speed))
            HStack { Text(L("对下一次朗读生效。")).font(.system(size: 11)).foregroundStyle(Ink.muted); Spacer(); Button(speech.busy ? L("停止") : L("试听声音")) { if speech.busy { speech.stop() } else { speech.speak(L("这是一段语音测试。"), preferences: model.preferences) } }.buttonStyle(ReaderButtonStyle(primary: true)) }
        }.onChange(of: model.preferences.endpoint) { _, _ in key = ""; keyStatus = "" }
    }
    private func input(_ label: String, text: Binding<String>, prompt: String) -> some View {
        SettingGroup(title: label) { TextField(prompt, text: text).modifier(QuietField()).accessibilityLabel(label) }
    }
}

struct WindowFocusControl: View {
    @ObservedObject var model: AppModel
    @ObservedObject var focus: WindowFocusController
    var body: some View {
        HStack(spacing: 10) {
            Button { model.toggleFocus() } label: {
                Label(focus.active ? L("收起窗口聚焦") : L("开启窗口聚焦"), systemImage: focus.active ? "rectangle.inset.filled" : "rectangle")
                    .font(.system(size: 12, weight: .medium))
            }.buttonStyle(.plain).help(focus.active ? L("收起窗口聚焦") : L("开启窗口聚焦"))
            Spacer()
            Button { model.beginRecording(3) } label: { KeyCap(text: model.preferences.focusShortcut.display) }.buttonStyle(.plain).help(L("修改快捷键"))
        }.foregroundStyle(focus.active ? Ink.dark : Ink.muted)
    }
}

struct WindowFocusSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject var focus: WindowFocusController
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            FocusOpacityPreview(opacity: model.preferences.focusOpacity, cornerRadius: model.preferences.focusCornerRadius / 2)
            FocusOpacityControl(model: model)
            sliderRow(L("窗口圆角"), value: $model.preferences.focusCornerRadius, range: 0...24, label: "\(Int(model.preferences.focusCornerRadius)) pt", step: 1)
            Divider()
            SettingGroup(title: L("专注计时")) {
                Stepper(value: $model.preferences.focusMinutes, in: 1...180) {
                    HStack { Text(L("专注时间")); Spacer(); Text(L("%d 分钟", model.preferences.focusMinutes)).monospacedDigit() }
                }
                Stepper(value: $model.preferences.restMinutes, in: 1...60) {
                    HStack { Text(L("休息时间")); Spacer(); Text(L("%d 分钟", model.preferences.restMinutes)).monospacedDigit() }
                }
                Stepper(value: Binding(get: { focus.dailyGoal }, set: { focus.setDailyGoal($0) }), in: 1...20) {
                    HStack { Text(L("每日目标")); Spacer(); Text("\(focus.dailyGoal)").monospacedDigit() }
                }
                Text(L("时长会在下次开始计时时生效，当前循环保持不变。")).font(.system(size: 11)).foregroundStyle(Ink.muted)
            }.font(.system(size: 13))
            Divider()
            HStack {
                Text(L("快捷键")).font(.system(size: 12)); Spacer()
                Button { model.beginRecording(3) } label: { KeyCap(text: model.preferences.focusShortcut.display) }.buttonStyle(.plain)
            }
            Text(L("可与标尺同时使用。Esc 优先收起标尺，再按一次退出窗口聚焦。")).font(.system(size: 11)).foregroundStyle(Ink.muted)
        }
    }
}

struct FocusOpacityControl: View {
    @ObservedObject var model: AppModel
    private var transparency: Binding<Double> {
        Binding(get: { 1 - model.preferences.focusOpacity }, set: { model.preferences.focusOpacity = 1 - $0 })
    }
    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text(L("透明度")).font(.system(size: 12))
                Spacer()
                Text("\(Int((transparency.wrappedValue * 100).rounded()))%")
                    .font(.system(size: 12, design: .monospaced)).monospacedDigit()
            }
            Slider(value: transparency, in: 0...1, step: 0.01).tint(Ink.dark).accessibilityLabel(L("窗口外透明度"))
            HStack {
                Text(L("不透明")); Spacer(); Text(L("完全透明"))
            }.font(.system(size: 10)).foregroundStyle(Ink.muted)
        }
    }
}

struct FocusOpacityPreview: View {
    let opacity: Double
    var cornerRadius: Double = 6
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9).fill(Color(hex: 0xE4E2DC))
            HStack(spacing: 8) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.7)).frame(width: 58, height: 65)
                }
            }
            RoundedRectangle(cornerRadius: 9).fill(.black.opacity(opacity))
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 3) { ForEach(0..<3) { _ in Circle().fill(Ink.faint).frame(width: 4, height: 4) } }
                RoundedRectangle(cornerRadius: 1).fill(Ink.muted.opacity(0.4)).frame(width: 68, height: 3)
                RoundedRectangle(cornerRadius: 1).fill(Ink.muted.opacity(0.25)).frame(width: 85, height: 3)
                RoundedRectangle(cornerRadius: 1).fill(Ink.muted.opacity(0.25)).frame(width: 57, height: 3)
            }.padding(12).frame(width: 116, height: 76).background(Ink.paper, in: RoundedRectangle(cornerRadius: cornerRadius))
        }.frame(height: 110).accessibilityElement(children: .ignore).accessibilityLabel(L("窗口聚焦预览"))
    }
}
