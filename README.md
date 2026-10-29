# TometoClock

Early implementation of a native macOS timer. The package targets macOS 14 and is built with the macOS 27 SDK on macOS 27.0.1. Run `swift run TometoClock` with a complete Swift development toolchain. Run `scripts/build-app.sh` to create `.build/TometoClock.app`; a packaged app is needed for notification authorization.

The session uses deadlines and stores five local presets and the work title. Reminders default to silent. The window is not floating and the menu bar item is hidden by default; when enabled, the menu bar shows time by default. Full-screen visibility is off by default. Skipping a long break starts a new round group. Desktop controls and reminder delivery are implemented but need interactive validation. Automatic Focus integration and the full acceptance and resource checks are not finished; see [Focus feasibility](docs/focus-feasibility.md). The hold gesture, window lifecycle, notifications, and sleep behavior require real interactive testing. The currently packaged app is unsigned and has no App Sandbox entitlement. Focus shortcut testing is manual; the app does not automatically invoke or restore Focus.

## CLI checks on Command Line Tools

With this machine's Command Line Tools (which lack XCTest), the tests can be run with Swift Testing and writable temporary caches:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/tometo-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/tometo-swift-cache swift test --disable-sandbox --scratch-path /tmp/tometo-build --build-system native --disable-xctest -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks -Xlinker -F -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks
```
