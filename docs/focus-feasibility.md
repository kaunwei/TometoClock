# Focus feasibility (incomplete)

Apple's public [Focus status interface](https://developer.apple.com/documentation/intents/infocusstatus) reports whether notifications are silenced, not the identity of the current Focus mode. It cannot establish that the app-selected mode is still active, so it cannot justify automatic restoration. Switching away and back is also not detectable by that interface. No automatic Focus restoration should be attempted without reliable identity.

The macOS 27.0.1 development machine has Command Line Tools but no Xcode. A GUI launch attempt in the current execution environment failed to connect to desktop services, and an application-bundle launch through desktop control timed out. Shortcut invocation, permission prompts, sandbox behavior, and late-result cancellation have not been verified. No supported automation contract is claimed yet. A real interactive Mac test with a user-connected shortcut and a properly packaged app is required before enabling automatic execution.

## CLI checks on macOS 27.0.1

On 2026-10-29, `/usr/bin/shortcuts list` failed inside the execution sandbox with “Couldn’t communicate with a helper application”; outside that sandbox it succeeded. Running a deliberately nonexistent shortcut outside the sandbox returned a nonzero exit and a not-found error. No existing Focus test shortcut was available, so these observations do not establish that a real shortcut runs successfully, that its permissions work, or that app sandboxing permits it. The settings page has an explicit test action; it does not automatically run shortcuts or restore Focus. A user-created harmless test shortcut is needed to finish the feasibility gate.

A user-provided shortcut named `切換勿擾模式` was listed and invoked from the CLI outside the execution sandbox on 2026-10-29; the command exited successfully. The invocation may have changed the user's Focus state. This confirms the CLI invocation path only; it does not verify mode identity, restoration, or a sandboxed app's permissions. The public Focus status interface does not establish which mode is active.

## Current safe contract

The app accepts a per-preset shortcut name and can invoke it only when the user explicitly chooses Test. It reports success or failure and leaves timing independent. Automatic invocation remains disabled: `shortcuts run` gives no documented guarantee that terminating its command cancels a shortcut already handed to the Shortcuts helper, and the provided shortcut toggles state rather than idempotently enabling a known mode. A late shortcut action could therefore modify Focus after the session was cancelled. The unsigned development bundle has no App Sandbox entitlement; the CLI success above is not evidence of behavior in a sandboxed distribution. Automatic restoration remains unsupported for lack of reliable mode identity.

On 2026-10-29 the unsigned app's explicit Test action successfully invoked the user's shortcut and reported completion. A nonexistent shortcut reported failure while the timer remained running. The successful test toggled Focus again; neither current-mode identity nor safe cancellation of a delayed action was established.
