# Firebase environments (Debug / Prod)

SnapLedger uses **two Firebase projects** selected by Xcode build configuration.

| Config | Scheme | App bundle ID | Widget bundle ID | App Group | Firebase |
|--------|--------|---------------|------------------|-----------|----------|
| **Debug** | `SnapLedger-Debug` (home screen: **SnapLedger-Debug**) | `com.snapledgerapp.ios` | `com.snapledgerapp.ios.widgets` | `group.com.snapledgerapp.ios.shared` | Existing project `xpnse-7b4f2` |
| **Release (Prod)** | `SnapLedger` (home screen: **SnapLedger**) | `com.snapledger.ios` | `com.snapledger.ios.widgets` | `group.com.snapledger.ios.shared` | **New** Prod Firebase project |

## Plist layout

```
src/Xpnse/Firebase/Config/
  GoogleService-Info-Debug.plist    # current xpnse-7b4f2 credentials
  GoogleService-Info-Release.plist  # replace with Prod download
```

A **Copy GoogleService-Info** Run Script (after Resources, before Crashlytics upload) copies the correct file into the app bundle as `GoogleService-Info.plist`. Release builds **fail** until the Prod placeholder is replaced (must not contain `REPLACE_WITH_PROD_FIREBASE_PLIST`).

## Prod console checklist (you create once)

### Apple Developer
1. Register App IDs: `com.snapledger.ios`, `com.snapledger.ios.widgets`
2. Create App Group: `group.com.snapledger.ios.shared`
3. Enable App Groups on both App IDs

### Firebase
1. Create a new Firebase project (separate from `xpnse-7b4f2`)
2. Add an iOS app with bundle ID `com.snapledger.ios`
3. Download `GoogleService-Info.plist` and overwrite `src/Xpnse/Firebase/Config/GoogleService-Info-Release.plist`
4. Enable Crashlytics, Analytics, and Remote Config
5. Add Remote Config booleans: `insights_enabled`, `receipt_scan_enabled`, `export_import_enabled` (defaults `true`)

Debug App IDs and Firebase project stay as they are today — no re-registration needed.

## Google Sign-In note

Each plist has its own `REVERSED_CLIENT_ID`. When Auth UI is re-enabled, Info.plist URL types must include the active environment’s reversed client ID.
