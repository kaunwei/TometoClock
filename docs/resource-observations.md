# Resource observations

On macOS 27.0.1 using the release app, an initial launch produced approximately 96% CPU and a physical footprint exceeding 1 GiB within a minute. A sample showed repeated SwiftUI app graph and main-menu updates. The presentation setter was made idempotent to avoid re-publishing unchanged values. A subsequent idle snapshot after approximately 42 seconds showed 0.0% CPU and 93,184 KiB RSS (`ps`). These are individual samples, not energy measurements or budgets. Visible running, hidden running, paused, sleep/wake, and longer-term memory behavior still require profiling.

A later idle `ps` snapshot of the same launch after approximately 10 minutes showed 0.0% CPU and 79,728 KiB RSS. This does not establish behavior under active timing, sleep, or UI changes.

After fixing last-window closure, an interactive one-minute countdown used 6.1% CPU and 104,768 KiB RSS in one visible-running snapshot. A separate hidden-running snapshot with the menu bar disabled showed 0.3% CPU and 105,936 KiB RSS. These are instantaneous `ps` values; sleep/wake and long-running profiling have not been performed.
