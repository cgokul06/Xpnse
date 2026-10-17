# Onboarding education (phase 1)

In-app education sheets that walk new users through the first useful actions in SnapLedger. Later journeys (widgets, receipt scanner, Insights) are deferred.

Sheets appear on the **Home** screen, one at a time, after the global education policy allows a new session, with a short delay (~1.5s) after the user lands on Home. **Recurring reminder** is the exception: it appears on **Add Transaction** when the user taps Save, before the recurring item is saved.

## Shipped journeys

Priority is lower-int-first (Income wins over everything else).

| Priority | Journey | When it shows | Primary action |
|---|---|---|---|
| 0 | **Income Setup** | No transactions, no configured income, no active recurring income | Opens Add Transaction as income with recurring on |
| 4 | **Recurring reminder** | User taps Save on **Add Transaction** for an **expense or savings** recurring item with **Remind me** off, and notification permission is still **not determined**. Does **not** show for income. | Dismisses the sheet, asks for notification permission, then if allowed turns on Remind me with the default time, saves, and dismisses Add Transaction |
| 5 | **Expense Setup** | After Income Setup is completed **or** declined/swiped, and the user still has **no expenses** | Opens Add Transaction as expense |
| 10 | **Custom Category** | At least 3 transactions and no custom categories | Pushes Settings → Categories and opens the new-category modal |

### Income Setup

- Eligible only for a truly empty ledger.
- Completes when the user saves income (one-off or recurring).
- Decline and swipe both mark the journey declined (one-shot).

### Expense Setup

- After a **completed** Income Setup, shows when the user returns to Home.
- After Income Setup is **declined or swiped**, shows on the **next launch or foreground**, and only if `expenseCount == 0`. This follow-up skips the 10-minute decline cooldown (`followUpAfterSkipOf`); other journeys still wait for it.
- If the user already added an expense, this journey never shows.

### Recurring reminder

- Shows on **Add Transaction** when the user taps Save for an **expense or savings** recurring item with **Remind me** off, **before** the item is saved. Does not wait until Home.
- Does **not** show after an income recurring save.
- **Yes** dismisses the sheet, then asks for system notification permission. If allowed, turns on **Remind me** with the default time (9 PM the day before), saves the recurring item, and dismisses Add Transaction.
- If permission is denied, or the user taps **Not Now** / swipes the sheet, the recurring item is saved without Remind me and Add Transaction dismisses.
- Does **not** show if notify was already on (the form already requested permission).
- Does **not** show if OS notification permission is already granted or denied.
- After **Not Now**, never shows again. After a swipe, does not show again this session.
- The engine never publishes this journey on its own (`presentsAutomatically == false`). Add Transaction starts it with `beginHostedPresentation`, so recurring items created elsewhere (for example, Settings → Recurring) never show it, and it never appears on Home.
- Does not interrupt another journey that is already in progress (for example, when Add Transaction was opened from the expense sheet).

### Custom Category

- Independent of whether Income Setup was completed.
- Back from the add-category flow is Categories → Settings → Home.

## Framework (done)

- Campaign model, persisted per-journey state, outcomes (`completed` / `declined` / `dismissed` / `actionFailed`)
- Journey prerequisites and completion validators
- `EducationEngine` scheduler: only one journey active (`idle` → `presenting` → `performingAction` → `waitingForOutcome`)
- Global policy: no back-to-back sheets; declined journeys wait **10 minutes** plus a real trigger (launch, foreground, new transaction, or recurring created); completed journeys may resume on return to Home
- Live evaluation context from SwiftData (transactions, recurring rules, categories, notification authorization)
- Presentation coordinator: Home-only except Recurring reminder (allowed on Add Transaction); ~1.5s delay after landing on Home; suppressed while another overlay is up
- Education sheet copy is localized (`education.*` keys in `Localizable.xcstrings`)

## Deferred (later phase)

- Widget education
- Receipt scanner education
- Insights education
- Education analytics
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
