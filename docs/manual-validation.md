# Interactive validation

On macOS 27.0.1, the release app was exercised through accessibility controls:

- Start, pause, resume, short hold, and two-second hold; reset returned to 25:00 and did not start the timer.
- A one-minute countdown reached 00:00 and displayed Completed. Sound and notification were enabled, but the observer could not determine whether either was delivered; this remains unverified.
- Closing the last window initially terminated the app. After adding the application delegate lifecycle handling, closing and reopening preserved a running countdown, including with the menu bar disabled.
- Cycle defaults and separate automatic-start settings were visible. Menu bar insertion toggled successfully, but its menu controls could not be inspected through the available desktop control.
- A nonexistent shortcut returned a failure message without stopping timing; the user's shortcut returned success and changed Focus state.
- The app entered and exited its own full-screen mode. Visibility over another full-screen app, system appearance changes, sleep/wake, notification delivery, and audible sound remain unverified.
- System notification logs for the one-minute test show authorization and notification submission returned errors; System Settings did not list TometoClock under app notifications. The error details and cause are not yet known. No claim is made that sound or notification delivery works.
