//
//  AddTransactionView.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI

fileprivate enum AddTransactionViewFocusField {
    case description
    case cost
    case category
    case date
    case transactionType
}

struct AddTransactionView: View {
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var billScannerService: BillScannerService
    @FocusState fileprivate var focussedField: AddTransactionViewFocusField?
    @State private var transactionType: TransactionType = .expense
    @State private var amount: String = ""
    @State private var categoryStore = CategoryStore.shared
    @State private var selectedCategoryId: String = BuiltinCategories.otherCategoryId
    @State private var description: String = ""
    @State private var selectedDate = Date()
    @State private var isLoading = false
    @State private var showDeleteAlert: Bool = false
    @State private var isDeleting: Bool = false
    @State private var suggestionEngine = SuggestionEngine()
    @State private var suggestions: [SuggestionItem] = []
    @State private var showSuggestions: Bool = false
    @State private var isDescriptionChangeBecauseOfSelection: Bool = false
    @State private var showDropdownForCategory: Bool = false
    @State private var isRecurring: Bool = false
    @State private var recurrenceFrequency: RecurrenceFrequency = .daily
    @State private var hasRecurringEndDate: Bool = false
    @State private var recurringEndDate: Date = Date()
    @State private var remindRecurring: Bool = false
    @State private var reminderDateTime: Date = AddTransactionView.defaultReminderDateTime(for: Date())
    @State private var showReminderPermissionAlert: Bool = false
    private let transactionManager: FirebaseTransactionManager = .shared
    private var transaction: Transaction?
    private let isEditing: Bool

    private var categories: [CategoryDefinition] {
        categoryStore.categories(for: transactionType)
    }

    private var isFormValid: Bool {
        !(amount.isEmpty) && !description.isEmpty
    }

    private var recurringDateRangeValid: Bool {
        guard isRecurring else { return true }
        guard hasRecurringEndDate else { return true }
        return recurringEndDate >= selectedDate
    }

    private var isRecurringReminderScheduleValid: Bool {
        guard isRecurring, remindRecurring else { return true }
        return RecurringReminderScheduleMath.isValidReminder(
            transactionDay: selectedDate,
            reminderDateTime: reminderDateTime
        )
    }

    private var recurrenceOptions: [RecurrenceFrequency] {
        RecurrenceFrequency.uiOptions(for: selectedDate)
    }

    init(
        billScannerService: BillScannerService,
        transaction: Transaction? = nil
    ) {
        self.billScannerService = billScannerService
        self.transaction = transaction
        self.isEditing = transaction != nil
        self.focussedField = self.isEditing ? nil : .description
    }

    private func mapEditableDatas() {
        guard let txn = self.transaction else {
            return
        }

        self.amount = "\(txn.amount)"
        self.selectedDate = Date(timeIntervalSince1970: txn.date)
        self.description = txn.title
        self.selectedCategoryId = txn.categoryId
        self.transactionType = txn.type
    }

    var body: some View {
        NavigationView {
            ZStack {
                PrimaryGradient()

                ScrollView {
                    VStack(spacing: 24) {
                        // Transaction Type Selector
                        transactionTypeSelector

                        // Date input
                        dateInputSection

                        // Description Input
                        descriptionInputSection

                        // Amount Input
                        amountInputSection

                        // Category Selection (as a square scrollable box)
                        categorySelectionSection

                        if !isEditing {
                            recurringSection
                        }

                        // Spacer for bottom buttons
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    self.focussedField = nil
                    self.showDropdownForCategory = false
                }
                .onChange(of: billScannerService.extractedTransaction) { _, extractedData in
                    if let data = extractedData {
                        // Auto-fill the form with extracted data
                        self.amount = String(format: "%.2f", data.amount)
                        self.description = data.title
                        self.transactionType = data.type
                        self.selectedCategoryId = data.categoryId
                        self.selectedDate = data.formattedDate
                    }
                }
                .onChange(of: description) { _, newValue in
                    let shouldShowSuggestions: Bool = {
                        guard isEditing else {
                            return true
                        }

                        return newValue != self.transaction?.title
                    }()
                    
                    guard shouldShowSuggestions else {
                        return
                    }

                    guard !self.isDescriptionChangeBecauseOfSelection  else {
                        self.showSuggestions = false
                        return
                    }

                    if newValue.count > 2 {
                        suggestionEngine.queryDebounced(newValue, limit: 2) { results in
                            self.suggestions = results
                            self.showSuggestions = !results.isEmpty
                        }
                    } else {
                        self.showSuggestions = false
                    }
                }
                .onChange(of: self.showSuggestions) { _, show in
                    if !show {
                        self.suggestions = []
                    }
                }
                .onChange(of: selectedDate) { _, newValue in
                    recurrenceFrequency = recurrenceFrequency.aligned(to: newValue)
                    clampReminderDateTimeToTransactionDay(newValue)
                }

                if isDeleting {
                    ProgressView()
                }
            }
            .safeAreaInset(edge: .bottom, content: {
                // Bottom Buttons
                bottomButtonsSection
            })
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        self.dismiss()
                        self.showSuggestions = false
                    }, label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(XpnseColorKey.white.color)
                            .bold()
                            .padding(.all, 8)
                    })
                }

                ToolbarItem(placement: .principal) {
                    Text("Add Transaction")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                if isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            self.showDeleteAlert = true
                        }, label: {
                            Image(systemName: "trash")
                                .foregroundStyle(XpnseColorKey.white.color)
                                .bold()
                                .padding(.all, 8)
                        })
                    }
                }
            }
            .onAppear {
                self.mapEditableDatas()
                suggestionEngine.load()
            }
            .task {
                await categoryStore.load()
            }
            .onChange(of: transactionType) { _, _ in
                if !categories.contains(where: { $0.id == selectedCategoryId }) {
                    selectedCategoryId = BuiltinCategories.otherCategoryId
                }
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Are you sure you want to delete this transaction?"),
                    primaryButton: .destructive(
                        Text("Yes"),
                        action: {
                        Task {
                            await self.deleteTransaction()
                        }
                    }),
                    secondaryButton: .default(
                        Text("No"),
                        action: {
                        self.showDeleteAlert = false
                    })
                )
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
                guard newValue, isRecurring else { return }
                Task {
                    let allowed = await RecurringReminderScheduler.shared.validateWhenTurningRemindMeOn()
                    if !allowed {
                        await MainActor.run { showReminderPermissionAlert = true }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden()
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

    // MARK: - Transaction Type Selector
    private var transactionTypeSelector: some View {
        HStack(spacing: 12) {
            Button(action: {
                transactionType = .expense
                selectedCategoryId = BuiltinCategories.otherCategoryId
                showSuggestions = false
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Expense")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(transactionType == .expense ? XpnseColorKey.expensePrimary.color : Color.gray.opacity(0.3))
                .xpnseRoundedCorner()
            }

            Button(action: {
                transactionType = .income
                selectedCategoryId = BuiltinCategories.otherCategoryId
                showSuggestions = false
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Income")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(transactionType == .income ? XpnseColorKey.incomePrimary.color : Color.gray.opacity(0.3))
                .xpnseRoundedCorner()
            }
        }
        .focused(self.$focussedField, equals: .transactionType)
    }

    // MARK: - Amount Input Section
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
                    .focused(self.$focussedField, equals: .cost)
            }
        }
    }

    // MARK: - Category Selection Section (Square Scrollable Box)
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
                selectedCategoryId: self.$selectedCategoryId,
                showDropdown: self.$showDropdownForCategory
            )
            .focused(self.$focussedField, equals: .category)
        }
    }

    // MARK: - Recurring Section
    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isRecurring) {
                Text("Recurring")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .toggleStyle(.switch)
            .tint(XpnseColorKey.secondaryButtonBGColor.color)

            if isRecurring {
                HStack {
                    Text("Frequency")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    Spacer(minLength: 0)

                    Picker("Frequency", selection: $recurrenceFrequency) {
                        ForEach(recurrenceOptions, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Toggle(isOn: $hasRecurringEndDate) {
                    Text("Set end date")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .toggleStyle(.switch)
                .tint(XpnseColorKey.secondaryButtonBGColor.color)

                if hasRecurringEndDate {
                    DatePicker(
                        "End date",
                        selection: $recurringEndDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .colorScheme(.dark)
                    .foregroundColor(.white)
                }

                if !recurringDateRangeValid {
                    Text("End date must be on or after start date.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }

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

                    if !isRecurringReminderScheduleValid {
                        Text("Reminder must be before the transaction date, at latest the end of the previous day (e.g. transaction 11 May → reminder on or before 10 May, 11:59 p.m.).")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    // MARK: - Description Input Section
    private var descriptionInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 0) {
                TextField("Add a description", text: $description)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(XpnseColorKey.white.color)
                    .textFieldStyle(XpnseTextFieldStyle())
                    .focused(self.$focussedField, equals: .description)

                if showSuggestions {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggestions:")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.top, 12)
                            .padding(.leading, 8)

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, item in
                                Button {
                                    self.description = item.title
                                    if let cat = item.categoryIdentifier {
                                        self.selectedCategoryId = cat
                                    }
                                    self.showSuggestions = false
                                    self.isDescriptionChangeBecauseOfSelection = true
                                } label: {
                                    HStack {
                                        Text(item.title)
                                            .foregroundColor(XpnseColorKey.white.color)
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                        if let cat = item.categoryIdentifier {
                                            Text(categoryStore.categoryDisplayName(for: cat))
                                                .foregroundColor(.white.opacity(0.7))
                                                .font(.system(size: 14))
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                }

                                if idx != self.suggestions.count - 1 {
                                    Rectangle()
                                        .fill(XpnseColorKey.white.color)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 1)
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                    }
                    .background(Color.white.opacity(0.08))
                    .xpnseRoundedCorner()
                }
            }
        }
        .onChange(of: self.focussedField) { _, newVal in
            if newVal != .description {
                self.showSuggestions = false
            }
            if newVal != nil {
                self.showDropdownForCategory = false
            }
        }
    }

    // MARK: - Date Input Section
    private var dateInputSection: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Date of transaction")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 0)

            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .colorScheme(.dark)
            .focused(self.$focussedField, equals: .date)
        }
    }

    // MARK: - Bottom Buttons Section
    private var bottomButtonsSection: some View {
        HStack(spacing: 16) {
            // Done Button
            Button(action: {
                addOrUpdateTransaction()
            }) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    Text("Save")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(XpnseColorKey.secondaryButtonBGColor.color)
                .opacity(isFormValid ? 1.0 : 0.7)
                .xpnseRoundedCorner()
            }
            .disabled(
                !isFormValid || isLoading || !recurringDateRangeValid
                    || (isRecurring && remindRecurring && !isRecurringReminderScheduleValid)
            )

            if !self.isEditing {
                // Scan Bill Button
                Button(action: {
                    scanBill()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 18, weight: .semibold))

                        Text("Scan Bill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(XpnseColorKey.secondaryButtonBGColor.color)
                    .xpnseRoundedCorner()
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Actions
    private func addOrUpdateTransaction() {
        guard !amount.isEmpty else { return }

        isLoading = true

        let transaction = Transaction(
            id: isEditing ? (self.transaction?.id ?? UUID().uuidString) : UUID().uuidString,
            type: transactionType,
            categoryId: self.selectedCategoryId,
            amount: Double(amount) ?? 0.0,
            date: selectedDate.timeIntervalSince1970,
            title: description
        )

        Task {
            if isRecurring && !isEditing {
                suggestionEngine.upsert(
                    from: TransactionAdapter(
                        title: transaction.title,
                        categoryIdentifier: transaction.categoryId,
                        date: Date(timeIntervalSince1970: transaction.date)
                    )
                )
                let computedEndDate = hasRecurringEndDate ? recurringEndDate : nil
                let reminderOffset: TimeInterval? = {
                    guard remindRecurring else { return nil }
                    return RecurringReminderScheduleMath.offsetFromEndOfTransactionDay(
                        transactionDay: selectedDate,
                        reminderDateTime: reminderDateTime
                    )
                }()
                let recurring = RecurringTransaction(
                    title: description,
                    type: transactionType.rawValue,
                    categoryIdentifier: selectedCategoryId,
                    amount: Decimal(Double(amount) ?? 0.0),
                    startDate: selectedDate,
                    endDate: computedEndDate,
                    recurrence: mappedRecurrenceFrequency(),
                    notificationReminderEnabled: remindRecurring,
                    notificationReminderOffsetFromEndOfDay: reminderOffset,
                    notificationScheduledForOccurrenceDate: nil,
                    metadata: [
                        "createdFrom": "AddTransactionView"
                    ]
                )
                await transactionManager.createRecurringTransaction(recurring)
                await transactionManager.processRecurringTransactions()
            } else if isEditing {
                await transactionManager.updateTransaction(transaction)
            } else {
                suggestionEngine.upsert(
                    from: TransactionAdapter(
                        title: transaction.title,
                        categoryIdentifier: transaction.categoryId,
                        date: Date(timeIntervalSince1970: transaction.date)
                    )
                )
                await transactionManager.addTransaction(transaction)
            }

            await MainActor.run {
                isLoading = false
                self.dismiss()
            }
        }
    }

    private func scanBill() {
        // Implement bill scanning functionality
        self.homeCoordinator.push(.billScanner)
    }

    private func deleteTransaction() async {
        guard let transaction else { return }
        await self.transactionManager.deleteTransaction(transaction)
        suggestionEngine.decrement(title: transaction.title)
        self.dismiss()
    }

    private func mappedRecurrenceFrequency() -> RecurrenceFrequency {
        recurrenceFrequency.aligned(to: selectedDate)
    }

}
