# Xpnse

Native iOS app for tracking day-to-day income and expenses — with period summaries, category insights, receipt scanning, recurring transactions, widgets, and local backup.

**Platform:** iOS 26+ · **Stack:** SwiftUI, SwiftData, WidgetKit, Firebase Auth, Apple Foundation Models

## Documentation

- **[Features & capabilities](docs/FEATURES.md)** — full product documentation: home dashboard, transactions, bill scanner, recurring rules, categories, currency, widgets, export/import, and more
- **[AGENTS.md](AGENTS.md)** — contributor and build environment notes

## Quick start

1. Open `src/Xpnse.xcodeproj` in Xcode 26+
2. Resolve SPM dependencies (Firebase, Google SignIn)
3. Run on an iOS 26 Simulator or device (⌘R)

## Project layout

```
src/
  Xpnse/           Main app target
  XpnseWidgets/    Home Screen widgets
  XpnseShared/     Shared models (widgets, App Group)
  Xpnse.xcodeproj/
docs/
  FEATURES.md      Product feature documentation
```
