import SwiftUI
import AVFoundation

struct MainView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var speech: SpeechEngine
    @ObservedObject var ruler: RulerController
    @State private var recordingError = ""
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 202)
            VStack(spacing: 0) {
                ScrollView {
                    Group {
                        switch model.page {
                        case .home: home
                        case .voice: VoiceSettings(model: model, speech: speech)
                        case .ruler: rulerSettings
                        case .shortcuts: shortcutSettings
                        }
                    }.padding(30).frame(maxWidth: 880)
                        .frame(maxWidth: .infinity)
                }
                statusBar
            }.background(Ink.paper)
        }
        .foregroundStyle(Ink.dark).tint(Ink.dark)
        .frame(minWidth: 940, minHeight: 700)
        .preferredColorScheme(.light)
        .sheet(isPresented: Binding(get: { model.recording != nil }, set: { if !$0 { model.recording = nil } }), onDismiss: { model.registerShortcuts(); recordingError = "" }) {
            VStack(spacing: 20) {
                PixelIcon(kind: "keys").frame(width: 40, height: 40)
                Text("按下你喜欢的快捷键").font(.system(size: 22, weight: .semibold))
                Text("包含 ⌘、⌥ 或 ⌃ 中至少一个修饰键，再加一个字母或数字。")
                    .font(.system(size: 13)).foregroundStyle(Ink.muted)
                KeyCap(text: "等待按键…")
                if !recordingError.isEmpty { Text(recordingError).font(.system(size: 12)).foregroundStyle(Ink.orange) }
                ShortcutCapture(onShortcut: { shortcut in
                    guard let id = model.recording else { return }
                    recordingError = model.acceptShortcut(shortcut, id: id) ?? ""
                }, onCancel: { model.recording = nil }).frame(width: 1, height: 1)
                Button("取消 · Esc") { model.recording = nil }.buttonStyle(LumaButtonStyle())
            }.padding(36).frame(width: 480).background(Ink.paper)
        }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                PixelIcon().frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 7) { PixelWord(); Text("一 行").font(.system(size: 11, weight: .medium)).tracking(4).foregroundStyle(Ink.muted) }
            }.padding(.horizontal, 24).padding(.top, 42).padding(.bottom, 42)
            Eyebrow(text: "YOUR READING COMPANION").font(.system(size: 8)).padding(.horizontal, 20).padding(.bottom, 14)
            ForEach(Array(Page.allCases.enumerated()), id: \.element) { index, page in
                Button { model.page = page } label: {
                    HStack(spacing: 12) {
                        PixelIcon(kind: ["home", "voice", "ruler", "keys"][index], color: model.page == page ? Ink.dark : Ink.muted).frame(width: 21, height: 21)
                        Text(page.rawValue).font(.system(size: 13, weight: model.page == page ? .semibold : .regular))
                        Spacer(minLength: 0)
                        if model.page == page { Rectangle().fill(Ink.orange).frame(width: 5, height: 5) }
                    }.padding(.horizontal, 13).padding(.vertical, 13)
                        .background(model.page == page ? Ink.card : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 5)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                PixelIcon(kind: "spark", color: Ink.orange).frame(width: 23, height: 23)
                Text("一次一行，\n也在向前。").font(.system(size: 18, weight: .medium)).lineSpacing(7)
                Text("A LITTLE SPACE TO FOCUS.").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.1).foregroundStyle(Ink.muted)
            }.padding(23)
            Rectangle().fill(Ink.dark.opacity(0.10)).frame(height: 1).padding(.horizontal, 23)
            HStack { Text("LUMA / 0.1.0"); Spacer(); Text("✦") }.font(.system(size: 9, design: .monospaced)).foregroundStyle(Ink.muted).padding(23)
        }.background(Ink.sidebar).frame(maxHeight: .infinity)
    }
    private var home: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Eyebrow(text: "MAKE ROOM FOR READING"); Spacer(); HStack(spacing: 6) { Circle().fill(Ink.dark).frame(width: 5, height: 5); Text("你的私人阅读空间").font(.system(size: 11)).foregroundStyle(Ink.muted) } }
            ZStack(alignment: .topLeading) {
                Image(nsImage: Assets.garden).resizable().interpolation(.none).scaledToFill().frame(height: 206).clipped().accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    Text("让阅读，\n慢慢变轻松。").font(.system(size: 30, weight: .semibold)).tracking(-0.6).lineSpacing(4)
                    Text("听见文字，也给目光一个落点。").font(.system(size: 12)).foregroundStyle(Ink.dark.opacity(0.8))
                }.padding(27)
            }.frame(height: 206).clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(3).background(Ink.faint, in: RoundedRectangle(cornerRadius: 15))
            HStack(alignment: .top, spacing: 14) {
                featureCard(kind: "voice", number: "01", title: "让文字读给你听", detail: "选中一句话，按下快捷键。\n再按一次，即可停止。", shortcut: model.preferences.readShortcut.display) { model.page = .voice }
                featureCard(kind: "ruler", number: "02", title: "只看眼前这一行", detail: "两次点击，框出阅读区域。\n滚动照常，干扰退后。", shortcut: model.preferences.rulerShortcut.display) { model.page = .ruler }
            }
            Surface(padding: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("在这里，试着慢下来").font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text(model.preferences.provider == "system" ? "系统语音 · 本机朗读" : "外部 API · 文字将发送至所设服务")
                            .font(.system(size: 10)).foregroundStyle(Ink.muted)
                    }
                    TextEditor(text: $model.sample).font(.system(size: 15)).lineSpacing(7)
                        .scrollContentBackground(.hidden).padding(8).frame(height: 78)
                        .background(Ink.paper, in: RoundedRectangle(cornerRadius: 6))
                        .accessibilityLabel("试读文字")
                    HStack(spacing: 10) {
                        Button { speech.speak(model.sample, preferences: model.preferences) } label: { HStack { Text("▶"); Text("试听这段文字") } }.buttonStyle(LumaButtonStyle(primary: true)).disabled(speech.busy)
                        if speech.busy {
                            Button(speech.state == .paused ? "继续" : "暂停") { speech.togglePause() }.buttonStyle(LumaButtonStyle()).disabled(speech.state == .loading)
                            Button("停止") { speech.stop() }.buttonStyle(LumaButtonStyle())
                        }
                        Spacer()
                        Text(String(format: "%.2g×", model.preferences.speed)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Ink.muted)
                    }
                }
            }
        }
    }
    private func featureCard(kind: String, number: String, title: String, detail: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Surface(padding: 17) {
            VStack(alignment: .leading, spacing: 11) {
                HStack { PixelIcon(kind: kind).frame(width: 25, height: 25); Spacer(); Eyebrow(text: number) }
                Text(title).font(.system(size: 17, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(Ink.muted).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                HStack { KeyCap(text: shortcut); Spacer(); Button("设置 ↗", action: action).buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Ink.orange) }.padding(.top, 3)
            }
        }
    }
    private var rulerSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageTitle(eyebrow: "02 / FOCUS", title: "给目光一个落点。", subtitle: "用一条清晰的阅读带，让其他内容暂时退后。")
            Surface {
                VStack(alignment: .leading, spacing: 17) {
                    HStack { Text("阅读带预览").font(.system(size: 15, weight: .semibold)); Spacer(); Eyebrow(text: "LIVE PREVIEW") }
                    RulerPreview(opacity: model.preferences.dimOpacity, width: model.preferences.lineWidth, amber: model.preferences.lineColor == "amber")
                    HStack {
                        Button(ruler.active ? "收起标尺" : "开启标尺") { ruler.toggle(preferences: model.preferences) }.buttonStyle(LumaButtonStyle(primary: true))
                        KeyCap(text: model.preferences.rulerShortcut.display)
                        Spacer()
                        Text(ruler.locked ? "已固定 · 鼠标正常操作" : "Esc 随时退出").font(.system(size: 12)).foregroundStyle(Ink.muted)
                    }
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 22) {
                    sliderRow("背景遮罩", value: $model.preferences.dimOpacity, range: 0.2...0.9, label: "\(Int(model.preferences.dimOpacity * 100))%")
                    sliderRow("横线粗细", value: $model.preferences.lineWidth, range: 1...4, label: "\(Int(model.preferences.lineWidth)) px", step: 1)
                    HStack {
                        Text("横线颜色").font(.system(size: 13))
                        Spacer()
                        Picker("横线颜色", selection: $model.preferences.lineColor) { Text("鼠尾草绿").tag("sage"); Text("暖琥珀色").tag("amber") }.labelsHidden().frame(width: 180)
                    }
                    Text("调整会在下次开启标尺时生效。").font(.system(size: 11)).foregroundStyle(Ink.muted)
                }
            }
            HStack(alignment: .top, spacing: 22) {
                step("1", "按下快捷键", "横线跟随鼠标")
                step("2", "点击两次", "先定上边，再定下边")
                step("3", "自在阅读", "滚动照常，Esc 收起")
            }.padding(.horizontal, 8)
            Text("只覆盖启动时鼠标所在的显示器。阅读带固定在屏幕上，不跟随网页内容移动。").font(.system(size: 12)).foregroundStyle(Ink.muted).lineSpacing(5)
        }
    }
    private func step(_ n: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(n).font(.system(size: 11, weight: .bold, design: .monospaced)).padding(7).background(Ink.sage, in: RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 13, weight: .semibold)); Text(text).font(.system(size: 11)).foregroundStyle(Ink.muted) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageTitle(eyebrow: "04 / YOUR WAY", title: "顺手，才会常用。", subtitle: "设置熟悉的快捷键，在任何应用里轻轻唤起。")
            Surface {
                VStack(spacing: 22) {
                    shortcutRow("选区朗读 / 停止", detail: "先选中文字，再按下快捷键。", value: model.preferences.readShortcut.display, id: 1)
                    Divider().overlay(Ink.faint)
                    shortcutRow("开启 / 收起标尺", detail: "标尺开启后，也可以按 Esc 退出。", value: model.preferences.rulerShortcut.display, id: 2)
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 17) {
                    HStack {
                        PixelIcon(kind: "keys").frame(width: 26, height: 26)
                        Text("辅助功能权限").font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text(model.permission ? "已开启" : "待开启").font(.system(size: 12, weight: .medium)).foregroundStyle(model.permission ? Ink.dark : Ink.orange)
                    }
                    Text("用于读取其他应用中的选中文字，以及在标尺模式下响应 Esc。系统语音试读不需要这项权限。").font(.system(size: 13)).foregroundStyle(Ink.muted).lineSpacing(6)
                    HStack {
                        Button("打开系统设置") { SelectionReader.requestPermission() }.buttonStyle(LumaButtonStyle(primary: true))
                        Button("重新检查") { model.refreshPermission() }.buttonStyle(LumaButtonStyle())
                    }
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("复制兼容模式", isOn: $model.preferences.copyFallback).font(.system(size: 14, weight: .medium)).toggleStyle(.switch)
                    Text("当应用无法直接提供选中文字时，模拟 ⌘C 获取，并尝试恢复原剪贴板。关闭后只使用辅助功能接口读取。").font(.system(size: 12)).foregroundStyle(Ink.muted).lineSpacing(5)
                }
            }
            Text("关闭窗口后，Luma 仍在菜单栏等你。要完全退出，请使用菜单栏中的「退出 Luma」。")
                .font(.system(size: 12)).foregroundStyle(Ink.muted).lineSpacing(5)
        }
    }
    private func shortcutRow(_ title: String, detail: String, value: String, id: UInt32) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 14, weight: .semibold)); Text(detail).font(.system(size: 12)).foregroundStyle(Ink.muted) }
            Spacer()
            Button { model.beginRecording(id) } label: { KeyCap(text: value) }.buttonStyle(.plain).help("点击录制新的快捷键")
        }
    }
    private var statusBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Ink.faint).frame(height: 1)
            HStack(spacing: 9) {
                if speech.state == .loading { ProgressView().controlSize(.mini) }
                else { Rectangle().fill(speech.busy || ruler.active ? Ink.orange : Ink.dark).frame(width: 6, height: 6) }
                Text(model.notice.isEmpty ? speech.message : model.notice).font(.system(size: 11)).lineLimit(2).textSelection(.enabled)
                Spacer(minLength: 5)
                if !model.notice.isEmpty { Button("关闭") { model.notice = "" }.buttonStyle(.plain).font(.system(size: 11)) }
                if speech.busy { Button("停止") { speech.stop() }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold)) }
                if ruler.active { Button("收起标尺") { ruler.stop() }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold)) }
            }.padding(.horizontal, 24).frame(minHeight: 42).background(Ink.card)
        }
    }
}

func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, label: String, step: Double = 0.05) -> some View {
    HStack(spacing: 20) {
        Text(title).font(.system(size: 13)).frame(width: 75, alignment: .leading)
        Slider(value: value, in: range, step: step).accessibilityLabel(title)
        Text(label).font(.system(size: 12, weight: .medium, design: .monospaced)).frame(width: 52, alignment: .trailing)
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
            VStack(alignment: .leading, spacing: 14) {
                Text("世界有很多声音，不必同时听见。")
                Text("把注意力放在眼前这一行。").foregroundStyle(Ink.dark)
                Text("慢慢来，下一行会在那里等你。")
            }.font(.system(size: 16)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 30)
            VStack(spacing: 0) {
                Color.black.opacity(opacity).frame(height: 48)
                Rectangle().fill(amber ? Color(hex: 0xE8914A) : Color(hex: 0xADD69E)).frame(height: width)
                Color.clear.frame(height: 44)
                Rectangle().fill(amber ? Color(hex: 0xE8914A) : Color(hex: 0xADD69E)).frame(height: width)
                Color.black.opacity(opacity)
            }
        }.frame(height: 148).background(Ink.paper).clipShape(RoundedRectangle(cornerRadius: 7)).accessibilityLabel("标尺预览：中间一行保持明亮，上下变暗")
    }
}

struct VoiceSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject var speech: SpeechEngine
    @State private var key = ""
    @State private var keyStatus = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageTitle(eyebrow: "01 / LISTEN", title: "找到舒服的声音。", subtitle: "一句、一段。让文字用你喜欢的速度流动。")
            Surface {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("语音来源", selection: $model.preferences.provider) { Text("系统语音").tag("system"); Text("外部语音 API").tag("api") }.pickerStyle(.segmented)
                    if model.preferences.provider == "system" {
                        Text("本机朗读，无需 API Key。优先按文字自动选择中文或英文声音。").font(.system(size: 12)).foregroundStyle(Ink.muted).lineSpacing(4)
                        Picker("声音", selection: $model.preferences.systemVoice) {
                            Text("自动选择 · 中文 / English").tag("")
                            ForEach(model.voices, id: \.identifier) { voice in Text("\(voice.name) · \(voice.language)").tag(voice.identifier) }
                        }
                    } else {
                        Text("兼容 OpenAI 格式的语音接口。只在朗读时发送所选文字；服务费用由你的账户承担。").font(.system(size: 12)).foregroundStyle(Ink.muted).lineSpacing(5)
                        input("完整接口地址", text: $model.preferences.endpoint, prompt: "https://…/v1/audio/speech")
                        HStack(spacing: 15) { input("模型", text: $model.preferences.model, prompt: "tts-1"); input("音色", text: $model.preferences.voice, prompt: "alloy") }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("API Key").font(.system(size: 12, weight: .medium)); Spacer(); Text("仅保存在本机钥匙串").font(.system(size: 10)).foregroundStyle(Ink.muted) }
                            HStack {
                                SecureField("输入后点击保存；本地免密服务可留空", text: $key).textFieldStyle(.roundedBorder).accessibilityLabel("API Key")
                                Button("保存密钥") {
                                    do { guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { keyStatus = "请输入密钥；删除已存密钥请点击下方按钮。"; return }; try KeyStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines), endpoint: model.preferences.endpoint); key = ""; keyStatus = "已保存至此接口对应的系统钥匙串。" }
                                    catch { keyStatus = error.localizedDescription }
                                }.buttonStyle(LumaButtonStyle())
                            }
                            HStack {
                                Text(keyStatus.isEmpty ? "密钥按完整接口地址分别保存，修改地址后请重新保存。" : keyStatus).font(.system(size: 11)).foregroundStyle(Ink.muted)
                                Spacer()
                                Button("删除已存密钥") { do { try KeyStore.delete(endpoint: model.preferences.endpoint); keyStatus = "已删除此地址的密钥。" } catch { keyStatus = error.localizedDescription } }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(Ink.orange)
                            }
                        }
                    }
                    Divider()
                    sliderRow("朗读速度", value: $model.preferences.speed, range: 0.5...2, label: String(format: "%.2g×", model.preferences.speed))
                    HStack { Text("慢一点"); Spacer(); Text("按自己的节奏"); Spacer(); Text("快一点") }.font(.system(size: 10)).foregroundStyle(Ink.muted)
                    Text("语速对下一次朗读生效；系统语音与不同 API 的实际速度会略有差异。").font(.system(size: 11)).foregroundStyle(Ink.muted)
                }
            }
            Surface(padding: 18) {
                HStack(spacing: 15) {
                    PixelIcon(kind: "voice").frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 7) { Text("听听现在的声音").font(.system(size: 14, weight: .semibold)); Text("“不着急，按照自己的节奏，慢慢向前。”").font(.system(size: 12)).foregroundStyle(Ink.muted) }
                    Spacer()
                    Button(speech.busy ? "停止" : "试听") {
                        if speech.busy { speech.stop() } else { speech.speak("不着急，按照自己的节奏，慢慢向前。", preferences: model.preferences) }
                    }.buttonStyle(LumaButtonStyle(primary: true))
                }
            }
            Text("外部服务需返回 MP3 音频，并接受 model、voice、input、speed 和 response_format 字段。其他协议的服务需要专用适配。")
                .font(.system(size: 11)).foregroundStyle(Ink.muted).lineSpacing(5)
        }.onChange(of: model.preferences.endpoint) { _, _ in key = ""; keyStatus = "" }
    }
    private func input(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(label).font(.system(size: 12, weight: .medium)); TextField(prompt, text: text).textFieldStyle(.roundedBorder).font(.system(size: 12, design: .monospaced)).accessibilityLabel(label) }
    }
}
