# Localization

SnapLedger uses Apple String Catalogs for v1 internationalization.

## Languages

- English (`en`, Base) — source
- Spanish (`es`)
- French (`fr`)
- German (`de`)

Device preferred language is used automatically. Missing keys fall back to English. There is no in-app language picker.

## Catalogs

- [`src/XpnseShared/Localizable.xcstrings`](../src/XpnseShared/Localizable.xcstrings) — app + widgets (shared target)
- [`src/Xpnse/InfoPlist.xcstrings`](../src/Xpnse/InfoPlist.xcstrings) — usage description strings

## Key conventions

Semantic keys, dotted namespaces:

- `common.*`, `home.*`, `txn.*`, `category.*`, `settings.*`, `auth.*`, `insights.*`, `scanner.*`, `widget.*`, `notification.*`

Builtin categories: `category.builtin.<id>` (e.g. `category.builtin.food`). Custom category names are never localized.

## Code usage

```swift
Text("home.add_transaction")
String(localized: "home.add_transaction")
L10n.tr("notification.upcoming", title)
AmountFormatter.format(amount, currencyCode: code) // never manual currency symbols
```

## Adding a language later

1. Add the region to `knownRegions` in the Xcode project
2. Add translations for that language code in the String Catalog(s)
3. Optionally extend `OCRLanguagePreferences.supportedRecognitionLanguages`

No code changes are required beyond resources for Italian, Portuguese (Brazil), Dutch, Japanese, Korean, or Chinese (Simplified).
