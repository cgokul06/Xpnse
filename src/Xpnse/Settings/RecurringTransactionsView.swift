//
//  RecurringTransactionsView.swift
//  Xpnse
//
//  Created by Gokul C on 05/05/26.
//

import SwiftUI

struct RecurringTransactionsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var recurringItems: [RecurringTransaction] = []
    @State private var isLoading = true
    @State private var selectedForEdit: RecurringTransaction?
    @State private var categoryStore = CategoryStore.shared

    private let transactionManager = FirebaseTransactionManager.shared

    private var activeItems: [RecurringTransaction] {
        recurringItems.filter { $0.state == .active }
    }

    private var pausedItems: [RecurringTransaction] {
        recurringItems.filter { $0.state == .paused }
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .tint(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
            } else if recurringItems.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gradientNavigationBackground()
        .navigationTitle("common.recurring")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedForEdit) { item in
            EditRecurringTransactionView(item: item) {
                Task { await reload() }
            }
        }
        .task {
            AppAnalytics.logScreen(AppAnalytics.Screen.recurring)
            await categoryStore.load()
            await reload()
        }
        .onAppear {
            UserEngagementCoordinator.shared.beginBusyWork(.manageRecurring)
        }
        .onDisappear {
            UserEngagementCoordinator.shared.endBusyWork(.manageRecurring)
        }
    }

    private var listContent: some View {
        List {
            if !activeItems.isEmpty {
                Section {
                    ForEach(activeItems, id: \.id) { item in
                        recurringRow(item)
                    }
                } header: {
                    sectionHeader(L10n.tr("common.active"))
                }
            }

            if !pausedItems.isEmpty {
                Section {
                    ForEach(pausedItems, id: \.id) { item in
                        recurringRow(item)
                    }
                } header: {
                    sectionHeader(L10n.tr("common.paused"))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AdaptiveBrandSurface.mutedForeground(for: colorScheme))
            .textCase(nil)
    }

    @ViewBuilder
    private func recurringRow(_ item: RecurringTransaction) -> some View {
        RecurringTransactionRowView(item: item)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .contentShape(Rectangle())
            .onTapGesture {
                AppAnalytics.logButtonClick(AppAnalytics.Button.editRecurring, source: AppAnalytics.Screen.recurring)
                selectedForEdit = item
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if item.state == .active {
                    Button {
                        AppAnalytics.logButtonClick(AppAnalytics.Button.skipRecurring, source: AppAnalytics.Screen.recurring)
                        Task {
                            await transactionManager.skipRecurringTransaction(id: item.id)
                            await reload()
                        }
                    } label: {
                        Label("txn.skip", systemImage: "forward.fill")
                    }
                    .tint(.orange)

                    Button {
                        AppAnalytics.logButtonClick(AppAnalytics.Button.pauseRecurring, source: AppAnalytics.Screen.recurring)
                        Task {
                            await transactionManager.cancelRecurringTransaction(id: item.id)
                            await reload()
                        }
                    } label: {
                        Label("common.pause", systemImage: "pause.fill")
                    }
                    .tint(.gray)
                }
            }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 40))
                .xpnseAdaptiveForeground(muted: true)

            Text("settings.recurring_empty")
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()

            Text("settings.recurring_empty_hint")
                .font(.system(size: 14, weight: .regular))
                .xpnseAdaptiveForeground(muted: true)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func reload() async {
        isLoading = true
        recurringItems = await transactionManager.fetchRecurringTransactions()
            .filter { $0.state != .deleted }
            .sorted { ($0.nextOccurrence ?? .distantFuture) < ($1.nextOccurrence ?? .distantFuture) }
        isLoading = false
    }
}

private struct EditRecurringTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var transactionType: TransactionType
    @State private var amount: String
    @State private var categoryStore = CategoryStore.shared
    @State private var selectedCategoryId: String
    @State private var description: String
    @State private var merchant: String
    @State private var initialTransactionDate: Date
    @State private var recurringStartDate: Date
    @State private var recurrence: RecurrenceFrequency
    @State private var hasRecurringEndDate: Bool
    @State private var recurringEndDate: Date
    @State private var remindRecurring: Bool
    @State private var reminderDateTime: Date
    @State private var showReminderPermissionAlert: Bool = false
    @State private var merchantSuggestionEngine = SuggestionEngine(
        storeFileName: SuggestionEngine.merchantStoreFileName
    )
    @State private var merchantSuggestions: [SuggestionItem] = []
    @State private var showMerchantSuggestions: Bool = false
    @State private var isMerchantChangeBecauseOfSelection: Bool = false

    private let original: RecurringTransaction
    private let onSaved: () -> Void
    private let transactionManager = FirebaseTransactionManager.shared

    private var categories: [CategoryDefinition] {
        categoryStore.categories(for: transactionType)
    }

    private var recurrenceOptions: [RecurrenceFrequency] {
        RecurrenceFrequency.uiOptions(for: recurringStartDate)
    }

    private var canEditStartDate: Bool {
        Calendar.current.startOfDay(for: original.startDate) > Calendar.current.startOfDay(for: Date())
    }

    private var isDateRangeValid: Bool {
        !hasRecurringEndDate || recurringEndDate >= recurringStartDate
    }

    private var isReminderScheduleValid: Bool {
        guard remindRecurring else { return true }
        return RecurringReminderScheduleMath.isValidReminder(
            transactionDay: recurringStartDate,
            reminderDateTime: reminderDateTime
        )
    }

    private var normalizedMerchantOrNil: String? {
        guard transactionType == .expense else { return nil }
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    init(item: RecurringTransaction, onSaved: @escaping () -> Void) {
        self.original = item
        let type = TransactionType(rawValue: item.type) ?? .expense
        self._transactionType = State(initialValue: type)
        self._amount = State(initialValue: AmountFormatter.format(item.amount))
        self._selectedCategoryId = State(
            initialValue: item.categoryIdentifier ?? BuiltinCategories.otherCategoryId
        )
        self._description = State(initialValue: item.title)
        self._merchant = State(initialValue: item.merchant ?? "")
        self._initialTransactionDate = State(initialValue: item.startDate)
        self._recurringStartDate = State(initialValue: item.startDate)
        self._recurrence = State(initialValue: item.recurrence)
        self._hasRecurringEndDate = State(initialValue: item.endDate != nil)
        self._recurringEndDate = State(initialValue: item.endDate ?? item.startDate)
        self._remindRecurring = State(initialValue: item.notificationReminderEnabled)
        self._reminderDateTime = State(initialValue: Self.initialReminderDateTime(for: item))
        self.onSaved = onSaved
    }

    private static func initialReminderDateTime(for item: RecurringTransaction) -> Date {
        if let offset = item.notificationReminderOffsetFromEndOfDay {
            let end = RecurringReminderScheduleMath.endOfCalendarDay(containing: item.startDate)
            let candidate = end.addingTimeInterval(-offset)
            if RecurringReminderScheduleMath.isValidReminder(
                transactionDay: item.startDate,
                reminderDateTime: candidate
            ) {
                return candidate
            }
        }
        return defaultReminderDateTime(for: item.startDate)
    }

    private static func defaultReminderDateTime(for transactionDay: Date) -> Date {
        let cal = Calendar.current
        guard let latest = RecurringReminderScheduleMath.endOfDayBeforeTransactionDay(
            containing: transactionDay,
            calendar: cal
        ) else {
            return transactionDay
        }
        let txStart = cal.startOfDay(for: transactionDay)
        guard let prevStart = cal.date(byAdding: .day, value: -1, to: txStart) else { return latest }
        let candidate = cal.date(bySettingHour: 21, minute: 0, second: 0, of: prevStart) ?? prevStart
        return min(candidate, latest)
    }

    private func clampReminderDateTimeToTransactionDay(_ transactionDay: Date) {
        let cal = Calendar.current
        guard let latest = RecurringReminderScheduleMath.endOfDayBeforeTransactionDay(
            containing: transactionDay,
            calendar: cal
        ) else { return }
        var next = reminderDateTime
        let txStart = cal.startOfDay(for: transactionDay)
        if next > latest || cal.startOfDay(for: next) >= txStart {
            next = min(Self.defaultReminderDateTime(for: transactionDay), latest)
        }
        if next != reminderDateTime {
            reminderDateTime = next
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PrimaryGradient()

                ScrollView {
                    VStack(spacing: 24) {
                        transactionTypeSelector
                        initialDateSection
                        descriptionInputSection
                        if transactionType == .expense {
                            merchantInputSection
                        }
                        amountInputSection
                        categorySelectionSection
                        recurrenceSection
                        reminderSection
                        deleteRecurringButton
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showMerchantSuggestions = false
                }
                .onChange(of: merchant) { _, newValue in
                    if isMerchantChangeBecauseOfSelection {
                        showMerchantSuggestions = false
                        isMerchantChangeBecauseOfSelection = false
                        return
                    }

                    let shouldShow: Bool = newValue != (original.merchant ?? "")
                    guard shouldShow else { return }

                    if newValue.count > 2 {
                        merchantSuggestionEngine.queryDebounced(newValue, limit: 2) { results in
                            merchantSuggestions = results
                            showMerchantSuggestions = !results.isEmpty
                        }
                    } else {
                        showMerchantSuggestions = false
                    }
                }
                .onChange(of: showMerchantSuggestions) { _, show in
                    if !show {
                        merchantSuggestions = []
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                        .xpnseAdaptiveForeground()
                }
                ToolbarItem(placement: .principal) {
                    Text("txn.update_recurring")
                        .font(.title3)
                        .fontWeight(.bold)
                        .xpnseAdaptiveForeground()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        AppAnalytics.logButtonClick(
                            AppAnalytics.Button.saveRecurring,
                            source: AppAnalytics.Screen.editRecurring
                        )
                        Task { await save() }
                    }
                    .disabled(
                        !isDateRangeValid || amount.isEmpty || description.isEmpty
                            || (remindRecurring && !isReminderScheduleValid)
                    )
                    .xpnseAdaptiveForeground()
                }
            }
            .alert("common.notifications", isPresented: $showReminderPermissionAlert) {
                Button("common.open_settings") {
                    RecurringReminderScheduler.shared.openAppSettings()
                }
                Button("common.ok", role: .cancel) {}
            } message: {
                Text("txn.notifications_settings")
            }
            .onChange(of: remindRecurring) { _, newValue in
                guard newValue else { return }
                Task {
                    let allowed = await RecurringReminderScheduler.shared.validateWhenTurningRemindMeOn()
                    if !allowed {
                        await MainActor.run { showReminderPermissionAlert = true }
                    }
                }
            }
            .onChange(of: recurringStartDate) { _, newValue in
                initialTransactionDate = newValue
                recurrence = recurrence.aligned(to: newValue)
                if hasRecurringEndDate, recurringEndDate < newValue {
                    recurringEndDate = newValue
                }
                clampReminderDateTimeToTransactionDay(newValue)
            }
            .onAppear {
                AppAnalytics.logScreen(AppAnalytics.Screen.editRecurring)
                merchantSuggestionEngine.load()
            }
            .task {
                await categoryStore.load()
            }
            .onChange(of: transactionType) { _, newType in
                if !categories.contains(where: { $0.id == selectedCategoryId }) {
                    selectedCategoryId = BuiltinCategories.defaultCategoryId(for: newType)
                }
                if newType != .expense {
                    showMerchantSuggestions = false
                    merchantSuggestions = []
                    merchant = ""
                }
            }
        }
    }

    private func save() async {
        let computedEndDate = hasRecurringEndDate ? recurringEndDate : nil
        let reminderOffset: TimeInterval? = {
            guard remindRecurring else { return nil }
            return RecurringReminderScheduleMath.offsetFromEndOfTransactionDay(
                transactionDay: recurringStartDate,
                reminderDateTime: reminderDateTime
            )
        }()
        let updated = RecurringTransaction(
            id: original.id,
            title: description,
            merchant: normalizedMerchantOrNil,
            type: transactionType.rawValue,
            categoryIdentifier: selectedCategoryId,
            amount: Decimal(string: amount) ?? original.amount,
            startDate: recurringStartDate,
            endDate: computedEndDate,
            recurrence: recurrence,
            nextOccurrence: resolvedNextOccurrence(
                original: original,
                startDate: recurringStartDate,
                endDate: computedEndDate,
                recurrence: recurrence
            ),
            lastTransactionAddedOn: original.lastTransactionAddedOn,
            state: original.state,
            notificationReminderEnabled: remindRecurring,
            notificationReminderOffsetFromEndOfDay: reminderOffset,
            notificationScheduledForOccurrenceDate: nil,
            metadata: original.metadata
        )
        if let merchantName = normalizedMerchantOrNil {
            merchantSuggestionEngine.upsert(
                from: TransactionAdapter(
                    title: merchantName,
                    categoryIdentifier: nil,
                    date: Date()
                )
            )
        }
        await transactionManager.updateRecurringTransaction(updated)
        await MainActor.run {
            onSaved()
            dismiss()
        }
    }

    /// Avoid resetting `nextOccurrence` to the series start on every edit — that caused
    /// `processPending` to re-walk history and create duplicate occurrences.
    private func resolvedNextOccurrence(
        original: RecurringTransaction,
        startDate: Date,
        endDate: Date?,
        recurrence: RecurrenceFrequency,
        calendar: Calendar = .current
    ) -> Date? {
        guard original.state == .active else { return nil }

        let scheduleUnchanged =
            original.recurrence == recurrence
            && calendar.isDate(original.startDate, inSameDayAs: startDate)
            && sameOptionalDay(original.endDate, endDate, calendar: calendar)

        if scheduleUnchanged, let existing = original.nextOccurrence {
            if let endDate, existing > endDate { return nil }
            return existing
        }

        let next: Date?
        if let lastAdded = original.lastTransactionAddedOn {
            if startDate > lastAdded {
                next = recurrence.firstOccurrence(onOrAfter: startDate, calendar: calendar)
            } else {
                next = recurrence.nextOccurrence(after: lastAdded, calendar: calendar)
            }
        } else {
            next = recurrence.firstOccurrence(onOrAfter: startDate, calendar: calendar)
        }

        if let endDate, let next, next > endDate { return nil }
        return next
    }

    private func sameOptionalDay(_ lhs: Date?, _ rhs: Date?, calendar: Calendar) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (l?, r?):
            return calendar.isDate(l, inSameDayAs: r)
        default:
            return false
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $remindRecurring) {
                Text("txn.remind_me")
                    .font(.system(size: 16, weight: .medium))
                    .xpnseAdaptiveForeground()
            }
            .toggleStyle(.switch)
            .tint(XpnseColorKey.secondaryButtonBGColor.color)

            if remindRecurring {
                DatePicker(
                    "txn.reminder_datetime",
                    selection: $reminderDateTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)

                if !isReminderScheduleValid {
                    Text("txn.reminder_invalid_start")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }
            }
        }
    }

    private var transactionTypeSelector: some View {
        TransactionTypePicker(selection: $transactionType) { type in
            selectedCategoryId = BuiltinCategories.defaultCategoryId(for: type)
        }
    }

    private var initialDateSection: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("txn.date_of_initial")
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()

            Spacer(minLength: 0)

            Text(initialTransactionDate.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 14, weight: .medium))
                .xpnseAdaptiveForeground(muted: true)
        }
    }

    private var descriptionInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("common.description")
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()

            TextField("txn.field.description_placeholder", text: $description)
                .font(.system(size: 20, weight: .bold))
                .xpnseStyledTextField()
        }
    }

    private var merchantInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("common.merchant")
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()

            VStack(alignment: .leading, spacing: 0) {
                TextField("txn.field.merchant_placeholder", text: $merchant)
                    .font(.system(size: 20, weight: .bold))
                    .xpnseStyledTextField()

                if showMerchantSuggestions {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("txn.suggestions")
                            .font(.system(size: 16, weight: .semibold))
                            .xpnseAdaptiveForeground()
                            .padding(.top, 12)
                            .padding(.leading, 8)

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(merchantSuggestions.enumerated()), id: \.offset) { idx, item in
                                Button {
                                    merchantSuggestionEngine.cancelPendingQuery()
                                    isMerchantChangeBecauseOfSelection = true
                                    merchant = item.title
                                    showMerchantSuggestions = false
                                } label: {
                                    HStack {
                                        Text(item.title)
                                            .xpnseAdaptiveForeground()
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                }

                                if idx != merchantSuggestions.count - 1 {
                                    Rectangle()
                                        .fill(AdaptiveBrandSurface.fieldBorder(for: colorScheme))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 1)
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                    }
                    .background(AdaptiveBrandSurface.elevatedSurfaceBackground(for: colorScheme))
                    .xpnseRoundedCorner()
                }
            }
        }
    }

    private var amountInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("common.amount")
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()

            HStack {
                Text(CurrencyManager.shared.selectedCurrency.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .xpnseAdaptiveForeground()

                TextField("txn.field.amount_placeholder", text: $amount)
                    .font(.system(size: 24, weight: .bold))
                    .keyboardType(.decimalPad)
                    .xpnseStyledTextField()
            }
        }
    }

    private var categorySelectionSection: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("common.category")
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()
                .frame(height: 64, alignment: .center)

            Spacer(minLength: 0)

            DropDownMenu(
                options: categories,
                menuWdith: 250,
                maxItemDisplayed: 6,
                selectedCategoryId: $selectedCategoryId,
                showDropdown: .constant(false)
            )
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("txn.frequency")
                    .font(.system(size: 16, weight: .medium))
                    .xpnseAdaptiveForeground()

                Spacer(minLength: 0)

                Picker("txn.frequency", selection: $recurrence) {
                    ForEach(recurrenceOptions, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("txn.start_date")
                    .font(.system(size: 16, weight: .medium))
                    .xpnseAdaptiveForeground()
                Spacer(minLength: 0)
                DatePicker("", selection: $recurringStartDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .disabled(!canEditStartDate)
            }

            Toggle(isOn: $hasRecurringEndDate) {
                Text("txn.set_end_date")
                    .font(.system(size: 16, weight: .medium))
                    .xpnseAdaptiveForeground()
            }
            .toggleStyle(.switch)
            .tint(XpnseColorKey.secondaryButtonBGColor.color)

            if hasRecurringEndDate {
                DatePicker("txn.end_date", selection: $recurringEndDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }

            if !isDateRangeValid {
                Text("txn.end_date_invalid")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
            }
        }
    }

    private var deleteRecurringButton: some View {
        Button(role: .destructive) {
            Task {
                AppAnalytics.logButtonClick(
                    AppAnalytics.Button.deleteRecurring,
                    source: AppAnalytics.Screen.editRecurring
                )
                await transactionManager.deleteRecurringTransaction(id: original.id)
                onSaved()
                dismiss()
            }
        } label: {
            Text("txn.delete_recurring")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.85))
                .xpnseRoundedCorner()
        }
    }
}
