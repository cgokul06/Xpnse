# SnapLedger

Native iOS app for tracking day-to-day income and expenses — with period summaries, category insights, receipt scanning, recurring transactions, widgets, and local backup.

**Platform:** iOS 26+ · **Debug bundle ID:** `com.snapledgerapp.ios` · **Prod bundle ID:** `com.snapledger.ios` · **Stack:** SwiftUI, SwiftData, WidgetKit, Firebase, Apple Foundation Models

## Documentation

- **[Features & capabilities](docs/FEATURES.md)** — full product documentation: home dashboard, transactions, bill scanner, recurring rules, categories, currency, widgets, export/import, and more
- **[Firebase environments](docs/FIREBASE_ENVIRONMENTS.md)** — Debug vs Prod Firebase projects, bundle IDs, and GoogleService-Info plists
- **[Legal documents](docs/LEGAL.md)** — Privacy Policy and Terms source HTML, plus how to republish to GitHub Pages
- **[AGENTS.md](AGENTS.md)** — contributor and build environment notes

## Quick start

1. Open `src/Xpnse.xcodeproj` in Xcode 26+
2. Select a scheme in the toolbar:
   - **SnapLedger-Debug** — Debug build (display name SnapLedger-Debug, existing Firebase)
   - **SnapLedger** — Release/Prod build (display name SnapLedger, Prod Firebase)
3. Resolve SPM dependencies (Firebase, Google SignIn)
4. Run on an iOS 26 Simulator or device (⌘R)

## Project layout

```
src/
  Xpnse/           Main app target (SnapLedger)
  XpnseWidgets/    Home Screen widgets
  XpnseShared/     Shared models (widgets, App Group)
  Xpnse.xcodeproj/
docs/
  FEATURES.md      Product feature documentation
  LEGAL.md         How to update/republish Privacy & Terms
  privacy.html     Privacy Policy source (publish via snapledger-legal)
  terms.html       Terms & Conditions source (publish via snapledger-legal)
```
