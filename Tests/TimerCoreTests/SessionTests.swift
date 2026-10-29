import Testing
import Foundation
@testable import TimerCore

@Test func startCountsDownFromTwentyFiveMinutes() {
    let start = Date(timeIntervalSince1970: 0)
    let session = Session()
    session.start(at: start)
    #expect(session.remaining(at: start.addingTimeInterval(10)) == 1490)
}

@Test func pauseFreezesTimeAndResumeContinues() {
    let start = Date(timeIntervalSince1970: 0)
    let session = Session()
    session.start(at: start)
    session.pause(at: start.addingTimeInterval(100))
    #expect(session.remaining(at: start.addingTimeInterval(200)) == 1400)
    session.start(at: start.addingTimeInterval(200))
    #expect(session.remaining(at: start.addingTimeInterval(210)) == 1390)
}

@Test func resetStopsAndRestoresDuration() {
    let start = Date(timeIntervalSince1970: 0)
    let session = Session()
    session.start(at: start)
    session.reset()
    #expect(session.remaining(at: start.addingTimeInterval(100)) == 1500)
    #expect(session.state == .ready)
}

@Test func elapsedCountdownCompletesAndStaysCompleted() {
    let start = Date(timeIntervalSince1970: 0)
    let session = Session()
    session.start(at: start)
    session.update(at: start.addingTimeInterval(1501))
    #expect(session.state == .completed)
    #expect(session.remaining(at: start.addingTimeInterval(3000)) == 0)
}

@Test func presetsAndTitleSurviveRelaunchWithoutRunningTimer() throws {
    let store = MemoryStore()
    let session = Session(store: store)
    session.title = "Write"
    session.renamePreset(at: 2, to: "Deep work")
    session.selectPreset(at: 2)
    session.start(at: Date(timeIntervalSince1970: 0))
    let restored = Session(store: store)
    #expect(restored.title == "Write")
    #expect(restored.presets.count == 5)
    #expect(restored.presets[2].name == "Deep work")
    #expect(restored.selectedPreset == 2)
    #expect(restored.state == .ready)
}

@Test func editingDurationDoesNotChangeRunningOrPausedTimerUntilReset() {
    let start = Date(timeIntervalSince1970: 0)
    let session = Session()
    session.start(at: start)
    session.setDuration(600)
    session.pause(at: start.addingTimeInterval(100))
    #expect(session.remaining(at: start.addingTimeInterval(200)) == 1400)
    session.reset()
    #expect(session.remaining(at: start) == 600)
}

@Test func completedWorkSchedulesShortBreakAndCountsRound() {
    let start = Date(timeIntervalSince1970: 0)
    let session = Session()
    session.setCyclesEnabled(true)
    session.start(at: start)
    session.update(at: start.addingTimeInterval(1500))
    #expect(session.completedWork == 1)
    #expect(session.phase == .shortBreak)
    #expect(session.state == .ready)
    #expect(session.remaining(at: start.addingTimeInterval(1500)) == 300)
}

@Test func skippingWorkDoesNotCountAndSkippingBreakReturnsToReadyWork() {
    let session = Session()
    session.setCyclesEnabled(true)
    session.skip()
    #expect(session.completedWork == 0)
    #expect(session.phase == .shortBreak)
    session.skip()
    #expect(session.phase == .work)
    #expect(session.state == .ready)
}

@Test func completedBreakReturnsToWork() {
    let start = Date(timeIntervalSince1970: 0)
    let session = Session()
    session.setCyclesEnabled(true)
    session.skip()
    session.start(at: start)
    session.update(at: start.addingTimeInterval(300))
    #expect(session.phase == .work)
    #expect(session.state == .ready)
    #expect(session.remaining(at: start.addingTimeInterval(300)) == 1500)
}

@Test func fourthCompletedWorkSchedulesLongBreakAndCompletingItClearsRounds() {
    let session = Session()
    session.setCyclesEnabled(true)
    var now = Date(timeIntervalSince1970: 0)
    for round in 1...4 {
        session.start(at: now)
        now = now.addingTimeInterval(1500)
        session.update(at: now)
        if round < 4 { session.skip() }
    }
    #expect(session.phase == .longBreak)
    #expect(session.completedWork == 4)
    #expect(session.remaining(at: now) == 900)
    session.start(at: now)
    now = now.addingTimeInterval(900)
    session.update(at: now)
    #expect(session.completedWork == 0)
    #expect(session.phase == .work)
}

@Test func resetPreservesRoundsAndRestartClearsThem() {
    let now = Date(timeIntervalSince1970: 0)
    let session = Session()
    session.setCyclesEnabled(true)
    session.start(at: now)
    session.update(at: now.addingTimeInterval(1500))
    session.reset()
    #expect(session.completedWork == 1)
    #expect(session.phase == .shortBreak)
    #expect(session.remaining(at: now) == 300)
    session.restartCycle()
    #expect(session.completedWork == 0)
    #expect(session.phase == .work)
}

@Test func cycleUsesConfiguredBreakAndLongBreakInterval() {
    let session = Session()
    session.setCyclesEnabled(true)
    session.configureCycle(shortBreak: 120, longBreak: 420, longBreakEvery: 2, longBreakEnabled: true)
    var now = Date(timeIntervalSince1970: 0)
    session.start(at: now); now = now.addingTimeInterval(1500); session.update(at: now)
    #expect(session.remaining(at: now) == 120)
    session.skip()
    session.start(at: now); now = now.addingTimeInterval(1500); session.update(at: now)
    #expect(session.phase == .longBreak)
    #expect(session.remaining(at: now) == 420)
}

@Test func skippingLongBreakStartsANewRoundGroup() {
    let session = Session()
    session.setCyclesEnabled(true)
    session.configureCycle(shortBreak: 300, longBreak: 900, longBreakEvery: 1, longBreakEnabled: true)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now); session.update(at: now.addingTimeInterval(1500))
    session.skip()
    #expect(session.phase == .work)
    #expect(session.completedWork == 0)
}

@Test func automaticBreakStartsButSkippedBreakDoesNotStartWork() {
    let session = Session()
    session.setCyclesEnabled(true)
    session.setAutomaticStarts(work: true, breaks: true)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.update(at: now.addingTimeInterval(1500))
    #expect(session.phase == .shortBreak)
    #expect(session.state == .running)
    session.skip()
    #expect(session.phase == .work)
    #expect(session.state == .ready)
}

@Test func transitionRulesAreSnapshottedWhenWorkStarts() {
    let session = Session()
    session.setCyclesEnabled(true)
    session.setAutomaticStarts(work: false, breaks: false)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.setAutomaticStarts(work: false, breaks: true)
    session.update(at: now.addingTimeInterval(1500))
    #expect(session.phase == .shortBreak)
    #expect(session.state == .ready)
}

@Test func wakeAfterDeadlineCompletesOnlyCurrentPhaseWithoutAutomaticTransition() {
    let session = Session()
    session.setCyclesEnabled(true)
    session.setAutomaticStarts(work: true, breaks: true)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.wake(at: now.addingTimeInterval(10000))
    #expect(session.phase == .work)
    #expect(session.state == .completed)
    #expect(session.completedWork == 1)
    session.wake(at: now.addingTimeInterval(11000))
    #expect(session.completedWork == 1)
}

@Test func restoredCyclePresetStartsReadyAtWork() {
    let store = MemoryStore()
    let session = Session(store: store)
    session.setCyclesEnabled(true)
    let restored = Session(store: store)
    #expect(restored.phase == .work)
    #expect(restored.state == .ready)
}

@Test func switchingPresetWhileReadyAppliesItsModeAndDuration() {
    let session = Session()
    session.selectPreset(at: 1)
    session.setCyclesEnabled(true)
    session.setWorkDuration(600)
    session.selectPreset(at: 0)
    #expect(session.phase == .standalone)
    #expect(session.remaining(at: Date(timeIntervalSince1970: 0)) == 1500)
    session.selectPreset(at: 1)
    #expect(session.phase == .work)
    #expect(session.remaining(at: Date(timeIntervalSince1970: 0)) == 600)
}

@Test func completionReportsConfiguredReminderOnce() {
    var reminders: [Session.Reminder] = []
    let session = Session(onCompletion: { reminders.append($0) })
    session.setReminders(workSound: true, workNotification: false, breakSound: false, breakNotification: false)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.update(at: now.addingTimeInterval(1500))
    session.update(at: now.addingTimeInterval(1600))
    #expect(reminders.count == 1)
    #expect(reminders.first?.sound == true)
    #expect(reminders.first?.notification == false)
}

@Test func breakUsesItsOwnReminderSettings() {
    var reminders: [Session.Reminder] = []
    let session = Session(onCompletion: { reminders.append($0) })
    session.setReminders(workSound: false, workNotification: false, breakSound: true, breakNotification: true)
    session.setCyclesEnabled(true)
    session.skip()
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now); session.update(at: now.addingTimeInterval(300))
    #expect(reminders.first?.phase == .shortBreak)
    #expect(reminders.first?.sound == true)
    #expect(reminders.first?.notification == true)
}

@Test func presentationPreferencesSurviveRelaunch() {
    let store = MemoryStore()
    let session = Session(store: store)
    session.setPresentation(floating: true, overFullScreen: true, menuBar: true, showTime: false)
    let restored = Session(store: store)
    #expect(restored.presentation.floating)
    #expect(restored.presentation.overFullScreen)
    #expect(restored.presentation.menuBar)
    #expect(!restored.presentation.showTime)
}

@Test func expiredPhaseOnWakeReportsCompletionOnce() {
    var reminders: [Session.Reminder] = []
    let session = Session(onCompletion: { reminders.append($0) })
    session.setReminders(workSound: true, workNotification: false, breakSound: false, breakNotification: false)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.wake(at: now.addingTimeInterval(1500))
    session.wake(at: now.addingTimeInterval(1600))
    #expect(reminders.count == 1)
    #expect(reminders.first?.sound == true)
}

@Test func changingWorkDurationWhileBreakIsReadyDoesNotChangeBreak() {
    let session = Session()
    session.setCyclesEnabled(true)
    session.skip()
    session.setDuration(600)
    #expect(session.phase == .shortBreak)
    #expect(session.remaining(at: Date(timeIntervalSince1970: 0)) == 300)
}

@Test func selectingStandaloneDuringWorkAppliesAtNextPhase() {
    let session = Session()
    session.setCyclesEnabled(true)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.selectPreset(at: 1)
    session.update(at: now.addingTimeInterval(1500))
    #expect(session.phase == .standalone)
    #expect(session.state == .ready)
    #expect(session.remaining(at: now.addingTimeInterval(1500)) == 1500)
}

@Test func resettingAfterSelectingStandaloneAppliesNewMode() {
    let session = Session()
    session.setCyclesEnabled(true)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.selectPreset(at: 1)
    session.reset()
    #expect(session.phase == .standalone)
    #expect(session.state == .ready)
}

@Test func selectedSoundIsIncludedInCompletion() {
    var reminders: [Session.Reminder] = []
    let session = Session(onCompletion: { reminders.append($0) })
    session.setSoundName("Ping")
    session.setReminders(workSound: true, workNotification: false, breakSound: false, breakNotification: false)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now); session.update(at: now.addingTimeInterval(1500))
    #expect(reminders.first?.soundName == "Ping")
}

@Test func olderSavedPresetsRetainTitleAndNamesWhenNewSettingsAreAdded() {
    let store = MemoryStore()
    store.save(Data(#"{"title":"Writing","selected":0,"presets":[{"name":"A","duration":600},{"name":"B","duration":1500},{"name":"C","duration":1500},{"name":"D","duration":1500},{"name":"E","duration":1500}]}"#.utf8))
    let restored = Session(store: store)
    #expect(restored.title == "Writing")
    #expect(restored.presets[0].name == "A")
    #expect(restored.remaining(at: Date(timeIntervalSince1970: 0)) == 600)
}

@Test func focusShortcutPreferenceIsSavedPerPreset() {
    let store = MemoryStore()
    let session = Session(store: store)
    session.setFocusShortcut("Work Focus")
    session.selectPreset(at: 1)
    #expect(session.presets[1].focusShortcut == "")
    let restored = Session(store: store)
    #expect(restored.presets[0].focusShortcut == "Work Focus")
}

@Test func pausingAfterDeadlineCompletesInsteadOfCreatingZeroLengthPause() {
    let session = Session()
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.pause(at: now.addingTimeInterval(1501))
    #expect(session.state == .completed)
    #expect(session.remaining(at: now.addingTimeInterval(1501)) == 0)
}

@Test func standaloneAndWorkDurationsAreIndependent() {
    let session = Session()
    let now = Date(timeIntervalSince1970: 0)
    session.setDuration(600)
    session.setCyclesEnabled(true)
    #expect(session.remaining(at: now) == 1500)
    session.setWorkDuration(1200)
    #expect(session.remaining(at: now) == 1200)
    session.setCyclesEnabled(false)
    #expect(session.remaining(at: now) == 600)
}

@Test func disabledLongBreakKeepsSchedulingShortBreaks() {
    let session = Session()
    session.setCyclesEnabled(true)
    session.configureCycle(shortBreak: 300, longBreak: 900, longBreakEvery: 1, longBreakEnabled: false)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.update(at: now.addingTimeInterval(1500))
    #expect(session.phase == .shortBreak)
    #expect(session.completedWork == 1)
}

@Test func selectingStandaloneDuringBreakAppliesAtNextPhase() {
    let session = Session()
    session.setCyclesEnabled(true)
    session.skip()
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.selectPreset(at: 1)
    session.update(at: now.addingTimeInterval(300))
    #expect(session.phase == .standalone)
    #expect(session.state == .ready)
    #expect(session.remaining(at: now.addingTimeInterval(300)) == 1500)
}

@Test func cycleCompletionRemainsObservableWhenRemindersAreSilent() {
    let session = Session()
    session.setCyclesEnabled(true)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.update(at: now.addingTimeInterval(1500))
    #expect(session.lastCompletedPhase == .work)
    session.start(at: now.addingTimeInterval(1500))
    #expect(session.lastCompletedPhase == nil)
}

@Test func quitClearsActiveTimerAndRoundsButKeepsPreferences() {
    let store = MemoryStore()
    let session = Session(store: store)
    session.setCyclesEnabled(true)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now); session.update(at: now.addingTimeInterval(1500))
    session.start(at: now.addingTimeInterval(1500))
    session.quit()
    #expect(session.state == .ready)
    #expect(session.completedWork == 0)
    #expect(session.phase == .work)
    #expect(Session(store: store).presets[0].cyclesEnabled)
}

@Test func skippingWorkAfterSwitchingToStandaloneUsesNewPreset() {
    let session = Session()
    session.setCyclesEnabled(true)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.selectPreset(at: 1)
    session.skip()
    #expect(session.phase == .standalone)
    #expect(session.state == .ready)
    #expect(session.completedWork == 0)
}

@Test func completionRemainsVisibleWhenNextBreakStartsAutomatically() {
    let session = Session()
    session.setCyclesEnabled(true)
    session.setAutomaticStarts(work: false, breaks: true)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now); session.update(at: now.addingTimeInterval(1500))
    #expect(session.state == .running)
    #expect(session.lastCompletedPhase == .work)
}

@Test func standaloneCompletionCanSwitchToReadyBreak() {
    let session = Session()
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.update(at: now.addingTimeInterval(1500))
    session.advanceAfterCompletion()
    #expect(session.phase == .shortBreak)
    #expect(session.state == .ready)
    #expect(session.remaining(at: now.addingTimeInterval(1500)) == 300)
}

@Test func phaseNamesAreSavedPerPresetAndRestored() {
    let store = MemoryStore()
    let session = Session(store: store)
    session.setPhaseName(.work, name: "Deep work")
    session.setPhaseName(.shortBreak, name: "Coffee")
    let restored = Session(store: store)
    #expect(restored.phaseName(.work) == "Deep work")
    #expect(restored.phaseName(.shortBreak) == "Coffee")
    restored.selectPreset(at: 1)
    #expect(restored.phaseName(.work) == "Work")
}

@Test func resettingManualBreakKeepsTheBreakPhase() {
    let session = Session()
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now); session.update(at: now.addingTimeInterval(1500))
    session.advanceAfterCompletion()
    session.start(at: now.addingTimeInterval(1500))
    session.reset()
    #expect(session.phase == .shortBreak)
    #expect(session.remaining(at: now) == 300)
    #expect(session.state == .ready)
}

@Test func manualBreakCompletesAndReturnsToStandaloneWork() {
    let session = Session()
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now); session.update(at: now.addingTimeInterval(1500))
    session.advanceAfterCompletion()
    session.start(at: now.addingTimeInterval(1500))
    session.update(at: now.addingTimeInterval(1800))
    #expect(session.phase == .standalone)
    #expect(session.state == .ready)
    #expect(session.remaining(at: now) == 1500)
}

@Test func resettingManualBreakAfterChangingPresetUsesNewPreset() {
    let session = Session()
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now); session.update(at: now.addingTimeInterval(1500))
    session.advanceAfterCompletion()
    session.start(at: now.addingTimeInterval(1500))
    session.selectPreset(at: 1)
    session.reset()
    #expect(session.phase == .standalone)
    #expect(session.remaining(at: now) == 1500)
}

@Test func switchingPresetsStopsAndRestartsFromNewPreset() {
    let session = Session()
    session.selectPreset(at: 1)
    session.setDuration(600)
    session.selectPreset(at: 0)
    let now = Date(timeIntervalSince1970: 0)
    session.start(at: now)
    session.selectPreset(at: 1)
    #expect(session.state == .ready)
    #expect(session.phase == .standalone)
    #expect(session.remaining(at: now.addingTimeInterval(100)) == 600)
    #expect(session.completedWork == 0)
}
