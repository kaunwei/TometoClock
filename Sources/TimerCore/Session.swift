import Foundation

public protocol SettingsStore: AnyObject {
    func load() -> Data?
    func save(_ data: Data)
}
public final class MemoryStore: SettingsStore {
    private var data: Data?
    public init() {}
    public func load() -> Data? { data }
    public func save(_ data: Data) { self.data = data }
}
public struct Preset: Codable {
    public var name: String
    public var duration: TimeInterval = 1500
    public var workDuration: TimeInterval = 1500
    public var cyclesEnabled = false
    public var shortBreak: TimeInterval = 300
    public var longBreak: TimeInterval = 900
    public var longBreakEvery = 4
    public var longBreakEnabled = true
    public var autoWork = false
    public var autoBreak = false
    public var workName = "Work"
    public var shortBreakName = "Short break"
    public var longBreakName = "Long break"
    public var focusShortcut = ""
    public var soundName = "Glass"
    public var workSound = false
    public var workNotification = false
    public var breakSound = false
    public var breakNotification = false
    public init(name: String) { self.name = name }
    private enum CodingKeys: String, CodingKey { case workName, shortBreakName, longBreakName, focusShortcut, name, duration, workDuration, cyclesEnabled, shortBreak, longBreak, longBreakEvery, longBreakEnabled, autoWork, autoBreak, soundName, workSound, workNotification, breakSound, breakNotification }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        workName = try values.decodeIfPresent(String.self, forKey: .workName) ?? "Work"
        shortBreakName = try values.decodeIfPresent(String.self, forKey: .shortBreakName) ?? "Short break"
        longBreakName = try values.decodeIfPresent(String.self, forKey: .longBreakName) ?? "Long break"
        focusShortcut = try values.decodeIfPresent(String.self, forKey: .focusShortcut) ?? ""
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? "Preset"
        duration = try values.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 1500
        workDuration = try values.decodeIfPresent(TimeInterval.self, forKey: .workDuration) ?? 1500
        cyclesEnabled = try values.decodeIfPresent(Bool.self, forKey: .cyclesEnabled) ?? false
        shortBreak = try values.decodeIfPresent(TimeInterval.self, forKey: .shortBreak) ?? 300
        longBreak = try values.decodeIfPresent(TimeInterval.self, forKey: .longBreak) ?? 900
        longBreakEvery = try values.decodeIfPresent(Int.self, forKey: .longBreakEvery) ?? 4
        longBreakEnabled = try values.decodeIfPresent(Bool.self, forKey: .longBreakEnabled) ?? true
        autoWork = try values.decodeIfPresent(Bool.self, forKey: .autoWork) ?? false
        autoBreak = try values.decodeIfPresent(Bool.self, forKey: .autoBreak) ?? false
        soundName = try values.decodeIfPresent(String.self, forKey: .soundName) ?? "Glass"
        workSound = try values.decodeIfPresent(Bool.self, forKey: .workSound) ?? false
        workNotification = try values.decodeIfPresent(Bool.self, forKey: .workNotification) ?? false
        breakSound = try values.decodeIfPresent(Bool.self, forKey: .breakSound) ?? false
        breakNotification = try values.decodeIfPresent(Bool.self, forKey: .breakNotification) ?? false
    }
}
public struct Presentation: Codable {
    public var floating = false
    public var overFullScreen = false
    public var menuBar = false
    public var showTime = true
    public init() {}
}
private struct SavedSettings: Codable {
    var title: String
    var presets: [Preset]
    var selected: Int
    var presentation: Presentation
    enum CodingKeys: String, CodingKey { case title, presets, selected, presentation }
    init(title: String, presets: [Preset], selected: Int, presentation: Presentation) {
        self.title = title; self.presets = presets; self.selected = selected; self.presentation = presentation
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decode(String.self, forKey: .title)
        presets = try values.decode([Preset].self, forKey: .presets)
        selected = try values.decode(Int.self, forKey: .selected)
        presentation = try values.decodeIfPresent(Presentation.self, forKey: .presentation) ?? Presentation()
    }
}
public final class Session {
    public struct Reminder { public let sound: Bool; public let notification: Bool; public let phase: Phase; public let soundName: String }
    private let onCompletion: (Reminder) -> Void
    public enum Phase { case standalone, work, shortBreak, longBreak }
    public private(set) var phase: Phase = .standalone
    public private(set) var completedWork = 0
    public private(set) var lastCompletedPhase: Phase?
    public enum State { case ready, running, paused, completed }
    public private(set) var state: State = .ready
    private var phaseSettings: Preset?
    private var manualBreak = false
    private var deadline: Date?
    private var frozen: TimeInterval = 1500
    private let store: SettingsStore?
    public var title: String = "" { didSet { save() } }
    public private(set) var presets = (1...5).map { Preset(name: "Preset \($0)") }
    public private(set) var selectedPreset = 0
    public private(set) var presentation = Presentation()
    public init(store: SettingsStore? = nil, onCompletion: @escaping (Reminder) -> Void = { _ in }) {
        self.store = store
        self.onCompletion = onCompletion
        if let data = store?.load(), let saved = try? JSONDecoder().decode(SavedSettings.self, from: data), saved.presets.count == 5, (0..<5).contains(saved.selected) {
            title = saved.title; presentation = saved.presentation; presets = saved.presets; selectedPreset = saved.selected; phase = presets[selectedPreset].cyclesEnabled ? .work : .standalone; frozen = phase == .work ? presets[selectedPreset].workDuration : presets[selectedPreset].duration
        }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(SavedSettings(title: title, presets: presets, selected: selectedPreset, presentation: presentation)) { store?.save(data) }
    }
    public func renamePreset(at index: Int, to name: String) { guard presets.indices.contains(index) else { return }; presets[index].name = name; save() }
    public func selectPreset(at index: Int) {
        guard presets.indices.contains(index), selectedPreset != index else { return }
        selectedPreset = index
        restartCycle()
        save()
    }
    public func setPresentation(floating: Bool, overFullScreen: Bool, menuBar: Bool, showTime: Bool) {
        presentation.floating = floating; presentation.overFullScreen = overFullScreen; presentation.menuBar = menuBar; presentation.showTime = showTime; save()
    }
    public func phaseName(_ phase: Phase) -> String {
        let preset = presets[selectedPreset]
        switch phase {
        case .standalone, .work: return preset.workName
        case .shortBreak: return preset.shortBreakName
        case .longBreak: return preset.longBreakName
        }
    }
    public func setPhaseName(_ phase: Phase, name: String) {
        switch phase {
        case .standalone, .work: presets[selectedPreset].workName = name
        case .shortBreak: presets[selectedPreset].shortBreakName = name
        case .longBreak: presets[selectedPreset].longBreakName = name
        }
        save()
    }
    public func setFocusShortcut(_ name: String) { presets[selectedPreset].focusShortcut = name; save() }
    public func setSoundName(_ name: String) { guard ["Glass", "Ping", "Sosumi"].contains(name) else { return }; presets[selectedPreset].soundName = name; save() }
    public func setReminders(workSound: Bool, workNotification: Bool, breakSound: Bool, breakNotification: Bool) {
        presets[selectedPreset].workSound = workSound; presets[selectedPreset].workNotification = workNotification
        presets[selectedPreset].breakSound = breakSound; presets[selectedPreset].breakNotification = breakNotification; save()
    }
    public func setAutomaticStarts(work: Bool, breaks: Bool) { presets[selectedPreset].autoWork = work; presets[selectedPreset].autoBreak = breaks; save() }
    public func configureCycle(shortBreak: TimeInterval, longBreak: TimeInterval, longBreakEvery: Int, longBreakEnabled: Bool) {
        presets[selectedPreset].shortBreak = max(1, shortBreak)
        presets[selectedPreset].longBreak = max(1, longBreak)
        presets[selectedPreset].longBreakEvery = max(1, longBreakEvery)
        presets[selectedPreset].longBreakEnabled = longBreakEnabled
        save()
    }
    public func setCyclesEnabled(_ enabled: Bool) { presets[selectedPreset].cyclesEnabled = enabled; save(); if state == .ready { phase = enabled ? .work : .standalone; frozen = enabled ? presets[selectedPreset].workDuration : presets[selectedPreset].duration } }
    public func setDuration(_ duration: TimeInterval) { presets[selectedPreset].duration = max(1, duration); save(); if state == .ready && phase == .standalone { frozen = presets[selectedPreset].duration } }
    public func setWorkDuration(_ duration: TimeInterval) { presets[selectedPreset].workDuration = max(1, duration); save(); if state == .ready && phase == .work { frozen = presets[selectedPreset].workDuration } }
    public func start(at date: Date) {
        guard state == .ready || state == .paused else { return }
        if state == .ready { phaseSettings = presets[selectedPreset]; lastCompletedPhase = nil }
        deadline = date.addingTimeInterval(frozen)
        state = .running
    }
    public func pause(at date: Date) {
        guard state == .running else { return }
        if remaining(at: date) == 0 { update(at: date); return }
        frozen = remaining(at: date); deadline = nil; state = .paused
    }
    public func wake(at date: Date) {
        guard state == .running, remaining(at: date) == 0 else { return }
        lastCompletedPhase = phase
        let settings = phaseSettings ?? presets[selectedPreset]
        let isBreak = phase == .shortBreak || phase == .longBreak
        onCompletion(Reminder(sound: isBreak ? settings.breakSound : settings.workSound, notification: isBreak ? settings.breakNotification : settings.workNotification, phase: phase, soundName: settings.soundName))
        deadline = nil; frozen = 0; state = .completed
        if phase == .work { completedWork += 1 }
        if phase == .longBreak { completedWork = 0 }
    }
    public func update(at date: Date) {
        if state == .running && remaining(at: date) == 0 {
            lastCompletedPhase = phase
            let settings = phaseSettings ?? presets[selectedPreset]
            let isBreak = phase == .shortBreak || phase == .longBreak
            onCompletion(Reminder(sound: isBreak ? settings.breakSound : settings.workSound, notification: isBreak ? settings.breakNotification : settings.workNotification, phase: phase, soundName: settings.soundName))
            deadline = nil; frozen = 0; state = .completed
            if phase == .work && !presets[selectedPreset].cyclesEnabled {
                completedWork += 1
                phase = .standalone; frozen = presets[selectedPreset].duration; state = .ready
            } else if phase == .work {
                completedWork += 1; phase = settings.longBreakEnabled && completedWork >= settings.longBreakEvery ? .longBreak : .shortBreak; frozen = phase == .longBreak ? presets[selectedPreset].longBreak : presets[selectedPreset].shortBreak; state = .ready
                if settings.autoBreak { let completed = lastCompletedPhase; start(at: date); lastCompletedPhase = completed }
            } else if phase == .shortBreak || phase == .longBreak {
                if phase == .longBreak { completedWork = 0 }
                manualBreak = false
                phase = presets[selectedPreset].cyclesEnabled ? .work : .standalone
                frozen = phase == .work ? presets[selectedPreset].workDuration : presets[selectedPreset].duration
                state = .ready
                if phase == .work && settings.autoWork { let completed = lastCompletedPhase; start(at: date); lastCompletedPhase = completed }
            }
        }
    }
    public func advanceAfterCompletion() {
        guard state == .completed else { return }
        switch phase {
        case .standalone, .work:
            manualBreak = phase == .standalone
            phase = .shortBreak; frozen = presets[selectedPreset].shortBreak
        case .shortBreak, .longBreak:
            manualBreak = false
            phase = presets[selectedPreset].cyclesEnabled ? .work : .standalone
            frozen = phase == .work ? presets[selectedPreset].workDuration : presets[selectedPreset].duration
        }
        lastCompletedPhase = nil
        state = .ready
    }
    public func skip() {
        switch phase {
        case .standalone: return
        case .work:
            phase = presets[selectedPreset].cyclesEnabled ? .shortBreak : .standalone
            frozen = phase == .shortBreak ? presets[selectedPreset].shortBreak : presets[selectedPreset].duration
        case .shortBreak, .longBreak:
            if phase == .longBreak { completedWork = 0 }
            manualBreak = false
            phase = presets[selectedPreset].cyclesEnabled ? .work : .standalone
            frozen = phase == .work ? presets[selectedPreset].workDuration : presets[selectedPreset].duration
        }
        deadline = nil; state = .ready
    }
    public func reset() {
        lastCompletedPhase = nil
        deadline = nil
        if !presets[selectedPreset].cyclesEnabled && !manualBreak { phase = .standalone }
        else if phase == .standalone { phase = .work }
        switch phase {
        case .shortBreak: frozen = presets[selectedPreset].shortBreak
        case .longBreak: frozen = presets[selectedPreset].longBreak
        case .work: frozen = presets[selectedPreset].workDuration
        case .standalone: frozen = presets[selectedPreset].duration
        }
        state = .ready
    }
    public func quit() { restartCycle() }
    public func restartCycle() { manualBreak = false; completedWork = 0; phase = presets[selectedPreset].cyclesEnabled ? .work : .standalone; reset() }
    public func remaining(at date: Date) -> TimeInterval {
        max(0, deadline?.timeIntervalSince(date) ?? frozen)
    }
}

public final class DefaultsStore: SettingsStore {
    private let defaults: UserDefaults
    private let key: String
    public init(defaults: UserDefaults = .standard, key: String = "TometoClock.settings") {
        self.defaults = defaults; self.key = key
    }
    public func load() -> Data? { defaults.data(forKey: key) }
    public func save(_ data: Data) { defaults.set(data, forKey: key) }
}
