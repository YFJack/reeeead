import SwiftUI
import AVFoundation

struct MainView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var speech: SpeechEngine
    @ObservedObject var ruler: RulerController
    @State private var mode = "read"
    @State private var recordingError = ""
    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 28).padding(.top, 22).padding(.bottom, 23)
            if model.page == .home {
                home.padding(.horizontal, 28)
                Spacer(minLength: 18)
            } else {
                Picker("设置分类", selection: $model.page) { Text("语音").tag(Page.voice); Text("标尺").tag(Page.ruler); Text("快捷键").tag(Page.shortcuts) }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 28).padding(.bottom, 22)
                ScrollView {
                    Group {
                        switch model.page {
                        case .voice: VoiceSettings(model: model, speech: speech)
                        case .ruler: rulerSettings
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
        .sheet(isPresented: Binding(get: { model.recording != nil }, set: { if !$0 { model.recording = nil } }), onDismiss: { model.registerShortcuts(); recordingError = "" }) {
            VStack(spacing: 18) {
                Text("设置快捷键").font(.system(size: 20, weight: .semibold))
                Text("按住 ⌘、⌥ 或 ⌃，再按一个字母或数字。").font(.system(size: 12)).foregroundStyle(Ink.muted)
                KeyCap(text: "等待按键…")
                if !recordingError.isEmpty { Text(recordingError).font(.system(size: 12)).foregroundStyle(.orange) }
                ShortcutCapture(onShortcut: { shortcut in
                    guard let id = model.recording else { return }
                    recordingError = model.acceptShortcut(shortcut, id: id) ?? ""
                }, onCancel: { model.recording = nil }).frame(width: 1, height: 1)
                Button("取消") { model.recording = nil }.buttonStyle(ReaderButtonStyle()).keyboardShortcut(.cancelAction)
            }.padding(30).frame(width: 360).background(Ink.paper)
        }
    }
    private var header: some View {
        HStack(spacing: 10) {
            if model.page == .home {
                ReaderMark().frame(width: 22, height: 24)
                Text("Reeeead").font(.system(size: 25, weight: .semibold, design: .rounded)).tracking(-1)
                Spacer()
                Button { model.page = .voice } label: { Image(systemName: "gearshape").font(.system(size: 17)).foregroundStyle(Ink.muted).frame(width: 30, height: 30) }.buttonStyle(.plain).help("设置").accessibilityLabel("设置")
            } else {
                Button { model.page = .home } label: { Image(systemName: "chevron.left").font(.system(size: 15, weight: .medium)).frame(width: 25, height: 30) }.buttonStyle(.plain).accessibilityLabel("返回阅读")
                Text("设置").font(.system(size: 21, weight: .semibold)); Spacer()
                Text("Reeeead").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Ink.muted)
            }
        }
    }
    private var home: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 22) { modeButton("朗读", symbol: "speaker.wave.2", value: "read"); modeButton("标尺", symbol: "line.3.horizontal", value: "ruler"); Spacer() }
            if mode == "read" {
                VStack(spacing: 0) {
                    TextEditor(text: $model.sample).font(.system(size: 16)).lineSpacing(8).scrollContentBackground(.hidden).padding(16).frame(height: 152).accessibilityLabel("朗读文字")
                    HStack(spacing: 12) {
                        Button { model.page = .voice } label: { Label(model.preferences.provider == "system" ? "系统语音" : "外部语音", systemImage: "waveform").font(.system(size: 11)).foregroundStyle(Ink.muted) }.buttonStyle(.plain)
                        Menu {
                            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { rate in Button(String(format: "%.2g×", rate)) { model.preferences.speed = rate } }
                        } label: { Text(String(format: "%.2g×", model.preferences.speed)).font(.system(size: 11, weight: .medium)) }.menuStyle(.borderlessButton).fixedSize().help("朗读速度")
                        Spacer()
                        if speech.busy {
                            if speech.state != .loading {
                                Button { speech.togglePause() } label: { Image(systemName: speech.state == .paused ? "play.fill" : "pause.fill") }.buttonStyle(ReaderButtonStyle()).accessibilityLabel(speech.state == .paused ? "继续" : "暂停")
                            }
                            Button("停止") { speech.stop() }.buttonStyle(ReaderButtonStyle(primary: true))
                        } else {
                            Button { speech.speak(model.sample, preferences: model.preferences) } label: { Label("朗读", systemImage: "play.fill") }.buttonStyle(ReaderButtonStyle(primary: true)).disabled(model.sample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }.padding(14)
                }.background(Ink.card, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Ink.faint))
                shortcutHint("选中文字后，随时朗读", key: model.preferences.readShortcut.display, id: 1)
            } else {
                VStack(spacing: 18) {
                    RulerPreview(opacity: model.preferences.dimOpacity, width: model.preferences.lineWidth, amber: model.preferences.lineColor == "amber")
                    HStack {
                        Text("点击两次，固定上下边界。").font(.system(size: 12)).foregroundStyle(Ink.muted); Spacer()
                        Button(ruler.active ? "收起标尺" : "开启标尺") { ruler.toggle(preferences: model.preferences) }.buttonStyle(ReaderButtonStyle(primary: true))
                    }
                }.padding(16).background(Ink.card, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Ink.faint))
                shortcutHint("固定后照常滚动，Esc 退出", key: model.preferences.rulerShortcut.display, id: 2)
            }
            if !model.permission {
                HStack(spacing: 9) {
                    Image(systemName: "hand.raised").font(.system(size: 12))
                    Text("开启权限，即可跨应用使用").font(.system(size: 11)); Spacer()
                    Button("开启") { SelectionReader.requestPermission() }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).underline()
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
        HStack { Text(text).font(.system(size: 12)).foregroundStyle(Ink.muted); Spacer(); Button { model.beginRecording(id) } label: { KeyCap(text: key) }.buttonStyle(.plain).help("修改快捷键") }
    }
    private var rulerSettings: some View {
        VStack(alignment: .leading, spacing: 25) {
            RulerPreview(opacity: model.preferences.dimOpacity, width: model.preferences.lineWidth, amber: model.preferences.lineColor == "amber")
            sliderRow("遮罩深浅", value: $model.preferences.dimOpacity, range: 0.2...0.9, label: "\(Int(model.preferences.dimOpacity * 100))%")
            sliderRow("横线粗细", value: $model.preferences.lineWidth, range: 1...4, label: "\(Int(model.preferences.lineWidth)) pt", step: 1)
            HStack { Text("横线颜色").font(.system(size: 13)); Spacer(); Picker("横线颜色", selection: $model.preferences.lineColor) { Text("柔和绿").tag("sage"); Text("琥珀色").tag("amber") }.labelsHidden().frame(width: 130) }
            Text("下次开启时生效。只覆盖鼠标所在的显示器。").font(.system(size: 11)).foregroundStyle(Ink.muted)
        }
    }
    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingGroup(title: "快捷键") {
                shortcutHint("选区朗读 / 停止", key: model.preferences.readShortcut.display, id: 1); Divider()
                shortcutHint("开启 / 收起标尺", key: model.preferences.rulerShortcut.display, id: 2)
            }
            Divider()
            SettingGroup(title: "权限") {
                HStack {
                    Label(model.permission ? "辅助功能已开启" : "辅助功能未开启", systemImage: model.permission ? "checkmark.circle" : "hand.raised").font(.system(size: 13)); Spacer()
                    Button(model.permission ? "系统设置" : "开启") { SelectionReader.requestPermission() }.buttonStyle(ReaderButtonStyle())
                }
                HStack { Text("用于读取选中文字和响应 Esc。").font(.system(size: 11)).foregroundStyle(Ink.muted); Spacer(); Button("重新检查") { model.refreshPermission() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Ink.muted) }
            }
            Divider()
            SettingGroup(title: "兼容性") {
                Toggle("复制兼容模式", isOn: $model.preferences.copyFallback).font(.system(size: 13)).toggleStyle(.switch).controlSize(.small)
                Text("读取选区失败时模拟 ⌘C，并尝试恢复剪贴板。").font(.system(size: 11)).foregroundStyle(Ink.muted).lineSpacing(4)
            }
        }
    }
    private var footer: some View {
        HStack(spacing: 8) {
            if speech.state == .loading { ProgressView().controlSize(.mini) }
            else { Circle().fill(speech.busy || ruler.active ? Ink.accent : Ink.muted.opacity(0.55)).frame(width: 5, height: 5) }
            Text(model.notice.isEmpty ? speech.message : model.notice).font(.system(size: 10)).foregroundStyle(Ink.muted).lineLimit(2).textSelection(.enabled)
            Spacer(minLength: 0)
            if !model.notice.isEmpty { Button("关闭") { model.notice = "" }.buttonStyle(.plain).font(.system(size: 10)) }
            if ruler.active { Button("收起") { ruler.stop() }.buttonStyle(.plain).font(.system(size: 10, weight: .medium)) }
            if speech.busy { Button("停止") { speech.stop() }.buttonStyle(.plain).font(.system(size: 10, weight: .medium)) }
        }.frame(minHeight: 38).padding(.horizontal, 28).padding(.bottom, 5)
    }
}

func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, label: String, step: Double = 0.05) -> some View {
    HStack(spacing: 12) {
        Text(title).font(.system(size: 13)).frame(width: 68, alignment: .leading)
        Slider(value: value, in: range, step: step).accessibilityLabel(title)
        Text(label).font(.system(size: 11, design: .monospaced)).frame(width: 43, alignment: .trailing)
    }
}
struct ShortcutCapture: NSViewRepresentable {
    let onShortcut: (Shortcut) -> Void
    let onCancel: () -> Void
    func makeNSView(context: Context) -> ShortcutRecorderView { let v = ShortcutRecorderView(); v.onShortcut = onShortcut; v.onCancel = onCancel; return v }
    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) { nsView.onShortcut = onShortcut; nsView.onCancel = onCancel }
}
struct RulerPreview: View {
    let opacity: Double
    let width: Double
    let amber: Bool
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 13) {
                Text("其他内容，暂时退后。"); Text("把目光留在正在读的这一行。"); Text("向下滚动，接着读。")
            }.font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
            VStack(spacing: 0) {
                Color.black.opacity(opacity).frame(height: 43)
                Rectangle().fill(amber ? Color(hex: 0xE8914A) : Color(hex: 0xADD69E)).frame(height: width)
                Color.clear.frame(height: 38)
                Rectangle().fill(amber ? Color(hex: 0xE8914A) : Color(hex: 0xADD69E)).frame(height: width)
                Color.black.opacity(opacity)
            }
        }.frame(height: 130).background(Ink.paper).clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .ignore).accessibilityLabel("阅读带预览：中间清晰，上下变暗")
    }
}
struct VoiceSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject var speech: SpeechEngine
    @State private var key = ""
    @State private var keyStatus = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingGroup(title: "语音来源") { Picker("语音来源", selection: $model.preferences.provider) { Text("系统语音").tag("system"); Text("外部 API").tag("api") }.pickerStyle(.segmented).labelsHidden() }
            if model.preferences.provider == "system" {
                SettingGroup(title: "声音") {
                    Picker("声音", selection: $model.preferences.systemVoice) {
                        Text("自动选择 · 中文 / English").tag("")
                        ForEach(model.voices, id: \.identifier) { voice in Text("\(voice.name) · \(voice.language)").tag(voice.identifier) }
                    }.labelsHidden()
                    Text("本机朗读，无需 API Key。").font(.system(size: 11)).foregroundStyle(Ink.muted)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    input("完整接口地址", text: $model.preferences.endpoint, prompt: "https://…/v1/audio/speech")
                    HStack(spacing: 12) { input("模型", text: $model.preferences.model, prompt: "tts-1"); input("音色", text: $model.preferences.voice, prompt: "alloy") }
                    SettingGroup(title: "API Key") {
                        SecureField("仅存于本机钥匙串", text: $key).modifier(QuietField()).accessibilityLabel("API Key")
                        HStack {
                            Button("保存") {
                                do { guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { keyStatus = "请先输入密钥。"; return }; try KeyStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines), endpoint: model.preferences.endpoint); key = ""; keyStatus = "已保存到此地址对应的钥匙串。" }
                                catch { keyStatus = error.localizedDescription }
                            }.buttonStyle(ReaderButtonStyle())
                            Button("删除已存密钥") { do { try KeyStore.delete(endpoint: model.preferences.endpoint); keyStatus = "已删除。" } catch { keyStatus = error.localizedDescription } }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Ink.muted)
                        }
                        if !keyStatus.isEmpty { Text(keyStatus).font(.system(size: 11)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true) }
                    }
                    Text("支持 OpenAI 兼容语音接口。朗读文字将发送至此服务，费用由你的账户承担。").font(.system(size: 11)).foregroundStyle(Ink.muted).lineSpacing(4)
                }
            }
            Divider()
            sliderRow("语速", value: $model.preferences.speed, range: 0.5...2, label: String(format: "%.2g×", model.preferences.speed))
            HStack { Text("对下一次朗读生效。").font(.system(size: 11)).foregroundStyle(Ink.muted); Spacer(); Button(speech.busy ? "停止" : "试听声音") { if speech.busy { speech.stop() } else { speech.speak("这是一段语音测试。", preferences: model.preferences) } }.buttonStyle(ReaderButtonStyle(primary: true)) }
        }.onChange(of: model.preferences.endpoint) { _, _ in key = ""; keyStatus = "" }
    }
    private func input(_ label: String, text: Binding<String>, prompt: String) -> some View {
        SettingGroup(title: label) { TextField(prompt, text: text).modifier(QuietField()).accessibilityLabel(label) }
    }
}
