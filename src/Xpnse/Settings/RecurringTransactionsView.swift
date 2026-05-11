//
//  RecurringTransactionsView.swift
//  Xpnse
//
//  Created by Gokul C on 05/05/26.
//

import SwiftUI

struct RecurringTransactionsView: View {
    @State private var recurringItems: [RecurringTransaction] = []
    @State private var isLoading = true
    @State private var selectedForEdit: RecurringTransaction?

    private let transactionManager = FirebaseTransactionManager.shared

    var body: some View {
        List {
            if recurringItems.isEmpty && !isLoading {
                Text("No recurring transactions found.")
                    .foregroundStyle(.secondary)
            }

            ForEach(recurringItems, id: \.id) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                    Text("Next: \(item.nextOccurrence?.formatted(date: .abbreviated, time: .omitted) ?? "—")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Amount: \(CurrencyManager.shared.selectedCurrency.symbol)\(NSDecimalNumber(decimal: item.amount).stringValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Skip") {
                        Task {
                            await transactionManager.skipRecurringTransaction(id: item.id)
                            await reload()
                        }
                    }
                    .tint(.orange)

                    Button("Pause") {
                        Task {
                            await transactionManager.cancelRecurringTransaction(id: item.id)
                            await reload()
                        }
                    }
                    .tint(.gray)
                }
                .onTapGesture {
                    selectedForEdit = item
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Recurring Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedForEdit) { item in
            EditRecurringTransactionView(item: item) {
                Task { await reload() }
            }
        }
        .task {
            await reload()
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

    @State private var transactionType: TransactionType
    @State private var amount: String
    @State private var selectedCategory: TransactionCategory
    @State private var description: String
    @State private var initialTransactionDate: Date
    @State private var recurringStartDate: Date
    @State private var recurrence: RecurrenceFrequency
    @State private var hasRecurringEndDate: Bool
    @State private var recurringEndDate: Date
    @State private var remindRecurring: Bool
    @State private var reminderDateTime: Date
    @State private var showReminderPermissionAlert: Bool = false

    private let original: RecurringTransaction
    private let onSaved: () -> Void
    private let transactionManager = FirebaseTransactionManager.shared

    private var categories: [TransactionCategory] {
        TransactionCategory.categories(for: transactionType)
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

    init(item: RecurringTransaction, onSaved: @escaping () -> Void) {
        self.original = item
        let type = TransactionType(rawValue: item.type) ?? .expense
        self._transactionType = State(initialValue: type)
        self._amount = State(initialValue: NSDecimalNumber(decimal: item.amount).stringValue)
        self._selectedCategory = State(initialValue: TransactionCategory(rawValue: item.categoryIdentifier ?? "") ?? .other)
        self._description = State(initialValue: item.title)
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("Update Recurring")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
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
                                type: transactionType.rawValue,
                                categoryIdentifier: selectedCategory.rawValue,
                                amount: Decimal(string: amount) ?? original.amount,
                                startDate: recurringStartDate,
                                endDate: computedEndDate,
                                recurrence: recurrence,
                                nextOccurrence: original.state == .active
                                    ? recurrence.firstOccurrence(onOrAfter: recurringStartDate)
                                    : nil,
                                lastTransactionAddedOn: original.lastTransactionAddedOn,
                                state: original.state,
                                notificationReminderEnabled: remindRecurring,
                                notificationReminderOffsetFromEndOfDay: reminderOffset,
                                notificationScheduledForOccurrenceDate: nil,
                                metadata: original.metadata
                            )
                            await transactionManager.updateRecurringTransaction(updated)
                            await MainActor.run {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .disabled(
                        !isDateRangeValid || amount.isEmpty || description.isEmpty
                            || (remindRecurring && !isReminderScheduleValid)
                    )
                }
            }
            .alert("Notifications", isPresented: $showReminderPermissionAlert) {
                Button("Open Settings") {
                    RecurringReminderScheduler.shared.openAppSettings()
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Turn on notifications for Xpnse in Settings to get reminders for this recurring transaction.")
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
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $remindRecurring) {
                Text("Remind me")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .toggleStyle(.switch)
            .tint(XpnseColorKey.secondaryButtonBGColor.color)

            if remindRecurring {
                DatePicker(
                    "Reminder date and time",
                    selection: $reminderDateTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .colorScheme(.dark)
                .foregroundColor(.white)

                if !isReminderScheduleValid {
                    Text("Reminder must be before the start date, at latest the end of the previous day (e.g. start 11 May → reminder on or before 10 May, 11:59 p.m.).")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }
            }
        }
    }

    private var transactionTypeSelector: some View {
        HStack(spacing: 12) {
            Button {
                transactionType = .expense
                selectedCategory = .other
            } label: {
                Text("Expense")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(transactionType == .expense ? XpnseColorKey.expensePrimary.color : Color.gray.opacity(0.3))
                    .xpnseRoundedCorner()
            }

            Button {
                transactionType = .income
                selectedCategory = .other
            } label: {
                Text("Income")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(transactionType == .income ? XpnseColorKey.incomePrimary.color : Color.gray.opacity(0.3))
                    .xpnseRoundedCorner()
            }
        }
    }

    private var initialDateSection: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Date of initial transaction")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 0)

            Text(initialTransactionDate.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var descriptionInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            TextField("Add a description", text: $description)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(XpnseColorKey.white.color)
                .textFieldStyle(XpnseTextFieldStyle())
        }
    }

    private var amountInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            HStack {
                Text(CurrencyManager.shared.selectedCurrency.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                TextField("0.00", text: $amount)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(XpnseTextFieldStyle())
            }
        }
    }

    private var categorySelectionSection: some View {
        HStack(spacing: 16) {
            Text("Category")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 0)

            DropDownMenu(
                options: categories,
                menuWdith: 250,
                maxItemDisplayed: 6,
                selectedCategory: $selectedCategory,
                showDropdown: .constant(false)
            )
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Frequency")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Spacer(minLength: 0)

                Picker("Frequency", selection: $recurrence) {
                    ForEach(recurrenceOptions, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("Start date")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                Spacer(minLength: 0)
                DatePicker("", selection: $recurringStartDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .colorScheme(.dark)
                    .disabled(!canEditStartDate)
            }

            Toggle(isOn: $hasRecurringEndDate) {
                Text("Set end date")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .toggleStyle(.switch)
            .tint(XpnseColorKey.secondaryButtonBGColor.color)

            if hasRecurringEndDate {
                DatePicker("End date", selection: $recurringEndDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .colorScheme(.dark)
                    .foregroundColor(.white)
            }

            if !isDateRangeValid {
                Text("End date must be on or after start date.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
            }
        }
    }

    private var deleteRecurringButton: some View {
        Button(role: .destructive) {
            Task {
                await transactionManager.deleteRecurringTransaction(id: original.id)
                onSaved()
                dismiss()
            }
        } label: {
            Text("Delete Recurring Transaction")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.85))
                .xpnseRoundedCorner()
        }
    }
}
