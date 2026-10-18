# SnapLedger — Product map for analytics and churn

This document describes the live user journey and every feature surface, with the drop-off points, success signals, and instrumentation gaps that matter when designing analytics and diagnosing churn.

It is written from the current app behavior (currency gate, then Home, then in-app education). Sign-in screens exist in the codebase and are **not** on the live route. Companion docs: [FEATURES.md](FEATURES.md) (product overview) and [EDUCATION_ONBOARDING.md](EDUCATION_ONBOARDING.md) (education engine).

**Platform:** iOS 26+, local-first SwiftData. No account is required. There is no server-side session, so uninstall and “stopped opening the app” are not the same event.

---

## How to use this doc

1. Pick an activation definition from [Recommended definitions](#recommended-definitions) before building funnels. The product has several plausible “first value” moments, and they answer different questions.
2. Use [First-session funnel](#first-session-funnel) and [Education journeys](#education-journeys) for early churn (install → first useful ledger).
3. Use [Feature surfaces](#feature-surfaces) for later churn (people who activated, then stopped). The return path is [Return hooks](#return-hooks): the 7:00 PM check-in, the Balance widget reminder, and recurring bill notifications.
4. Use [What is already logged](#what-is-already-logged) so new events do not duplicate Firebase screen views and `button_click`.
5. Use [Instrumentation gaps](#instrumentation-gaps) as the backlog. Education, form abandon, and transaction shape are the holes that currently hide the cause of early churn.
6. Keep every new parameter inside the [Privacy rules](#privacy-rules).

---

## Privacy rules

`AppAnalytics` is explicitly privacy-safe. Events must not carry amounts, merchants, descriptions, category names, emails, or other financial or personal content.

Safe dimensions:

| Kind | Examples |
|---|---|
| Screen and button ids | `home`, `add_transaction`, `save_transaction` |
| Outcome enums | `success`, `fail`, `empty`, `not_related` |
| Feature flags | `insights_enabled` = `true` / `false` |
| Coarse product shape | transaction **type** (`expense` / `income` / `savings`), whether it is recurring, whether a reminder was on, entry **source** (`home`, `education_income`, `scan`, `share`, `widget`) |
| Buckets | lifetime transaction count bucket (`0`, `1`, `2-4`, `5-19`, `20+`), days since install bucket, not the raw description |

Do not log search queries, feedback text, currency amounts, or OCR text. Currency **code** (ISO, e.g. `INR`) and locale are acceptable user properties. Feedback text already goes to Firestore, not Analytics.

---

## Identity, and what “churn” can mean

Two anonymous ids are created at launch in `AnonymousIdentity`:

| Id | Storage | Survives | Sent to Analytics today |
|---|---|---|---|
| `userId` | Keychain | Relaunch, and often reinstall | Yes — `Analytics.setUserID` |
| `installationId` | UserDefaults | This install only | No |

Implications for churn analysis:

- **Inactivity churn** is the measurable one: no `session_start` for N days. Firebase can do this. The app cannot see an uninstall.
- **Reinstall** often keeps the same Analytics user (Keychain `userId`) while wiping SwiftData. That user looks like a returning user with an empty ledger, not a new install, unless you also track `installationId` and a “ledger empty after prior activity” signal.
- **Clear Local Data** is an in-app reset. `clear_data_confirm` is intent; `local_data_clear_completed` is success. It is not uninstall. `first_transaction_saved` is not reset. Treat it as a frustration or “start over” event, not a new install.
- **Export then disappearance** can mean the person moved their data out and left. Export success is logged; the later absence is only visible as inactivity.
- There is no login, so there is no cross-device user and no “account deleted” event.

A practical churn definition for this app:

| Window | Working definition |
|---|---|
| Early | Installed, reached Home, and has **no expense** by end of day 1, or no second session by day 3 |
| Activated-then-churned | Saved at least one expense, then no session for 14 days |
| Habit broken | Had a recurring rule or a 3+ day open streak, then no session for 14 days |

Day boundaries should use the device calendar. The app’s own “streak” is consecutive **days the app was opened or foregrounded**, not consecutive days a transaction was logged.

---

## Recommended definitions

Use these as funnel stages. They are product definitions built from events, not person-level claims. SnapLedger is local-first and has no account identity; report retention by Firebase analytics identity / this install.

| Stage | Definition | Event / report |
|---|---|---|
| Setup complete | Currency selection was persisted and the app can proceed to Home | `app_setup_completed` |
| Education exposed | Income sheet was shown | `education_presented` `journey=income_setup` |
| **Activated** | First successful transaction for this install / analytics identity | `first_transaction_saved` |
| Repeat user | A later session includes a meaningful successful action | `txn_save`, recurring create, `export_completed`, or `insights_viewed` `state=ready` |
| At risk | No meaningful action for 7 days | GA4 cohort; no client event |
| Inactive | No meaningful action for 14 or 30 days | GA4 inactivity proxy, not person-level churn |
| Reactivated | After 14+ days without a meaningful action, returns and completes one | Cohort/query; no client event |

Meaningful actions: successful transaction save, recurring-rule creation, successful export, or Insights viewed with `state=ready`. Do not count screen views, settings visits, button taps, or failed actions.

Do not treat “opened the app 8 times” or “20 transactions” as activation. Those thresholds exist only to gate the App Store review prompt.

`first_transaction_saved` is once per install. Clear Local Data does **not** reset it (same analytics identity, empty ledger). Reinstall / deleting the app does, because UserDefaults is gone. Do not claim person-level continuity across reinstalls.

---

## First-session funnel

```
Launch
  → Firebase configure + anonymous user id
  → recurring rules materialize in the background (no-op on a new install)
  → route:
       no saved currency → Choose your currency
       saved currency    → Home
  → Home appears (empty ledger: no summary card, “No transactions found!”)
  → ~1.5s after Home is settled and foregrounded
  → Income Setup sheet, if still eligible
```

Auth is commented out of `AppRoute`. Google, email, and guest buttons are not shown.

### 1. Choose your currency

Shown only when `CurrencyManager` has no stored selection. Returning installs skip it.

| UI | Behavior |
|---|---|
| Title | “Choose your currency” |
| Body | “Set your preferred currency before you start tracking expenses.” |
| Row | Opens a searchable list (name, ISO code, symbol). Selecting a row **saves immediately** |
| Continue | Saves the selected currency again and routes to Home |

Default selection is whatever `CurrencyManager` already resolves before the user taps anything (device-based). Continue stays enabled when that code is known, so a user can pass this screen without opening the list.

**Drop-off:** kill the app on this screen. Next launch shows it again. There is no skip.

**Already logged:** screen `currency_selection`, screen `currency_list`, buttons `currency_continue` and `select_currency`.

**Not logged:** whether they opened the list, which ISO code they kept, or whether they backgrounded without Continue. Currency code is the right user property (not an event parameter on every tap).

### 2. Home, empty

After Continue, Home is the only tab. There is no tab bar.

Visible on an empty month:

- Title and Settings gear
- Month switcher (current billing cycle)
- Empty copy: “No transactions found!”
- **Add transaction** (always)
- **Scan bill** only when Remote Config `receipt_scan_enabled` is on **and** Apple Foundation Models are available on the device
- Insights button only when `insights_enabled` is on
- No summary card until the viewed cycle has transactions

Reaching Home is also “first use” for the expense check-in. The app then requests **provisional** notification permission once per install. That grant is quiet: no system alert, so it does not cover the Income sheet. The check-in stays off until they leave the app. Details are in [Return hooks](#return-hooks).

The Income sheet covers this empty Home about 1.5 seconds later, if education is allowed. Users can tap Add transaction or Settings during that 1.5 seconds, which marks navigation busy and **suppresses** the sheet until they return.

**Already logged:** screen `home` on appear, `add_transaction`, `open_settings`, `open_scan`, `open_insights`.

**Not logged:** empty vs non-empty Home, time from Home appear to first tap, or “sheet suppressed because the user navigated away.”

### 3. Overlays that compete on Home

Only one education sheet is active at a time. These also wait for a quiet Home:

| Overlay | When it can show | Blocks |
|---|---|---|
| Education sheets | Home, foreground, settled past launch, no other overlay, 1.5s after landing on Home | Review prompt and App Lock promo |
| App review sheet | Eligibility passed, a trigger fired, 60s of continuous foreground, no busy work, no education sheet | Education and App Lock promo |
| App Lock promo | Lock off, promo never shown, ≥ 5 lifetime transactions, device can authenticate, idle Home (no 60s wait) | Shown as a full-screen cover once per install |

Busy work (Add/Edit transaction, delete, scanner, import/export, categories, recurring, currency setup, clear-data) holds the review prompt and the App Lock promo. Education on Home is also held while navigation is busy.

A new user will not see the review prompt or App Lock promo during first-run education. Those are mid-life interruptions. See [Interrupting prompts](#interrupting-prompts).

---

## Education journeys

Sheets are localized (`en`, `de`, `es`, `fr`). Copy below is English. Outcomes are persisted per journey in UserDefaults. **None of this is sent to Firebase today.** Education analytics is explicitly deferred.

Global rules:

- Lower priority number wins.
- One journey at a time.
- After any outcome, the next sheet needs a new trigger: launch, foreground, transaction added, or recurring rule created. Completed journeys may also resume when the user returns to Home.
- **Declined** is terminal for that journey (Maybe Later, or a swipe on Income).
- **Dismissed** (swipe on Expense, Reminder, or Custom Category) is not terminal. The journey can show again after the next trigger.
- **actionFailed** (opened the form from the sheet, then left without saving) is not terminal. The journey can show again.
- Declined journeys also wait **10 minutes** plus a real trigger, except the Expense follow-up after Income was skipped.
- A journey already in progress is not interrupted. Recurring reminder will not appear if Add Transaction was opened from the Expense sheet.

### Journey map

| Priority | Id | Sheet | Shows when | Primary | Secondary | Swipe | Completes when |
|---|---|---|---|---|---|---|---|
| 0 | `income_setup` | Welcome to SnapLedger | Empty ledger: no transactions, no income, no active recurring income | Add My Income | Maybe Later → **declined** | **declined** | Income saved (one-off or recurring) |
| 4 | `recurring_reminder` | Get a reminder before it's due | User taps Save on an **expense or savings** recurring item with Remind me off, and notification permission is **not determined** or **provisional**. Never for income. Never auto-shown on Home | Yes, remind me | Not Now → **declined** (never again) | **dismissed** (not again this session) | Full permission granted and reminder saved |
| 5 | `expense_setup` | Track your first expense | Income journey is completed **or** declined, and expense count is still 0 | Add Expense | Maybe Later → **declined** | **dismissed** (can return) | An expense is saved |
| 10 | `custom_category` | Organize your spending your way | ≥ 3 transactions and zero custom categories | Create Category | Maybe Later → **declined** | **dismissed** | A custom category is created |

### Income Setup — the first value ask

Copy:

- Title: “Welcome to SnapLedger 👋”
- Body: “Let's get your finances started. Adding your regular income gives SnapLedger a better understanding of your finances and helps personalize your dashboard.”
- Primary: “Add My Income”
- Secondary: “Maybe Later”

Primary opens Add Transaction with **type = income** and **recurring = on**. The sheet itself does not save anything. Completion happens only when income is actually saved.

Churn-relevant branches:

| User action | Journey result | What they see next | Risk |
|---|---|---|---|
| Save income | `completed` | Expense sheet when they return to Home | Low, if the form was understandable |
| Maybe Later or swipe | `declined` forever | Expense sheet on the **next launch or foreground**, even inside the 10-minute decline cooldown | They never set income. The app still tries to get an expense |
| Tap Add My Income, then close the form | `actionFailed` | Income sheet can return on the next trigger | Form friction, not sheet rejection |
| Add an expense from the Home button before the sheet | Income becomes ineligible (`transactionsExist`) | Expense sheet never needed if an expense exists; Income will not show | User found the primary button themselves. This is success, not a drop-off |
| Kill app during the 1.5s delay | Sheet never presented | Same sheet next eligible Home visit | Do not count as a decline |

Income is a poor sole activation metric. The sheet asks for salary, but the product’s ongoing loop is expenses. Segment “income completed, expense never saved” separately from “never saved anything.”

### Expense Setup

Copy:

- Title: “Track your first expense”
- Body: “Let's add an expense to get started with your expense tracking.”
- Primary: “Add Expense” — opens Add Transaction as **expense**, recurring **off**
- Secondary: “Maybe Later” — terminal decline

Timing:

- If Income was **completed**, Expense shows when the user comes back to Home (the return itself is a valid trigger).
- If Income was **declined or swiped**, Expense waits for the next **launch or foreground**, and skips the 10-minute cooldown.
- If an expense already exists, the journey never shows.

Swipe is `dismissed`, so a user who flicks the sheet away can see it again. Maybe Later cannot.

### Recurring reminder — permission ask

This is the only education sheet that does not appear on Home. Add Transaction starts it **before** the recurring item is saved, when:

- Type is expense or savings (not income)
- Recurring is on and Remind me is off
- OS notification permission is `notDetermined` or `provisional` (the quiet grant from the expense check-in). Already fully authorized, ephemeral, or denied skips the sheet
- No other journey is in progress
- App is foregrounded and no competing overlay is up

Copy:

- Title: “Get a reminder before it's due”
- Body: “We'll remind you before this transaction happens next time, so you can keep your funds ready.”
- Primary: “Yes, remind me”
- Secondary: “Not Now”

| Choice | Save behavior | Later |
|---|---|---|
| Yes + system Allow | Standard permission prompt (this upgrades provisional to full alerts). Remind me turns on at the default time (9:00 PM the day before the occurrence), item saves, form closes | Journey `completed` |
| Yes + system Deny | Item saves **without** a reminder, form closes | Not eligible again (`notificationPermissionDenied`) |
| Not Now | Item saves without a reminder. If permission is still only provisional, the save **also** raises the standard system prompt | Journey `declined` forever |
| Swipe | Item saves without a reminder. Same provisional upgrade prompt as Not Now | `dismissed`; suppressed for this session; can show on a later save while permission is still undetermined or provisional |

If the user turned Remind me on themselves, the form already requests the standard prompt (including the provisional upgrade) and this sheet does not show.

Creating an expense or savings recurring rule while permission is only provisional always asks for the standard prompt, even when this sheet did not appear. Provisional authorization is what the expense check-in uses, and it never counts as that prompt.

This sheet is the permission upgrade for **bill reminders**. Coming back after inactivity is a separate check-in: a local notification and the Balance widget. See [Return hooks](#return-hooks).

### Custom Category

Copy:

- Title: “Organize your spending your way”
- Body: “Create your own categories to match how you manage your finances.”
- Primary: “Create Category” — pushes Settings → Categories and opens the new-category modal
- Secondary: “Maybe Later” — terminal

Eligible at 3 transactions regardless of whether Income was completed. Back path is Categories → Settings → Home. Leaving without creating a category is `actionFailed` and can retry. Creating a category completes it even if they never saw the sheet.

### Deferred education (not in the product)

Widget, receipt scanner, and Insights have **no** education sheets. Users must discover the scan button, the Insights chart button, and the widget gallery on their own. Absence of a prompt is itself a churn hypothesis for those features.

### Education context the engine already knows (not analytics)

`CampaignContext` includes transaction count, expense count, income flags, recurring-income flag, reminder-eligible recurring count, reminder-enabled flag, notification authorization, and custom category count. `daysSinceInstall`, `receiptScanCount`, and `isWidgetInstalled` are reserved and not filled. Do not assume those exist as user properties.

---

## Feature surfaces

Each section is: what the user can do, what “success” looks like, where they abandon, and what is logged.

### Home dashboard

The home screen is the retention surface. People who do not understand it have nowhere else to go.

| Control | Behavior | Logged |
|---|---|---|
| Settings gear | Pushes Settings | `open_settings` |
| Month arrows and horizontal swipe | Moves one billing cycle. Past is unlimited. Future stops at **+12** cycles (`maxFuturisticRange`) | `report_period_changed` (`navigation_method` `arrow` or `swipe`, `direction`) |
| Summary card | Shown only when the cycle has transactions. Front: exact balance, compact income (if any), compact savings and expenses. Back: expense donut. Flip state persists across month swipes | `flip_summary_card` |
| Transaction row | Opens edit | `open_transaction` |
| List options | Group by category, sort asc/desc, filter expense/income/savings (on by default), upcoming recurring (off by default). Persisted. Filters affect the list only; the balance card stays full-cycle | `open_list_options` and one event per toggle |
| Search | Magnifying glass replaces the header with a field. Matches **title and merchant only** (not category, not amount). Hides the bottom bar while active | `search_transactions` on open only. Query is not logged (correct). No “zero results” event |
| Scroll | Hides the bottom Add/Scan bar. A scroll-to-top button appears when the summary card is offscreen | `scroll_to_top` |
| Add transaction | Pushes a blank form (expense, recurring off) | `add_transaction` |
| Scan bill | Pushes the scanner. Hidden when the flag is off or Foundation Models are unavailable | `open_scan` + `feature_exposure` |
| Insights | Chart button, flag-gated | `open_insights` + `feature_exposure` |
| Upcoming row | Visible when “Upcoming” is on. Tap opens the recurring editor. Does not create a transaction | `open_upcoming_recurring` |

Empty cycle: no summary card, full-height “No transactions found!” Upcoming rows can still show if that filter is on.

**Churn notes:**

- Month swipe is a primary navigation gesture and is invisible in analytics. Arrow taps undercount month browsing.
- Search that matches only title/merchant will return nothing for category words (“food”). That feels like missing data.
- The Add button hides on scroll. On a long month this is a real miss for the core action.
- Scan invisibility on devices without Apple Intelligence is silent. Those users never see the button, so `open_scan` cannot measure demand.

### Add and edit transaction

This is the activation form. Required fields: **amount** and **description**. Category always has a default, so it never blocks save. Merchant is optional and only kept for **expenses**.

| Field | Default on a blank add | Notes |
|---|---|---|
| Type | Expense, unless education or a prefill set it. Order: Expense, Savings, Income | Changing type swaps the category list |
| Date | Today | |
| Description | Empty. Focused on create | Suggestions from history after typing. Picking one can fill category |
| Merchant | Empty. Expense only | Suggestions fill merchant only. AI infers a merchant on blur when Apple Intelligence is available, description ≥ 3 characters, and the user has not edited merchant |
| Amount | Empty | Exact currency formatting. This is the field most likely to block save |
| Category | Expense → Other. Income → Other Income. Savings → General Savings | AI classification on description blur if the user has not picked a category and the title is not an exact history match. Manual pick sticks |
| Recurring | Off, except Income education turns it on | Frequencies: daily, weekly, every 2/3/4 weeks, monthly, every two months, quarterly. Optional end date |
| Remind me | Off until toggled. Default time **9:00 PM the calendar day before** the occurrence | Shown with recurring. Turning it on requests the standard notification prompt. Provisional permission is treated as not yet prompted |

Save paths:

- Not recurring, new: writes a transaction, updates suggestion history, dismisses.
- Recurring, new: writes a **rule**, then materializes due occurrences (including one for today when it is due).
- Edit: updates the transaction. Delete is a confirmed destructive action on edit only.

Education reminder sheet can intercept Save (see above) and then still save.

Entry points that should be distinct sources:

| Source | How the form opens |
|---|---|
| `home` | Add transaction button |
| `education_income` | Income sheet primary. Type income, recurring on |
| `education_expense` | Expense sheet primary. Type expense, recurring off |
| `scan` | Scanner confirm |
| `share_text` / `share_image` | Share extension success |
| `widget_add` | Plus widget. URL has no `family`, so it is not attributed |
| `widget_balance` | Balance reminder tap. URL is `snapledger://add-transaction?family=systemSmall` or `systemMedium` |
| `notification` | Expense check-in tap, and only when Home’s stack is empty |
| `edit` | Tap a row |

**Logged:** screen `add_transaction` or `edit_transaction`, `transaction_form_opened`, `transaction_form_cancelled` (explicit close), `transaction_form_abandoned` (inferred: navigation pop or 30-minute background timeout), `first_transaction_saved` on the first successful create, `txn_save` (`txn_type`, `source`, `mode`, `recurring`, `reminder`), `transaction_save_failed`, `transaction_validation_failed` (inline end-date and reminder errors), `transaction_deleted`, `category_changed`, `recurring_setup_started`, plus the `save_transaction`, `delete_transaction`, `scan_bill_from_form`, `add_category` clicks.

**Not logged:**

- Suggestion picked, AI category applied, AI merchant applied
- Empty amount or description (the Save button is simply disabled)
- Which frequency was chosen

### Bill scanner

Home button and a control on the add form. Requires Foundation Models and `receipt_scan_enabled`.

1. Take Photo or Select from Library
2. Vision OCR, then the on-device model extracts merchant, total, date
3. Preview, then Add Transaction prefilled
4. Failure shows an error; the user can retry or type manually

**Logged:** screen `scan`, `take_photo`, `select_library`, `bill_scan_started`, `bill_scan_failed` (`stage`, `failure_reason`), `bill_scan_preview_shown`, `bill_scan_abandoned` (`capture` or `preview`), and the save as `txn_save` `source=scan`. Scan unavailability logs `feature_unavailable`.

**Not logged:** camera vs library on the result event, or camera permission denial.

Share-image uses the same pipeline. Text share is separate (`share_text_analyze_*`).

### Share to SnapLedger

From another app’s share sheet, text or a single image:

1. Extension writes the App Group inbox and opens `snapledger://share-inbox`
2. Analyzing overlay
3. Text: model decides “transaction-related” and extracts fields. Image: receipt pipeline
4. Success opens Add Transaction prefilled
5. Failure alerts and does not open the form

Text results: `empty`, `not_related`, `success`, `failed`. Image shares run the scan funnel with `source=share_image`. Saves carry `txn_save` `source=share_text` or `share_image`.

**Churn note:** `not_related` means the person tried to share something the model rejected. That is a product-expectation failure, not a crash. Pair it with a later `txn_save` `source=home` in the same session.

### Recurring transactions

Created from the add form, or managed in Settings → Recurring Transactions.

- Rules process on launch and when the app returns to foreground, inserting due transactions.
- Pause, resume, skip, edit, delete from the manage screen.
- Home “Upcoming” previews remaining occurrences in the viewed cycle without writing them.
- Insights can suggest potential recurring bills (loan, EMI, subscription, rent, utility, confidence ≥ 80) and offer “make recurring” or “not recurring.” Dismissals are stored and exported with backups.

**Logged:** screen `recurring` and `edit_recurring`; buttons pause, skip, edit, delete, save; `recurring_setup_started`; `txn_save` `mode=recurring_create` with `source` (add form or `insights_suggestion`) and `reminder`; `recurring_schedule_changed`; `recurring_transaction_paused`; `insight_action_selected` (`make_recurring`, `not_recurring`). The education reminder outcome is in the education events.

**Not logged:** frequency value, or resume as a state change.

Recurring is the strongest habit signal in the product. A user with only one-off expenses has to remember to open the app. A user with an active rule gets new rows without typing, and optionally a notification.

### Categories

Built-in:

- Expense: Food, Transport, Shopping, Health, Bills, Other (Other cannot be deleted)
- Savings: General Savings (protected), Emergency Fund, Vacation, Home, Investments
- Income: Salary, Business, Gifts, Rewards, Investments, Other Income (protected)

Custom: Settings → Categories, or the add-form shortcut. Name, type, SF Symbol, color. In-use categories cannot be deleted until nothing references them.

**Logged:** screen `manage_categories`, `edit_category`; buttons add/edit/delete; events `category_created` (`category_type`), `category_edit`.

**Not logged:** education vs settings as the source, or delete failure because the category is in use.

### Insights

Opened from the Home chart button when `insights_enabled`.

Phases: loading skeleton → empty (“No insights yet” / “Add income and expense transactions…”) → ready.

Ready content, in order, when data exists:

| Block | What the user sees | Depends on |
|---|---|---|
| Expense trend | Cumulative daily expenses for the current year, optional projection | Any expense trend points |
| Financial health | Stars and `X.X/5.0` from five deterministic parts: savings, spending discipline, subscriptions, stability, trend. Narrative is explanation only | Meaningful snapshot |
| Biggest changes | Category vs recent average (↑ ↓ ≈) | History |
| Top merchants | Ranked spend | Merchants on expenses |
| Category health | This cycle vs usual. Bands: &lt;80% green, 80–105% yellow, 105–120% orange, &gt;120% red | Complete lookback months |
| Forecast | Expected income, spending, savings | Snapshot |
| Events | Rare spikes and annual-style one-offs | Detection |
| Potential recurring | Suggestions with make-recurring / not-recurring | Detection, not already dismissed |
| Opportunities and wins | Short coaching when the model is available | Narrative generation |

Lookback uses up to the **three cycles before the current one**. A lookback cycle under **70%** of peer volume is treated as incomplete and excluded. Cache reuses results until transactions, rules, calendar day, or currency change.

Health copy uses a savings-rate guide of **20–30%** of income and a subscription guide of about **5–10%** of expenses. These are scoring bands, not user-set budgets.

**Logged:** screen `insights` on appear, `insights_viewed` with `state` (`empty`, `ready`, `error`), `insight_action_selected` for potential recurring, and `slow_operation` `insights_generate` at ≥ 2s. Generating insights also feeds the review engine (`review_trigger_insights` once).

**Not logged:** which cards rendered, narrative success vs fallback, or time on screen.

### Return hooks

Three local mechanisms bring someone back. There is no remote push. Release timing is below. Debug builds fire sooner (notification 30 minutes after background; widget gentle at 30 minutes and overdue at 1 hour, including later the same day) and show a “Version 1 / Version 2” label on the widget. Do not mix Debug analytics with Release cohorts.

#### 1. Expense check-in notification

Settings → Transactions → **Expense check-in**. Default **on**. Subtitle: “A quiet reminder at 7:00 PM if you have not opened SnapLedger for 24 hours.”

| Rule | Behavior |
|---|---|
| Who can be scheduled | Currency has been saved (the same gate as leaving Choose your currency). An expense is not required |
| Permission | Once, after that gate, the app requests authorization with `.provisional`. That grants a **quiet** notification and does not show the system alert. One attempt per install |
| When it fires | After the app backgrounds: 24 hours after the last foreground, then the next local **7:00 PM**. Time-zone changes reschedule |
| Copy | Title “A quick expense check-in”. Body “Had any expenses recently? Take a moment to log them in SnapLedger and keep your spending records up to date.” |
| One shot | Opening the app cancels the pending request and removes the delivered banner. A new one is scheduled only after the next background. It does not repeat while the person stays away |
| Tap | Logs the open and tries to push Add Transaction. The form opens only when the route is Home **and** the navigation stack is empty. If Settings, Insights, or another screen is already up, the tap is consumed and the form does not open |
| Save | `check_in_conversion` fires if they save an **expense** (not income, savings, an edit, or a recurring-generated row) within 24 hours of the tap, including a later session. A later tap replaces the marker; conversion is counted once per marker |
| Off | The Settings toggle cancels a pending notification and also turns off the Balance widget reminder. The toggle logs `check_in_preference_changed` |
| Clear data | Removes every pending notification, including recurring reminders, and restarts this window from now |

**Logged:** `check_in_eligible`, `check_in_schedule_result`, `check_in_cancelled`, `check_in_opened`, `check_in_conversion`, `check_in_preference_changed`. Lifecycle events carry `campaign_version` (currently `1`). Eligible and scheduled log once per fire date. Cancelled carries `cancellation_reason`.

| `cancellation_reason` | Meaning | Do not read it as |
|---|---|---|
| `app_open` | They came back, so the pending check-in was cleared | Opt-out. This will be the common reason |
| `disabled` | They turned Expense check-in off | |
| `authorization_denied` | Permission does not allow scheduling | |
| `rescheduled` | Fire date changed, or a delivered banner was still pending | |
| `policy_changed` | Campaign version changed | |
| `inactive` | Check-in is on but first use (saved currency) is not done | |

`check_in_opened` carries `notification_type=expense_check_in`. It does not mean the Add form appeared; a dropped form shows as no `transaction_form_opened` with `source=notification`.

#### 2. Balance widget check-in

The same Expense check-in toggle feeds an App Group activity file (`lastAppOpenAt`, `lastExpenseSavedAt`, `remindersEnabled`). The Balance widget timeline moves itself while the app is closed.

Activity time is the later of the last app open and the last **expense** save. With the toggle off, the widget stays on the normal balance.

| State | When (Release) | What the widget shows |
|---|---|---|
| Normal | Sooner than 24 hours, and never on the same calendar day as the last open (daylight-saving fallback) | Balance, savings, expenses |
| Gentle | 24 hours after activity, not before the next calendar day | Check-in copy. Same words as overdue |
| Overdue | 48 hours after activity | Same copy as gentle |

Copy does not change between gentle and overdue in Release:

- Small: title “A quick check-in”, message “Log your expenses to keep your totals up to date.”, action “Add expense”. The **whole** small widget is replaced and opens `snapledger://add-transaction?family=systemSmall`.
- Medium: balance stays. The savings/expenses row is replaced by “Keep your spending up to date” / “A quick expense entry helps keep your monthly totals accurate.” / “Add expense”. That card opens `snapledger://add-transaction?family=systemMedium`. A tap outside the card still opens Home and is **not** attributed.

Both sizes share one activity clock.

**Logged:** `widget_destination_opened` (`widget_type=balance`, `destination`, `widget_family`). `widget_transaction_saved` with the same `widget_family` if they save an expense before backgrounding. The family is forgotten on background, so a later save is not attributed.

**Not logged:** which state was showing (gentle vs overdue), widget install or removal, and the privacy Show/Hide control.

#### 3. Recurring bill reminder

Unchanged job: a local notification for a specific recurring expense or savings rule, default **9:00 PM the day before** the occurrence. Reconciled on launch and when rules change. Denied permission sends the user to system Settings from the form. Tapping the notification schedules the next occurrence; it does not open Add Transaction and it is not an analytics event.

Provisional permission from the expense check-in is not enough for this path. The education sheet and the recurring save both ask for the standard prompt so the quiet grant does not skip it.

### App Lock

Optional Face ID / device passcode.

- Toggle in Settings → Privacy & Security. Enabling and disabling both require authentication.
- After enable, lock on the next real background once the **1 hour** grace period has expired. A privacy cover hides content in the app switcher while locked.
- Soft-sell promo: once per install, after **5** lifetime transactions, only if lock is off and the device can authenticate, and only when Home is idle (education and review are not up).
- Promo primary: enable (runs the auth sheet). Secondary: Not Now. Either way the promo never returns.
- Deep link `snapledger://settings/app-lock` focuses the toggle.

**Logged:** promo screen and presented/enable/dismiss events; `app_lock_enabled` / `app_lock_disabled` with `source`; `app_lock_auth_result` (`result`, `method`, `operation`) for every unlock, enable, and disable attempt.

### Widgets

Two widgets are registered. The Balance check-in states are in [Return hooks](#return-hooks).

| Widget | Sizes | Tap when not in a check-in |
|---|---|---|
| Total Balance | Small: period, compact balance, savings and expenses stacked. Medium: balance with optional `/ income`, savings and expenses side by side. Privacy masks amounts when Hide Financial Information is on | `snapledger://home` |
| Add Transaction | Small, plus button | `snapledger://add-transaction` with no `family`. Opens the form and emits `widget_destination_opened` `widget_type=add` |

A donut widget kind exists in code and is **not** in the widget bundle.

Settings → Hide Financial Information masks Balance amounts until the user taps Show (30 seconds, then hides again). That control is not logged. `isWidgetInstalled` is still not populated, so “has a widget” is only inferred when a family URL is opened.

### Settings, data, and feedback

| Item | User effect | Logged |
|---|---|---|
| Currency | Display currency for the app and widgets | `open_currency`, `select_currency` |
| Number format | Auto (India → lakhs/crores, else millions), or forced. Compact only. Lists and forms stay exact | Screen not logged. Changes not logged |
| Monthly cycle | Start day 1–30. Default is the 1st (calendar month). Short months clamp. Changes Home, Insights, and widgets | Screen not logged. Changes not logged |
| Categories | Manage list | `manage_categories` |
| App Lock | See above | toggle events |
| Widget privacy | Mask widget amounts | Not logged |
| Expense check-in | Default on. Schedules the 7:00 PM inactivity notification and the Balance widget reminder. Off cancels both | `check_in_preference_changed`, and `check_in_cancelled` with `disabled` |
| Recurring | Manage rules | `manage_recurring` |
| Export | JSON backup, schema version 7: transactions, rules, custom categories, currency, dismissals | `export_backup` click, `export_started` / `export_completed` / `export_failed`. Gated by `export_import_enabled` |
| Import | Restore a compatible backup | click, `data_import_completed` (`record_count_bucket`) / `data_import_failed`. Failure also marks a critical error for this session (suppresses the review prompt) |
| Send Feedback | Free text to Firestore `feedback`, plus coarse counts (transactions, recurring count, launches, days since install, receipt scans, anonymous user id, app version, device, locale). No amounts or descriptions | `send_feedback`, then `review_feedback_submitted` or an inline error |
| Privacy / Terms | In-app legal | `open_privacy`, `open_terms`, screens `legal_privacy`, `legal_terms` |
| Clear Local Data | Deletes local transactions, recurring rules, and custom categories. Also removes every pending notification and restarts the expense check-in window | `clear_local_data` click, `clear_data_confirm` on confirm, then `local_data_clear_completed` or `local_data_clear_failed`. User properties refresh. `first_transaction_saved` is not reset |

Clear data and export are the two explicit “I am done or I do not trust this” actions. Put them on a churn board next to inactivity.

### Deep links

| URL | Lands on | Analytics |
|---|---|---|
| `snapledger://home` | Home, stack popped | `widget_destination_opened` `widget_type=balance`, `destination=home` |
| `snapledger://add-transaction` | Add form | `widget_destination_opened` `widget_type=add`. Saves carry `source=widget_add` |
| `snapledger://add-transaction?family=systemSmall` or `systemMedium` | Add form, stack popped | `widget_destination_opened` `widget_type=balance` with `widget_family`. Saves carry `source=widget_balance` |
| `snapledger://share-inbox` | Process share inbox | Share analyze events, not the URL |
| `snapledger://settings/app-lock` | Settings, App Lock row highlighted | None for the URL |

An expense-check-in tap is not a URL. It sets an in-app “open Add Expense” flag. See [Return hooks](#return-hooks).

### Remote Config

Fetched at launch and on foreground. Defaults are all on. Offline uses the last value or the default.

| Key | Hides |
|---|---|
| `insights_enabled` | Insights button and route |
| `receipt_scan_enabled` | Scan button and route |
| `export_import_enabled` | Export and import rows |

`feature_exposure` fires when the user **uses** Insights, Scan, or Export/Import, with `enabled=true`. It does not fire when the control is hidden. A flag rollout will look like a sudden drop in clicks, which is correct, but you cannot see “button hidden” as its own event unless you log exposure on Home appear.

### Apple Intelligence gate

Foundation Models availability is a device fact, not a user choice. When unavailable:

- Scan button is hidden
- AI category and AI merchant do not run
- Insights numbers still render; narratives stay empty or generic
- Potential-recurring detection falls back to heuristics

This splits the user base into two products. Any funnel for scan or AI coaching must be cut by this flag, or “never scanned” will be dominated by devices that could not scan.

### Review and feedback prompt

Not onboarding. It is a mid-life interruption and a possible annoyance churn source.

Eligible only when all of these are true:

- ≥ **7** days since install
- ≥ **8** launches (cold start increments launch count)
- ≥ **20** lifetime transactions (reconciled from the local store, so imports count)
- User has not already been sent to the App Store review page
- No critical error this session (import failure and similar)

Then a trigger must fire:

| Priority | Trigger | When |
|---|---|---|
| 1 | Insights generated | First time insights are generated |
| 2 | 7-day streak | 7 consecutive days the app was opened or foregrounded; evaluated on launch/foreground |
| 3 | Transaction milestones | 20, 50, 100, 250, 500 adds since the counter started. Counter resets after 500 |
| 4 | Receipt milestones | 20, 50, 100 successful scans. Counter resets after 100 |

The sheet waits until the user has been in the foreground for **60 continuous seconds**, not in a busy flow, and no education sheet is up.

Sheet: “loving it” → App Store review (never ask again) or “have a suggestion” → feedback form. Dismiss starts a **30-day** cooldown. Submitted feedback waits until the **next app version**.

**Logged well:** eligibility pass/fail with reason, which trigger, presented, positive, negative, feedback submitted/cancelled, dismiss, App Store opened.

Use `review_eligibility_failed` reasons (`daysSinceInstall`, `launchCount`, `lifetimeTransactions`, `cooldown`, `appStoreOpened`, `criticalErrorThisSession`) as a health metric, not as churn. Use dismiss-then-inactivity as a churn hypothesis.

---

## What is already logged

Firebase Analytics, event names exactly as in `AppAnalytics`.

### Screens

`home`, `insights`, `add_transaction`, `edit_transaction`, `manage_categories`, `edit_category`, `settings`, `scan`, `currency_selection`, `currency_list`, `recurring`, `edit_recurring`, `legal_privacy`, `legal_terms`, `feedback_flow`, `send_feedback`, `app_lock_promo`.

Missing screens: number format, monthly cycle, App Lock unlock cover, share analyzing overlay, currency setup is covered, education sheets are not screens.

### `button_click` (`button`, `source`)

`add_transaction`, `open_settings`, `open_insights`, `open_scan`, `scroll_to_top`, `flip_summary_card`, `open_transaction`, `save_transaction`, `delete_transaction`, `scan_bill_from_form`, `take_photo`, `select_library`, `export_backup`, `import_backup`, `manage_categories`, `manage_recurring`, `open_currency`, `open_privacy`, `open_terms`, `send_feedback`, `clear_local_data`, `currency_continue`, `select_currency`, `exclude_recurring_toggle`, `add_category`, `edit_category`, `delete_category`, `pause_recurring`, `skip_recurring`, `edit_recurring`, `delete_recurring`, `save_recurring`, `group_by_date`, `group_by_category`, `open_list_options`, `toggle_group_by_category`, `toggle_show_upcoming_recurring`, `toggle_filter_expense`, `toggle_filter_income`, `toggle_filter_savings`, `set_sort_ascending`, `set_sort_descending`, `open_upcoming_recurring`, `search_transactions`, review buttons, app-lock promo and toggle.

`group_by_date` and `exclude_recurring_toggle` are defined. Confirm they still fire before you build a chart on them; the list menu now logs `toggle_group_by_category` and the upcoming toggle.

### Outcome events

Names follow the SnapLedger Analytics & App Instrumentation Specification. Old names (`txn_delete`, `receipt_scan_*`, `category_add`, `export_backup` / `import_backup` events, `expense_reminder_*`, `widget_add_expense_opened`, `widget_expense_saved`) were hard-renamed and are no longer sent. Outcome events fire only after persistence returns success.

Shared parameter values:

- `source` (transactions): `home`, `education_income`, `education_expense`, `scan`, `share_text`, `share_image`, `widget_add`, `widget_balance`, `notification`, `insights_suggestion`, `edit`
- `mode`: `create`, `edit`, `recurring_create`
- `failure_reason`: `validation`, `persistence`, `permission_denied`, `unsupported_format`, `unavailable`, `unexpected`, `form_closed`, `no_text_found`, `invalid_image`
- `state`: `empty`, `ready`, `error`
- Buckets: `txn_bucket` `0`/`1`/`2_5`/`6_20`/`21_plus`; `record_count_bucket` `0`/`1_10`/`11_100`/`101_1000`/`1001_plus`; `duration_bucket` `lt_1s`/`1_3s`/`3_10s`/`gt_10s`; `slow_operation` uses `2_3s`/`3_10s`/`gt_10s`; `hours_since_install_bucket` `lt_1h`/`1_24h`/`1_3d`/`gt_3d`

#### Transaction lifecycle (P0)

| Event | Parameters |
|---|---|
| `transaction_form_opened` | `txn_type`, `source`, `mode`. Once per form presentation |
| `transaction_validation_failed` | `txn_type`, `source`, `field` (`end_date`, `reminder_time`), `reason`. Once per field per form |
| `txn_save` | `txn_type`, `source`, `mode`, `recurring`, `reminder` (`true`/`false`/`na`). Also covers Insights “Make recurring” (`source=insights_suggestion`, `mode=recurring_create`) |
| `transaction_save_failed` | `txn_type`, `source`, `failure_reason=persistence` |
| `transaction_form_cancelled` | `txn_type`, `source`, `mode`. Explicit close only. Not logged on background |
| `transaction_form_abandoned` | `txn_type`, `source`, `mode`, `stage` (`empty`, `partially_filled`, `ready_to_save`), `exit_reason` (`background_timeout`, `navigation`). Inferred unfinished forms only; never with cancelled for the same exit. Backgrounding stores a marker and does not log until return after 30 minutes, or the next launch |
| `first_transaction_saved` | `txn_type`, `source`, `hours_since_install_bucket`. Once per install after the first successful non-edit save. `txn_save` still fires |
| `transaction_deleted` | `txn_type`, `source` |
| `category_changed` | `change_source=edit_form`. Edit save where the category changed |

#### Education (P0)

| Event | Parameters |
|---|---|
| `education_presented` | `journey`, `trigger` (`home_visit`, `recurring_save`) |
| `education_action_selected` | `journey`, `action` |
| `education_dismissed` | `journey`, `dismiss_method` (`secondary_button`, `swipe`) |
| `education_completed` | `journey`. First transition to completed only |
| `education_action_failed` | `journey`, `failure_reason=permission_denied`. Recurring reminder only |
| `education_action_cancelled` | `journey`, `reason=form_closed`. Form-based journeys where the user closed the form |

#### Activation (P0)

| Event | Parameters |
|---|---|
| `app_setup_completed` | `setup_path=currency_selected`. Once per install, after the selected currency is persisted |
| `home_state_viewed` | `state`, `txn_bucket`. Once per foreground visit after data resolves |

#### Feature funnels (P1)

| Event | Parameters |
|---|---|
| `bill_scan_started` | `source` (`home`, `add_form`, `share_image`) |
| `bill_scan_preview_shown` | `result=success`, `source`. Prefilled form shown from a scan |
| `bill_scan_abandoned` | `stage` (`capture`, `preview`), `reason` |
| `bill_scan_failed` | `stage` (`ocr`, `extraction`), `failure_reason` |
| `share_text_analyze_start` / `share_text_analyze_result` | `result`: `empty`, `not_related`, `success`, `failed` |
| `insights_viewed` | `state` (`empty`, `ready`, `error`). Once per distinct rendered state per visit, not while loading. Error adds `failure_reason=persistence` |
| `insight_action_selected` | `action_type` (`make_recurring`, `not_recurring`) |
| `recurring_setup_started` | `txn_type`, `source` |
| `recurring_schedule_changed` | One event per successful save. `change_type` is the single field or `multiple`; `changed_fields` is the sorted comma-joined set (`frequency`, `start_date`, `end_date`, `reminder`) |
| `recurring_transaction_paused` | `source=recurring_list` |
| `transaction_search_used` | `entry_point=home`. First non-empty debounced query per search session. The query is never sent |
| `transaction_search_result` | `result` (`match`, `no_match`). Last applied query when the search session ends |
| `report_period_changed` | `navigation_method` (`arrow`, `swipe`), `direction` (`next`, `previous`) |
| `category_created` | `category_type` |
| `category_edit` | none |
| `export_started` / `export_completed` / `export_failed` | `format=json`; failure adds `failure_reason` |
| `data_import_completed` | `result=success`, `record_count_bucket` |
| `data_import_failed` | `failure_reason` |
| `clear_data_confirm` | none. User confirmed the wipe; deletion has not run yet |
| `local_data_clear_completed` | `source=settings`, `result=success`. After SwiftData wipe succeeds. User properties refresh afterward. Does not reset `first_transaction_saved` |
| `local_data_clear_failed` | `failure_reason=persistence` |

#### Notifications and widgets (P1)

| Event | Parameters |
|---|---|
| `check_in_eligible` | `campaign_version`, `trigger_reason=inactivity_24h`. Once per fire date |
| `check_in_schedule_result` | `campaign_version`, `result` (`success`, `failed`); failure adds `failure_reason` |
| `check_in_cancelled` | `campaign_version`, `cancellation_reason` |
| `check_in_preference_changed` | `enabled` |
| `check_in_opened` | `notification_type` (`expense_check_in`, `recurring_reminder`) |
| `check_in_conversion` | `campaign_version`, `action_type=expense_saved`, `window=24h`. Once per tap marker; a later tap restarts the window. Counts a qualifying expense save even in a later session, until expiry |
| `widget_destination_opened` | `widget_type` (`add`, `balance`), `destination` (`home`, `add_transaction`), `widget_family` when known |
| `widget_transaction_saved` | `txn_type`, `source=widget_balance`, `widget_family` |
| `widget_action_failed` | `widget_type`, `failure_reason=unavailable` (stack not at Home root) |

#### Security, diagnostics, review (P2)

| Event | Parameters |
|---|---|
| `app_lock_enabled` / `app_lock_disabled` | `source` (`settings`, `deep_link`) |
| `app_lock_auth_result` | `result` (`success`, `failed`, `cancelled`), `method` (`face_id`, `touch_id`, `optic_id`, `passcode`), `operation` (`unlock`, `enable`, `disable`) |
| App Lock promo | `app_lock_promo_presented`, `app_lock_promo_enable`, `app_lock_promo_dismiss` |
| `feature_unavailable` | `feature`, `reason` (`remote_config_off`, `apple_intelligence_unavailable`). Once per session per pair |
| `app_startup_completed` | `destination` (`home`, `currency_setup`), `duration_bucket`. Once per launch |
| `slow_operation` | `operation` (`scan`, `import`, `export`, `insights_generate`). Only at ≥ 2s. `duration_bucket` is `2_3s`, `3_10s`, or `gt_10s` |
| `feature_exposure` | `feature_key`, `enabled`. Means the feature was opened or invoked, not that it is merely available. Name kept so existing GA4 reports keep working |
| Review events | milestone / streak / eligibility `reason` where noted above |

Crashlytics non-fatals (`AppDiagnostics.recordNonFatal`) cover persistence, import, export, scan, category save, and insights failures. They carry only operation, feature, reason, and the underlying error domain and code — never the error description.

Firebase automatic events you can use without new code: `first_open`, `session_start`, `user_engagement`, `screen_view`, `app_remove` where the platform provides it (unreliable on iOS).

#### User properties

Refreshed on foreground and after data changes: `has_expense`, `has_income`, `has_recurring` (`true`/`false`), `txn_bucket`, `notifications_authorized` (`yes`, `no`, `provisional`, `unknown`), `app_lock_enabled`, `expense_check_in` (`enabled`, `disabled`). User id is the anonymous identity; no unique ids are set as user properties.

---

## Instrumentation gaps

Ordered by how much they block a churn explanation.

The spec rollout and the advancement brief closed education outcomes, first-transaction activation, inferred form abandonment, Insights empty/ready/error, 24-hour check-in conversion, local-data-clear completion, and latency-bucket alignment. What remains:

| Gap | Why churn analysis needs it |
|---|---|
| `installationId` not attached | Reinstall with a surviving Keychain id looks like the same user suddenly empty |
| Widget install and Home-widget taps without a deep link | Only deep-linked widget taps are logged; installs are not observable, and gentle vs overdue is not a parameter |
| Widget refresh outcome | WidgetKit does not report reload success, so the spec’s widget refresh result is not emitted |
| System notification prompt result | Provisional grant and the system prompt answer are only visible via `notifications_authorized` on the next refresh |
| Number format and monthly cycle changes not logged | Cycle start day changes what “this month” means; confused users may think data disappeared |
| Currency, locale, Apple Intelligence user properties | Not set, to keep user properties to the spec list. `feature_unavailable` covers Apple Intelligence per session |
| Validation for disabled Save | Save is disabled until required fields are filled, so only inline date/reminder errors produce `transaction_validation_failed` |

Intentionally not emitted because they would duplicate `txn_save`: `meaningful_action`, `transaction_edited`, `bill_scan_saved`, `recurring_transaction_created`. Derive them from `txn_save` `mode` and `source`.

---

## Funnels to build

### Activation (first 24 hours and first 7 days)

1. `first_open`
2. `screen_view` `currency_selection` (skip if absent — returning or already set)
3. `button_click` `currency_continue`
4. `app_setup_completed`
5. `home_state_viewed` (`state=empty` for new installs)
6. `education_presented` `journey=income_setup`
7. `education_completed`, `education_dismissed`, `education_action_cancelled`, or `education_action_failed` for that journey
8. `first_transaction_saved` (activation). `txn_save` still fires for this and every later save
9. Second `session_start` on a later calendar day with a meaningful action (repeat user)

Cut by the `has_*` and `txn_bucket` user properties; use `feature_unavailable` to split Apple Intelligence devices.

### First expense path

Compare `txn_save` by `source`, with `transaction_form_opened` → `transaction_form_cancelled` (explicit close) or `transaction_form_abandoned` (inferred) as the drop:

- Education primary → save
- Home Add button → save
- Scan or share → save

The education path can fail in the sheet (decline) or in the form (abandon). Those are different fixes.

### Habit

Among users with ≥ 1 expense:

- % with `txn_save` `mode=recurring_create` within 7 days
- % with `notifications_authorized=yes` rather than only `provisional`
- % with a session on day 7
- % with `insights_viewed` `state=ready`

### Return

Among users who reached Home (currency saved) and then went quiet:

1. `check_in_schedule_result` `result=success`
2. `check_in_opened` `notification_type=expense_check_in` (they tapped) or `check_in_cancelled` with `app_open` (they came back some other way) or no further event (the one shot was ignored)
3. `check_in_conversion` — a qualifying expense save within 24 hours of the tap, including a later session

Widget return, only for people who have a widget:

1. `widget_destination_opened` (`widget_type`, `destination`, `widget_family`)
2. `widget_transaction_saved` or `txn_save` with `source=widget_add` / `widget_balance`
3. `widget_action_failed` when the tap could not open the form

Do not treat `app_open` cancellations as failed reminders. That reason means the check-in worked or they returned on their own.

### Rage or exit

Watch, per user, before a 14-day gap:

- `clear_data_confirm` then `local_data_clear_completed` or `local_data_clear_failed`
- `data_import_failed` or `export_failed`
- `bill_scan_failed` / `bill_scan_abandoned` or `share_text_analyze_result` `not_related` with no later `txn_save`
- `transaction_save_failed`
- `review_dismissed` (especially if it was their last session)
- `app_lock_auth_result` `failed` / `cancelled` with `operation=unlock`, then no further sessions

---

## Churn hypotheses, tied to the product

| Hypothesis | Who | Signal that would confirm it | What exists now |
|---|---|---|---|
| Currency wall | New installs who never reach Home | `currency_selection` without `app_setup_completed` | Exists |
| Empty Home, no guidance seen | Killed the app during the 1.5s delay or left Home immediately | `home_state_viewed` `empty`, no `education_presented`, no `txn_save` | Exists |
| Rejected the income ask | Maybe Later / swipe | `education_dismissed` `journey=income_setup` | Exists |
| Form too heavy | Opened add, did not save | `transaction_form_opened` `mode=create` then `transaction_form_cancelled` or `transaction_form_abandoned` | Exists; `stage` and `exit_reason` split empty vs ready-to-save, close vs timeout |
| Income only | Did the sheet, never logged spending | `has_income=true`, `has_expense=false` | Exists |
| Check-in ignored | Currency saved, then no session | `check_in_schedule_result` success with no later `check_in_opened` and no `app_open` cancel | Exists, plus `check_in_preference_changed` |
| Check-in opened, nothing logged | Tapped the notification or widget and left the form | `check_in_opened` or `widget_destination_opened` without `check_in_conversion` / `widget_transaction_saved` | Exists; `widget_action_failed` separates a dropped form |
| No reason to return | Check-in off, no widget, no recurring rule | `expense_check_in=disabled`, `has_recurring=false`, no widget events, then inactivity | Exists |
| Expected scanning | Device cannot run Apple Intelligence, or scan failed | `feature_unavailable` `feature=scan`, or `bill_scan_failed` then inactivity | Exists |
| Insights disappointment | Opened Insights on a thin ledger | `insights_viewed` `state=empty` then no return | Exists |
| Search missed | Looked up something not there | `transaction_search_result` `no_match` | Exists; the query is never logged |
| Month confusion | Non-calendar cycle, or browsing empty future months | `report_period_changed` `next` into empty cycles, or a cycle-start change, then inactivity | Period changes exist; cycle-start change does not |
| Prompt fatigue | Review or App Lock promo was the last thing they saw | Promo or review event, then no session for 14 days | Exists |
| Data distrust | Exported or wiped | `export_completed` or `local_data_clear_completed`, then inactivity | Exists |
| Reinstall amnesia | Came back, ledger empty, did not import | New install on an existing `userId`, `txn_bucket=0`, no `data_import_completed` | Not observable until installation id is attached |
| Widget never discovered | No education and no in-app prompt for adding a widget | Retention higher among `widget_destination_opened` users | Installs are not observable |

---

## Session shape worth recording

If you add one lifecycle event, make it a session summary on background (no PII):

- `education_journey_shown` (id or `none`)
- `txn_created_count` bucket
- `screens`: coarse list or count of distinct screens
- `apple_intelligence`
- `entry`: `cold` | `url_home` | `url_add` | `url_widget_balance` | `notification` | `url_share` | `url_app_lock`

That single event answers “what did a churned user do on their last visit?” which the current click stream only answers after a lot of stitching, and still misses education.

---

*Behavior described here matches the app as implemented: live route is currency setup or Home; education campaigns are `income_setup`, `recurring_reminder`, `expense_setup`, and `custom_category`; the expense check-in and Balance widget reminder share one Settings toggle; analytics names match `AppAnalytics`.*
