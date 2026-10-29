import SwiftUI
import AppKit
import UserNotifications
import TimerCore

@MainActor
final class TimerModel: ObservableObject {
    private let session = Session(store: DefaultsStore(), onCompletion: { reminder in
        if reminder.sound { NSSound(named: NSSound.Name(reminder.soundName))?.play() }
        if reminder.notification, Bundle.main.bundleIdentifier != nil {
            let content = UNMutableNotificationContent()
            content.title = reminder.phase == .shortBreak || reminder.phase == .longBreak ? "Break complete" : "Countdown complete"
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    })
    @Published var title = "" { didSet { session.title = title } }
    @Published var selectedPreset = 0
    @Published var presetName = ""
    @Published var minutes = 25
    @Published var pressing = false
    @Published var held = false
    @Published var showingSettings = false
    @Published var focusMessage = ""
    @Published private(set) var state: Session.State = .ready
    @Published private(set) var seconds = 1500
    @Published private(set) var phase: Session.Phase = .standalone
    @Published private(set) var completedWork = 0
    @Published private(set) var lastCompletedPhase: Session.Phase?
    private var holdTask: Task<Void, Never>?
    private var timer: Timer?
    private var windowVisible = false
    private var asleep = false
    private var observers: [NSObjectProtocol] = []

    init() {
        title = session.title
        loadPreset()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.asleep = true }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.session.wake(at: Date()); self.asleep = false; self.refresh()
            }
        })
    }
    func loadPreset() {
        selectedPreset = session.selectedPreset
        presetName = session.presets[selectedPreset].name
        minutes = Int(session.presets[selectedPreset].duration / 60)
        refresh()
    }
    func selectPreset(_ index: Int) { session.selectPreset(at: index); loadPreset() }
    func savePreset() { session.renamePreset(at: selectedPreset, to: presetName); session.setDuration(TimeInterval(max(1, minutes) * 60)); refresh() }
    var presentation: Presentation { session.presentation }
    func setPresentation(floating: Bool, overFullScreen: Bool, menuBar: Bool, showTime: Bool) {
        guard presentation.floating != floating || presentation.overFullScreen != overFullScreen || presentation.menuBar != menuBar || presentation.showTime != showTime else { return }
        session.setPresentation(floating: floating, overFullScreen: overFullScreen, menuBar: menuBar, showTime: showTime)
        applyWindowPresentation(); refresh(); objectWillChange.send()
    }
    func setWindowVisible(_ visible: Bool) { guard windowVisible != visible else { return }; windowVisible = visible; timer?.invalidate(); timer = nil; refresh() }
    func applyWindowPresentation() {
        for window in NSApplication.shared.windows where window.canBecomeMain {
            window.level = (presentation.floating || presentation.overFullScreen) ? .floating : .normal
            if presentation.overFullScreen {
                window.collectionBehavior.remove(.moveToActiveSpace)
                window.collectionBehavior.formUnion([.canJoinAllSpaces, .fullScreenAuxiliary])
            } else {
                window.collectionBehavior.subtract([.canJoinAllSpaces, .fullScreenAuxiliary])
            }
        }
    }
    var menuBarImage: NSImage {
        let label = HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
            Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color(nsColor: .black))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.92), in: Capsule())
        }
        let renderer = ImageRenderer(content: label)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(size: .zero)
        image.isTemplate = false
        return image
    }
    var preset: Preset { session.presets[session.selectedPreset] }
    var presetNames: [String] { session.presets.map(\.name) }
    var phaseName: String { session.phaseName(phase) }
    func name(for phase: Session.Phase) -> String { session.phaseName(phase) }
    func setName(_ phase: Session.Phase, _ name: String) { session.setPhaseName(phase, name: name); objectWillChange.send() }
    func setWorkDuration(_ minutes: Int) { session.setWorkDuration(TimeInterval(minutes * 60)); refresh() }
    func setCycles(_ value: Bool) { session.setCyclesEnabled(value); refresh() }
    func setCycle(short: Int, long: Int, every: Int, enabled: Bool) {
        session.configureCycle(shortBreak: TimeInterval(short * 60), longBreak: TimeInterval(long * 60), longBreakEvery: every, longBreakEnabled: enabled); refresh()
    }
    func setFocusShortcut(_ name: String) { session.setFocusShortcut(name); objectWillChange.send() }
    func testFocusShortcut() {
        let name = preset.focusShortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { focusMessage = "Enter a shortcut name first."; return }
        focusMessage = "Testing…"
        Task.detached { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", name]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            let result: String
            do { try process.run(); process.waitUntilExit(); result = process.terminationStatus == 0 ? "Shortcut finished." : "Shortcut failed or was not found." }
            catch { result = "Unable to run shortcut." }
            await MainActor.run { self?.focusMessage = result }
        }
    }
    func setSoundName(_ name: String) { session.setSoundName(name); objectWillChange.send() }
    func setReminders(workSound: Bool, workNotification: Bool, breakSound: Bool, breakNotification: Bool) {
        session.setReminders(workSound: workSound, workNotification: workNotification, breakSound: breakSound, breakNotification: breakNotification)
        if (workNotification || breakNotification), Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        }
        objectWillChange.send()
    }
    func setAuto(work: Bool, breaks: Bool) { session.setAutomaticStarts(work: work, breaks: breaks); refresh() }
    func skip() { session.skip(); refresh() }
    func restart() { session.restartCycle(); refresh() }
    func quit() { session.quit(); timer?.invalidate(); NSApplication.shared.terminate(nil) }
    func beginPress() {
        guard holdTask == nil else { return }
        pressing = true; held = false
        holdTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard !Task.isCancelled else { return }
            held = true; pressing = false; reset()
        }
    }
    func cancelPress() { holdTask?.cancel(); holdTask = nil; pressing = false; held = false }
    func endPress() {
        holdTask?.cancel(); holdTask = nil; pressing = false
        if !held { toggle() }
        held = false
    }
    func toggle() {
        let now = Date()
        let before = session.state
        let phaseBefore = session.phase
        session.update(at: now)
        if before == .running && (session.state != .running || session.phase != phaseBefore) { refresh(); return }
        switch session.state {
        case .ready, .paused: session.start(at: now)
        case .running: session.pause(at: now)
        case .completed: session.advanceAfterCompletion()
        }
        refresh()
    }

    func reset() { session.reset(); refresh() }
    func refresh() {
        if !asleep { session.update(at: Date()) }
        state = session.state
        phase = session.phase
        completedWork = session.completedWork
        lastCompletedPhase = session.lastCompletedPhase
        seconds = Int(ceil(session.remaining(at: Date())))
        timer?.invalidate(); timer = nil
        if state == .running {
            let interval = (windowVisible || presentation.menuBar) ? 1.0 : max(0.01, session.remaining(at: Date()))
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var reopen: (() -> Void)?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { reopen?() }
        return true
    }
}

struct ContentView: View {
    @ObservedObject var model: TimerModel
    private let accent = Color(red: 0.82, green: 0.31, blue: 0.25)

    private var buttonTitle: String {
        switch model.state {
        case .ready: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        case .completed: model.phase == .shortBreak || model.phase == .longBreak ? "Go to work" : "Go to break"
        }
    }
    private var buttonIcon: String {
        switch model.state {
        case .ready, .paused: "play.fill"
        case .running: "pause.fill"
        case .completed: "arrow.right"
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Preset", selection: Binding(get: { model.selectedPreset }, set: { model.selectPreset($0) })) {
                    ForEach(0..<5) { Text(model.presetNames[$0]).tag($0) }
                }.labelsHidden().frame(maxWidth: 200)
                Spacer()
                Button { model.showingSettings = true } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.plain).font(.system(size: 16, weight: .medium))
                    .accessibilityLabel("Settings")
            }
            Spacer(minLength: 14)
            if model.phase == .shortBreak || model.phase == .longBreak {
                Text(model.phaseName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text(String(format: "%02d:%02d", model.seconds / 60, model.seconds % 60))
                .font(.system(size: 76, weight: .light, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
                .accessibilityLabel("Time remaining")
                .padding(.top, 4)
            if model.phase != .standalone && model.preset.cyclesEnabled {
                Text("\(model.completedWork) completed")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
            }
            if model.state == .completed {
                Text("Complete · tap to continue")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
            } else if let completed = model.lastCompletedPhase {
                Text("\(model.name(for: completed)) complete")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
            }
            Spacer(minLength: 12)
            Image(systemName: buttonIcon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(accent)
                .overlay(alignment: .leading) {
                    Rectangle().fill(.white.opacity(0.28))
                        .frame(width: model.pressing ? 76 : 0)
                        .animation(model.pressing ? .linear(duration: 2) : .none, value: model.pressing)
                        .allowsHitTesting(false)
                }
                .clipShape(Circle())
                .contentShape(Circle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in model.beginPress() }
                    .onEnded { _ in model.endPress() })
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(buttonTitle)
                .accessibilityAction { model.toggle() }
                .contextMenu { if model.phase != .standalone { Button("Skip") { model.skip() } } }
            Text("Hold to reset")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
            Spacer(minLength: 2)
        }
        .padding(20)
        .frame(width: 330, height: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $model.showingSettings) { SettingsView(model: model) }
        .onAppear { model.applyWindowPresentation(); model.setWindowVisible(true) }
        .onDisappear { model.cancelPress(); model.setWindowVisible(false) }
    }
}

struct SettingsView: View {
    @ObservedObject var model: TimerModel

    private func minutes(_ title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Minutes", value: value, format: .number)
                .labelsHidden().textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing).frame(width: 65)
            Text("min").foregroundStyle(.secondary)
        }
    }
    private func phaseName(_ title: String, phase: Session.Phase) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, text: Binding(get: { model.name(for: phase) }, set: { model.setName(phase, $0) }))
                .labelsHidden().textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing).frame(width: 180)
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings").font(.title2.bold())
                    Text("Customize your rhythm").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { model.showingSettings = false }
            }.padding(24)
            Divider()
            Form {
                Section("Preset") {
                    Picker("Current preset", selection: Binding(get: { model.selectedPreset }, set: { model.selectPreset($0) })) {
                        ForEach(0..<5) { Text(model.presetNames[$0]).tag($0) }
                    }
                    TextField("Preset name", text: Binding(get: { model.presetName }, set: { model.presetName = $0; model.savePreset() }))
                }
                Section("Timer") {
                    phaseName("Work name", phase: .work)
                    minutes("Countdown", value: Binding(get: { model.minutes }, set: { model.minutes = min(240, max(1, $0)); model.savePreset() }))
                    phaseName("Break name", phase: .shortBreak)
                    minutes("Break", value: Binding(get: { Int(model.preset.shortBreak / 60) }, set: { model.setCycle(short: min(240, max(1, $0)), long: Int(model.preset.longBreak / 60), every: model.preset.longBreakEvery, enabled: model.preset.longBreakEnabled) }))
                }
                Section("Pomodoro") {
                    Toggle("Use work and break cycles", isOn: Binding(get: { model.preset.cyclesEnabled }, set: { model.setCycles($0) }))
                    if model.preset.cyclesEnabled {
                        minutes("Work", value: Binding(get: { Int(model.preset.workDuration / 60) }, set: { model.setWorkDuration(min(240, max(1, $0))) }))
                        phaseName("Long break name", phase: .longBreak)
                        Toggle("Use long breaks", isOn: Binding(get: { model.preset.longBreakEnabled }, set: { model.setCycle(short: Int(model.preset.shortBreak / 60), long: Int(model.preset.longBreak / 60), every: model.preset.longBreakEvery, enabled: $0) }))
                        minutes("Long break", value: Binding(get: { Int(model.preset.longBreak / 60) }, set: { model.setCycle(short: Int(model.preset.shortBreak / 60), long: min(240, max(1, $0)), every: model.preset.longBreakEvery, enabled: model.preset.longBreakEnabled) }))
                        HStack { Text("Long break after"); Spacer(); TextField("Sessions", value: Binding(get: { model.preset.longBreakEvery }, set: { model.setCycle(short: Int(model.preset.shortBreak / 60), long: Int(model.preset.longBreak / 60), every: min(20, max(1, $0)), enabled: model.preset.longBreakEnabled) }), format: .number).labelsHidden().textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 65); Text("sessions").foregroundStyle(.secondary) }
                        Toggle("Automatically start work", isOn: Binding(get: { model.preset.autoWork }, set: { model.setAuto(work: $0, breaks: model.preset.autoBreak) }))
                        Toggle("Automatically start breaks", isOn: Binding(get: { model.preset.autoBreak }, set: { model.setAuto(work: model.preset.autoWork, breaks: $0) }))
                        Button("Restart entire cycle") { model.restart() }
                    }
                }
                Section("Reminders") {
                    Picker("Sound", selection: Binding(get: { model.preset.soundName }, set: { model.setSoundName($0) })) { ForEach(["Glass", "Ping", "Sosumi"], id: \.self) { Text($0) } }
                    Toggle("Work sound", isOn: Binding(get: { model.preset.workSound }, set: { model.setReminders(workSound: $0, workNotification: model.preset.workNotification, breakSound: model.preset.breakSound, breakNotification: model.preset.breakNotification) }))
                    Toggle("Work notification", isOn: Binding(get: { model.preset.workNotification }, set: { model.setReminders(workSound: model.preset.workSound, workNotification: $0, breakSound: model.preset.breakSound, breakNotification: model.preset.breakNotification) }))
                    Toggle("Break sound", isOn: Binding(get: { model.preset.breakSound }, set: { model.setReminders(workSound: model.preset.workSound, workNotification: model.preset.workNotification, breakSound: $0, breakNotification: model.preset.breakNotification) }))
                    Toggle("Break notification", isOn: Binding(get: { model.preset.breakNotification }, set: { model.setReminders(workSound: model.preset.workSound, workNotification: model.preset.workNotification, breakSound: model.preset.breakSound, breakNotification: $0) }))
                }
                Section("Focus") {
                    TextField("Shortcut name", text: Binding(get: { model.preset.focusShortcut }, set: { model.setFocusShortcut($0) }))
                    Button("Test shortcut") { model.testFocusShortcut() }
                    Text("\(model.focusMessage) Automatic Focus activation and restoration are unavailable until shortcut cancellation and mode identity can be verified.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Window & menu bar") {
                    Toggle("Always on top", isOn: Binding(get: { model.presentation.floating }, set: { model.setPresentation(floating: $0, overFullScreen: model.presentation.overFullScreen, menuBar: model.presentation.menuBar, showTime: model.presentation.showTime) }))
                    Toggle("Show over full-screen apps", isOn: Binding(get: { model.presentation.overFullScreen }, set: { model.setPresentation(floating: model.presentation.floating, overFullScreen: $0, menuBar: model.presentation.menuBar, showTime: model.presentation.showTime) }))
                    Toggle("Show in menu bar", isOn: Binding(get: { model.presentation.menuBar }, set: { model.setPresentation(floating: model.presentation.floating, overFullScreen: model.presentation.overFullScreen, menuBar: $0, showTime: model.presentation.showTime) }))
                    Toggle("Show time in menu bar", isOn: Binding(get: { model.presentation.showTime }, set: { model.setPresentation(floating: model.presentation.floating, overFullScreen: model.presentation.overFullScreen, menuBar: model.presentation.menuBar, showTime: $0) }))
                }
            }.formStyle(.grouped)
        }.frame(width: 520, height: 640)
    }
}

@main
struct TometoClockApp: App {
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = TimerModel()
    var body: some Scene {
        Window("TometoClock", id: "main") { ContentView(model: model).onAppear { appDelegate.reopen = { openWindow(id: "main") } } }
            .windowResizability(.contentSize)
            .defaultSize(width: 330, height: 320)
        MenuBarExtra(isInserted: Binding(get: { model.presentation.menuBar }, set: { model.setPresentation(floating: model.presentation.floating, overFullScreen: model.presentation.overFullScreen, menuBar: $0, showTime: model.presentation.showTime) })) {
            Button(model.state == .running ? "Pause" : "Start / Resume") { model.toggle() }
            if model.phase != .standalone { Button("Skip") { model.skip() } }
            Button("Open Window") { openWindow(id: "main"); NSApplication.shared.activate(ignoringOtherApps: true) }
            Button("Quit") { model.quit() }
        } label: {
            if model.presentation.showTime {
                Image(nsImage: model.menuBarImage)
                    .accessibilityLabel("Time remaining: \(model.seconds / 60) minutes \(model.seconds % 60) seconds")
            }
            else { Image(systemName: "timer") }
        }
    }
}
