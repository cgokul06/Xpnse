# SnapLedger — Product Features & Capabilities

SnapLedger is a native iOS expense-tracking app that helps you record income and expenses, understand spending by period and category, and stay on top of recurring bills. Data is stored locally on device with optional account sign-in infrastructure; there is no custom backend server.

**Platform:** iOS 26+  
**Tech stack:** SwiftUI, SwiftData, Firebase Auth, Apple Foundation Models, WidgetKit

---

## Table of contents

1. [Overview](#overview)
2. [First launch & onboarding](#first-launch--onboarding)
3. [Home dashboard](#home-dashboard)
4. [Transactions](#transactions)
5. [Bill scanner](#bill-scanner)
6. [Recurring transactions](#recurring-transactions)
7. [Categories](#categories)
8. [Currency](#currency)
9. [Settings & data management](#settings--data-management)
10. [Home screen widgets](#home-screen-widgets)
11. [Notifications](#notifications)
12. [Deep links](#deep-links)
13. [Architecture & data storage](#architecture--data-storage)
14. [Requirements & dependencies](#requirements--dependencies)

---

## Overview

| Capability | Description |
|---|---|
| Expense & income tracking | Log transactions with amount, description, category, date, and type |
| Period summaries | View balance, income, and expenses for each month |
| Category breakdown | Flip the summary card to see an expense donut chart by category |
| Smart suggestions | Description and merchant autocomplete from past transactions |
| AI category hints | On-device classification suggests a category from the description |
| Receipt scanning | Extract amount, merchant, and date from bill photos (Apple Intelligence) |
| Recurring schedules | Automate repeating transactions with optional reminders |
| Custom categories | Built-in and user-defined categories with icon and color |
| Multi-currency | 100+ currencies with searchable selection |
| Backup & restore | Export and import full JSON backups |
| Widgets | Balance snapshot and quick-add shortcuts on the Home Screen |

---

## First launch & onboarding

### Currency setup

On first launch (when no currency has been saved), SnapLedger presents a **Choose your currency** screen:

- Pick a default currency before entering the app
- Open a searchable currency list (name, ISO code, and symbol)
- Search is accessed from a magnifying-glass button in the navigation title; the search bar animates into the title area
- Tap **Continue** after selecting a currency

Returning users skip this step and land directly on the home dashboard.

### Sign-in (optional infrastructure)

The codebase includes Google, email/password, and guest sign-in flows. The current app route does **not** require authentication to use the app; all core features work with local storage.

---

## Home dashboard

The home screen is the primary hub for reviewing finances and adding entries.

### Header

- App title and tagline
- **Settings** gear icon

### Month navigation

- **Date switcher bar** shows the current month label (e.g. `May 2026`)
- **Swipe horizontally** on the date bar, summary card, or transaction list to move between months
- Supports browsing up to **12 months into the future** and unlimited past months (with data prefetching)
- Adjacent months are preloaded for smooth swiping

### Summary card

Shown only for months that contain transactions.

| Face | Content |
|---|---|
| **Balance** (default) | Total balance, income, and expenses for the period |
| **Donut** (tap flip) | Expense breakdown by category with chart visualization |

The card flip state persists while swiping between months.

### Transaction list

- **Transactions** header with a toggle to group by **date** or **category**
- Each group shows a net total (green for positive, red for negative)
- Tap a transaction to **edit** it
- **Scroll position** is remembered per month when switching away and back
- **Empty months:** no summary card; full-height empty state with “No transactions found!”

### Bottom actions

- **Add transaction** — opens the transaction form
- **Scan bill** — opens the receipt scanner (shown only when Apple Foundation Models are available on the device)

---

## Transactions

### Add & edit

The transaction form supports:

| Field | Details |
|---|---|
| Type | Expense or income |
| Date | Calendar picker |
| Amount | Numeric entry in selected currency |
| Description | Free text with live suggestions |
| Merchant | Optional free text with live suggestions |
| Category | Dropdown of expense or income categories |
| Recurring | Optional recurrence schedule (see below) |
| Reminder | Optional local notification for recurring items |

### Description suggestions

- As you type, SnapLedger suggests titles from your transaction history
- Suggestions are ranked by frequency and recency
- Selecting a suggestion can pre-fill the category from past usage
- Suggestions rebuild after data import

### Merchant suggestions

- Optional merchant / payee field on each transaction and recurring rule
- As you type in the merchant field, SnapLedger suggests merchant names from past usage (frequency + recency)
- Selecting a merchant suggestion fills only the merchant field (does not change category)
- Merchant suggestions rebuild after data import

### AI merchant detection

When Apple Intelligence is available and the description is at least 3 characters:

- An on-device language model infers a short merchant/brand from the description (e.g. “YouTube Premium” → YouTube, “Amazon Prime subscription” → Amazon)
- Runs automatically when you leave the description field (and after a receipt scan), unless you already edited the merchant yourself
- Does **not** prefill merchant from past description→merchant mappings the way category does for known titles

### AI category classification

When Apple Intelligence is available and the description is at least 3 characters:

- An on-device language model suggests the best matching category
- Classification runs automatically unless you manually pick a category
- Works separately for expense and income category lists
- Unlike merchant detection, a previously used description can still map to its known category without calling the model

### Delete

When editing an existing transaction, you can delete it with confirmation.

---

## Bill scanner

Available from the home screen when Foundation Models are supported.

### Input sources

- **Take Photo** — camera capture
- **Select from Library** — photo picker

### Extraction pipeline

1. **Vision** OCR reads text from the image
2. **Foundation Models** parse merchant name, total amount, and date
3. A preview screen lets you review extracted fields before saving
4. Confirmed data opens the add-transaction form pre-filled

If extraction fails, an error message is shown and you can retry or enter details manually.

---

## Recurring transactions

Create repeating transactions from the add-transaction form or manage them under **Settings → Manage Recurring Transactions**.

### Supported frequencies

- Daily
- Weekly (on the selected weekday)
- Every 2, 3, or 4 weeks
- Monthly (with end-of-month overflow handling)
- Every two months
- Quarterly

### Options

- Optional **end date**
- **Pause** or **resume** active schedules
- **Edit** amount, category, description, merchant, and schedule
- **Remind me** — schedules a local notification aligned to the recurrence

Recurring rules are processed automatically on app launch and when the app returns to the foreground, materializing due transactions into your history (including merchant when set).

---

## Categories

### Built-in categories

SnapLedger ships with default expense and income categories (food, transport, salary, etc.).

### Custom categories

**Settings → Manage Categories**

- Add, edit, or delete user-defined categories
- Set **name**, **type** (expense/income), **SF Symbol icon**, and **color**
- Categories used by existing transactions cannot be deleted until reassigned
- Category catalog is included in backup/export files

Categories appear in transaction forms, list grouping, summary donut chart, and AI classification prompts.

---

## Currency

### Selection

- First-run currency picker and **Settings → Currency**
- Searchable list of **100+ currencies**
- Search matches **full name**, **ISO code** (e.g. `INR`), and **symbol** (e.g. `₹`)
- Live filtering on every keystroke

### Usage

- Selected currency symbol is used across the app and widgets
- Stored in shared preferences (App Group) for widget access
- Included in JSON backup settings

---

## Settings & data management

Open **Settings** from the home screen gear icon.

### Preferences

- **Currency** — change default display currency

### Data portability

- **Export All Data** — generates a pretty-printed JSON backup (`snapledger_backup.json`) containing:
  - Transactions (including optional merchant)
  - Recurring rules (including optional merchant)
  - Custom categories
  - Currency preference
  - Schema version and timestamps (current schema version **7**)
- **Import All Data** — restores from a compatible JSON backup (supports schema versions up to current)

### Categories & recurring

- **Manage Categories**
- **Manage Recurring Transactions**

### Clear local data

- **Clear Local Data** — removes all locally stored transactions (destructive, confirmation via button role)

---

## Home screen widgets

SnapLedger includes a WidgetKit extension with two widgets. Data is synced from the main app via an **App Group** snapshot pipeline that refreshes when transactions change or the app becomes active.

### Total Balance

| Size | Content |
|---|---|
| **Small** | Period label, total balance, income and expense stacked vertically |
| **Medium** | Period label, total balance, income and expense side by side |

Tapping the widget opens the app home screen (`snapledger://home`).

### Add Transaction

- **Small** only
- Plus button shortcut
- Opens the add-transaction flow (`snapledger://add-transaction`)

---

## Notifications

Recurring transactions can schedule **local reminders**:

- Permission is requested when you first enable “Remind me”
- Reminders are reconciled when recurring rules change or the app launches
- If permission is denied, the app prompts you to enable notifications in Settings

---

## Deep links

Custom URL scheme: `snapledger://`

| URL | Action |
|---|---|
| `snapledger://home` | Open home dashboard |
| `snapledger://add-transaction` | Open add-transaction screen |

Used by widgets and can be invoked from Shortcuts or other apps.

---

## Architecture & data storage

### Local-first

| Layer | Technology |
|---|---|
| Transactions | SwiftData |
| Recurring rules | SwiftData |
| Categories | SwiftData |
| Suggestions | JSON file in Application Support |
| Preferences | UserDefaults (+ App Group for widgets) |

### Sync & services

- **Firebase Auth** — sign-in infrastructure (Google, email); not required for core usage
- **Firebase Analytics / Crashlytics / Firestore** — included in project dependencies; transaction storage is local SwiftData
- **No custom backend** — the app does not depend on a proprietary server

### Widget pipeline

1. `WidgetSnapshotBuilder` aggregates current-period totals and category slices
2. Snapshot written to App Group storage via `WidgetDataStore`
3. `WidgetRefreshCoordinator` debounces updates and calls `WidgetCenter.reloadAllTimelines()`

### AI features

Requires Apple **Foundation Models** availability on device:

- Bill/receipt parsing
- Category classification from description

When unavailable, bill scanner entry point is hidden and classification is skipped silently.

---

## Requirements & dependencies

### Device & OS

- iPhone or iPad running **iOS 26.0+**
- Xcode **26+** to build from source

### Apple capabilities

- Camera & photo library (bill scanner)
- Notifications (recurring reminders)
- App Groups (widget data sharing)

### Third-party packages (SPM)

- Firebase iOS SDK ≥ 12.0
- Google Sign-In iOS ≥ 9.0

### Build & run

1. Open `src/Xpnse.xcodeproj` in Xcode
2. Allow SPM to resolve dependencies
3. Select a simulator or device
4. Build and run (⌘R)

---

## Feature summary matrix

| Feature | Available offline | Requires Apple Intelligence |
|---|---|---|
| Add/edit/delete transactions | Yes | No |
| Month browsing & summaries | Yes | No |
| Category donut chart | Yes | No |
| Description suggestions | Yes | No |
| Merchant suggestions | Yes | No |
| AI merchant detection | Yes* | Yes |
| AI category classification | Yes* | Yes |
| Bill scanner | Yes* | Yes |
| Recurring transactions | Yes | No |
| Local reminders | Yes | No |
| Custom categories | Yes | No |
| Currency search | Yes | No |
| Export / import | Yes | No |
| Widgets | Yes** | No |

\*Feature hidden or degraded when Foundation Models are unavailable.  
\*\*Widgets read last snapshot written by the app; opening the app refreshes data.

---

*Document version reflects the codebase as of the current development branch. For contributor build instructions, see [AGENTS.md](../AGENTS.md).*
