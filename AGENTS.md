# AGENTS.md

## Project overview

Xpnse is a native iOS expense-tracking app built with **SwiftUI** and **Swift 5**, targeting **iOS 26.0**. It uses SwiftData for local persistence, Firebase for auth/profile sync, and Apple's FoundationModels for receipt scanning. There is no backend server, no web component, and no Docker infrastructure.

Key directories:
- `src/Xpnse/` — all Swift source (76 files)
- `src/Xpnse.xcodeproj/` — Xcode project definition
- SPM dependencies (resolved via Xcode): `firebase-ios-sdk` ≥ 12.0, `GoogleSignIn-iOS` ≥ 9.0

## Cursor Cloud specific instructions

### Environment limitations

This is a **macOS/Xcode-only** project. On the Linux Cloud Agent VM you **cannot** build or run the app (no Xcode, no iOS Simulator). The following is available on the VM:

| Tool | Version | Path | Purpose |
|---|---|---|---|
| Swift toolchain | 6.1 | `/opt/swift-6.1/usr/bin/swift` (symlinked to `/usr/local/bin/swift`) | Syntax checking (`swiftc -parse`) |
| SwiftLint | 0.63.2 | `/usr/local/bin/swiftlint` | Linting (`swiftlint lint`) |

### Running lint

```bash
export LINUX_SOURCEKIT_LIB_PATH=/opt/swift-6.1/usr/lib
cd src/Xpnse
swiftlint lint
```

SwiftLint requires the `LINUX_SOURCEKIT_LIB_PATH` env var set to the Swift toolchain's lib directory, otherwise it will crash at runtime.

### Syntax checking

```bash
swiftc -parse path/to/File.swift
```

This validates Swift syntax on a per-file basis. It does **not** resolve imports or type-check against Apple frameworks (SwiftUI, SwiftData, Vision, FoundationModels are unavailable on Linux).

### What you cannot do on this VM

- `xcodebuild` / full project compilation — requires macOS + Xcode 26
- Run the app in iOS Simulator — requires macOS
- Run automated tests — no test targets exist in the project
- Resolve SPM package dependencies — the project uses Xcode-managed SPM, not a standalone `Package.swift`

### Building and running the app (requires macOS)

1. Open `src/Xpnse.xcodeproj` in Xcode 26+
2. Xcode will auto-resolve SPM dependencies (Firebase, GoogleSignIn)
3. Select an iOS 26 Simulator or physical device
4. Build and run (Cmd+R)
