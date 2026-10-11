# Onboarding education (phase 1)

In-app education sheets that walk new users through the first useful actions in SnapLedger. Later journeys (widgets, receipt scanner, Insights) are deferred.

Sheets appear only on the **Home** screen, one at a time, after the global education policy allows a new session.

## Shipped journeys

Priority is lower-int-first (Income wins over everything else).

| Priority | Journey | When it shows | Primary action |
|---|---|---|---|
| 0 | **Income Setup** | No transactions, no configured income, no active recurring income | Opens Add Transaction as income with recurring on |
| 4 | **Recurring reminder** | First recurring saved with **Remind me** off, and notification permission is still **not determined** (not granted, not denied) | Dismisses the sheet, then asks for notification permission. If allowed, turns on the default reminder for that recurring item. If denied, continues without permission (no Settings alert) |
| 5 | **Expense Setup** | After Income Setup is completed **or** declined/swiped, and the user still has **no expenses** | Opens Add Transaction as expense |
| 10 | **Custom Category** | At least 3 transactions and no custom categories | Pushes Settings → Categories and opens the new-category modal |

### Income Setup

- Eligible only for a truly empty ledger.
- Completes when the user saves income (one-off or recurring).
- Decline and swipe both mark the journey declined (one-shot).

### Expense Setup

- After a **completed** Income Setup, shows when the user returns to Home.
- After Income Setup is **declined or swiped**, shows on the **next launch or foreground**, and only if `expenseCount == 0`.
- If the user already added an expense, this journey never shows.

### Recurring reminder

- Does **not** show if notify was already on at save time (the form already requested permission).
- Does **not** show if OS notification permission is already granted or denied.
- Secondary / dismiss: do not request permission.

### Custom Category

- Independent of whether Income Setup was completed.
- Back from the add-category flow is Categories → Settings → Home.

## Framework (done)

- Campaign model, persisted per-journey state, outcomes (`completed` / `declined` / `dismissed` / `actionFailed`)
- Journey prerequisites and completion validators
- `EducationEngine` scheduler: only one journey active (`idle` → `presenting` → `performingAction` → `waitingForOutcome`)
- Global policy: no back-to-back sheets; declined journeys wait **10 minutes** plus a real trigger (launch, foreground, new transaction, or recurring created); completed journeys may resume on return to Home
- Live evaluation context from SwiftData (transactions, recurring rules, categories, notification authorization)
- Presentation coordinator: Home-only, suppressed while navigation is busy or another overlay is up

## Deferred (later phase)

- Widget education
- Receipt scanner education
- Insights education
- Education analytics
- Localizing education sheet copy (`Localizable.xcstrings` — copy is currently hardcoded English)
- Filling remaining live context fields used only by later journeys (`daysSinceInstall`, `receiptScanCount`, `isWidgetInstalled`, and similar)

## Code map

```
src/Xpnse/Education/
  Campaign/       models, registry, persistence
  Engine/         events, evaluation context, EducationEngine
  Policy/         global cooldowns and session rules
  Journeys/       Income, Expense, Recurring reminder, Custom Category
  Presentation/   coordinator, navigation, notification-permission handler
src/Xpnse/DesignSystem/Components/Education/
  EducationBottomSheet + sheet models
src/XpnseTests/Education/
```
