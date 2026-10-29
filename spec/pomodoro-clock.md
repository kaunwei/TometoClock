# TometoClock: Native macOS Countdown and Pomodoro Timer

## Problem Statement

A Mac user needs a small, unobtrusive timer for focused work that remembers personal preferences, optionally organizes work and breaks, and integrates with their desktop without wasting battery or memory.

## Solution

Build a local-only Swift and SwiftUI macOS application. The default experience is a single 25-minute countdown. The main page contains a work title, remaining time, one context-sensitive timer button, and a settings entry. A second page exposes optional Pomodoro cycles, five named presets, reminders, desktop presentation, and Shortcuts-based Focus integration.

## User Stories

1. As a user, I want a 25-minute standalone countdown by default, so that I can start without configuring a routine.
2. As a user, I want to enter an optional work title, so that I can identify my current task.
3. As a user, I want one button to start, pause, and resume, so that the main page stays simple.
4. As a user, I want to hold that button for two seconds to reset, so that I do not need a separate reset button.
5. As a user, I want a filling animation and cancellation when I release early, so that reset is deliberate.
6. As a user, I want a separate settings page, so that advanced controls do not clutter the timer.
7. As a user, I want to configure countdown duration, so that the timer fits my work.
8. As a user, I want optional work and break cycles, so that I can follow a Pomodoro routine.
9. As a user, I want configurable work, short-break, and long-break durations, so that I can tune my routine.
10. As a user, I want a long break after N completed work sessions and an option to disable it, so that I control recovery periods.
11. As a user, I want independent automatic-start controls for work and breaks, so that transitions suit my pace.
12. As a user, I want to skip a phase without counting unfinished work, so that interruptions do not inflate progress.
13. As a user, I want phase reset to preserve completed rounds and a separate restart-cycle action, so that I control how much progress is discarded.
14. As a user, I want five named preset slots with automatic saving, so that I can reuse different routines.
15. As a user, I want the last selected preset and work title restored after relaunch, so that setup is minimal.
16. As a user, I want ongoing countdowns protected from settings changes, so that changes do not unexpectedly alter my current phase.
17. As a user, I want optional always-on-top presentation, so that time remains visible over other apps.
18. As a user, I want a separate full-screen visibility option, so that I control interruptions.
19. As a user, I want an optional menu bar item with icon-only or icon-and-time presentation, so that I can monitor time unobtrusively.
20. As a user, I want menu bar timer controls, so that I can operate the timer without opening its window.
21. As a user, I want separate sound and notification settings for work and break completion, so that reminders match my environment.
22. As a user, I want a silent mode and one-shot sounds that respect system volume, so that the app does not disturb others.
23. As a user, I want an optional shortcut to enable my chosen Focus mode when work starts, so that distractions are reduced.
24. As a user, I want safe conditional Focus restoration, so that the app respects my manual changes.
25. As a user, I want countdowns to continue if a shortcut fails, so that system integration does not block work.
26. As a user, I want closing the window to preserve timing, so that I can clear my desktop.
27. As a user, I want normal system sleep without wake requests, so that battery life takes priority.
28. As a user, I want elapsed time reconciled on wake without accumulating multiple rounds, so that sleep does not produce fictitious progress.
29. As a user, I want quitting to stop the session and relaunch to wait for my input, so that timers never restart unexpectedly.
30. As a user, I want a native appearance following system light and dark modes, so that the app feels at home on macOS.
31. As a user, I want local storage without accounts or syncing, so that the app remains lightweight.

## Implementation Decisions

- Use Swift and SwiftUI with AppKit integration where window and menu bar behavior require it. No application code, project glossary, ADRs, or existing tests are present.
- The user's target machine runs macOS 27. Select the minimum deployment target during implementation based on verified API availability and maintenance cost; compatibility with older releases is not a product requirement.
- Define phases as standalone countdown, work, short break, and long break. Define timer states as ready, running, paused, and completed. A single application session coordinates every UI surface.
- Main-page time is read-only. Its single button changes between Start, Pause, and Resume. Holding it for two seconds fills a progress indicator and resets the current phase to its configured duration, stopped. Early release cancels reset. A recognized hold must never also fire the click action.
- The work title is optional, persists independently of presets, survives relaunch, and is unaffected by preset switching.
- Defaults: standalone countdown 25 minutes; cycles disabled. Cycle defaults when enabled: work 25 minutes, short break 5 minutes, long break 15 minutes after 4 completed work sessions. Long breaks are optional. Automatic work and break starts are separate settings, both off by default.
- Count only fully completed work phases. Resetting a phase preserves the count; restarting the entire cycle or quitting clears it. A completed long break resets the count. Skipped work never increments it. Skipping a break leads to the next work phase in a ready state even when automatic work start is enabled.
- Expose Skip through the menu bar and main-page context menu. Expose Restart Entire Cycle on the settings page. Define skipped-long-break handling explicitly during implementation; it must not strand long-break scheduling or count incomplete work.
- Provide exactly five renameable preset slots. Save changes automatically. Each stores timing, cycle rules, sounds, notifications, and Focus shortcut preferences. Always-on-top, full-screen visibility, and menu bar presentation are app-wide settings.
- Snapshot timing and transition preferences for the active phase. Edits and preset selection affect the next phase or next explicit reset/start, not an ongoing or paused countdown. Presentation settings apply immediately.
- Support an optional floating window, with a separate Show Over Full-Screen Apps switch off by default. Menu bar visibility is optional; when enabled its default format is icon plus remaining time, with icon-only available. Its menu includes Start, Pause/Resume, Open Window, Quit, and cycle Skip where applicable. Do not infer an initial on/off preference for menu bar or floating mode; choose and document a conservative initial presentation during implementation.
- Closing the window keeps the session running. With both window and menu bar hidden, reopening the app must reveal the window. Quitting stops the session; relaunch restores preferences and title but no active countdown or cycle progress.
- Store a deadline rather than decrementing a counter. Pause freezes remaining duration. Permit normal system sleep and never request a wake or prevent sleep. On wake, reconcile the deadline once; an expired phase becomes completed and does not trigger catch-up cycles or automatic follow-on phases. Sleep-time audio delivery is not guaranteed.
- Visible countdowns update at second-level precision. Stop presentation refreshes for hidden surfaces. Avoid continuous animation, polling for Focus changes, busy loops, background helpers, and unnecessary dependencies. Measure idle and hidden-running resource use; numeric budgets require baseline measurement rather than invented targets.
- Work and break completion have independent sound and notification controls. Both can be disabled. Provide a small selection of built-in sounds, played once at system volume. Keep completed state visible even with reminders disabled. Request notification permission only when relevant; denial must not block timing. Initial reminder defaults remain an implementation choice to document.
- Focus integration is opt-in and uses user-connected macOS Shortcuts, executed automatically on work start. Provide connection and test controls. Shortcut failure yields a concise non-blocking message and does not stop the timer.
- Public Focus-status APIs do not provide full mode selection or restoration. Verify shortcut execution, current-mode reporting, and sandbox behavior on the target OS before promising support. On completion or cancellation, restore only if the current mode still matches the app-selected mode and reliable state is available. Pause retains Focus. If reliable verification is unavailable, skip automatic restoration and explain the limitation. Switching away and back cannot reliably be distinguished from leaving the mode unchanged.
- Focus automation should be serialized with session transitions so that late shortcut results cannot change the system for a cancelled or superseded session. Validate permission and failure paths on a real Mac.
- Use local platform-native persistence. No account, network service, or cloud synchronization is required.

## Testing Decisions

- Prefer one high-level session seam: drive user commands, simulated time, persistence round trips, and observed session outputs through the application session boundary. Supply controlled time and recording adapters for system effects rather than testing private implementation details.
- Cover start, pause, resume, reset, completion, sleep reconciliation, cycle counting, long-break boundaries, skips, next-phase preference application, and quit/relaunch behavior using deterministic tests without real waits.
- Test persisted observable behavior: five slots, renaming, last selection, independent title, global presentation settings, and restoration without a running session.
- Verify shortcut failures and conditional restoration through controlled outcomes; real Shortcuts capabilities, permissions, and sandbox constraints require target-Mac integration checks.
- Use focused UI/manual checks for the two-second gesture, early release, absence of accidental clicks, menu controls, window lifecycle, full-screen visibility, reminders, and light/dark appearance.
- Profile visible, hidden-running, paused, idle, and sleep/wake scenarios on the target Mac. Check for unnecessary repeated work and memory growth. Do not assert absolute energy savings without measurements.
- No prior test suite exists. The session seam is proposed for this greenfield application and has not received separate user review; it is a planning recommendation, not an already approved implementation interface.

## Out of Scope

- iOS, iPadOS, watchOS, accounts, cloud sync, analytics dashboards, and work-history reporting.
- Private APIs for Focus control, bypassing system permissions, preventing sleep, or waking the Mac for reminders.
- Repeated alarms, forced volume changes, continuous decorative animations, and background timing after Quit.
- Application implementation or publishing as part of this documentation task.

## Further Notes

- This document synthesizes the user's confirmed interview answers. Remaining engineering choices are identified above rather than presented as user decisions.
- Apple references: [Focus status](https://developer.apple.com/documentation/intents/infocusstatuscenter), [running Shortcuts by URL](https://support.apple.com/guide/shortcuts-mac/run-a-shortcut-from-a-url-apd624386f42/mac), and [Shortcuts command line](https://support.apple.com/guide/shortcuts-mac/apd455c82f02/mac).
- Focus integration requires an early feasibility gate. If the documented safety conditions cannot be met, retain reliable timing and clearly expose the reduced integration capability.
