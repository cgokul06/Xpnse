//
//  AddTransactionView.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI

fileprivate enum AddTransactionViewFocusField {
    case description
    case merchant
    case cost
    case category
    case date
}

struct AddTransactionView: View {
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var billScannerService: BillScannerService
    @FocusState fileprivate var focussedField: AddTransactionViewFocusField?
    @State private var transactionType: TransactionType = .expense
    @State private var amount: String = ""
    @State private var categoryStore = CategoryStore.shared
    @State private var selectedCategoryId: String = BuiltinCategories.otherCategoryId
    @State private var description: String = ""
    @State private var merchant: String = ""
    @State private var selectedDate = Date()
    @State private var isLoading = false
    @State private var showDeleteAlert: Bool = false
    @State private var isDeleting: Bool = false
    @State private var suggestionEngine = SuggestionEngine()
    @State private var merchantSuggestionEngine = SuggestionEngine(
        storeFileName: SuggestionEngine.merchantStoreFileName
    )
    @State private var suggestions: [SuggestionItem] = []
    @State private var merchantSuggestions: [SuggestionItem] = []
    @State private var showSuggestions: Bool = false
    @State private var showMerchantSuggestions: Bool = false
    @State private var isDescriptionChangeBecauseOfSelection: Bool = false
    @State private var isMerchantChangeBecauseOfSelection: Bool = false
    @State private var isMerchantChangeFromInference: Bool = false
    @State private var didManuallyEditMerchant = false
    @State private var showDropdownForCategory: Bool = false
    @State private var isRecurring: Bool = false
    @State private var recurrenceFrequency: RecurrenceFrequency = .daily
    @State private var hasRecurringEndDate: Bool = false
    @State private var recurringEndDate: Date = Date()
    @State private var remindRecurring: Bool = false
    @State private var reminderDateTime: Date = AddTransactionView.defaultReminderDateTime(for: Date())
    @State private var showReminderPermissionAlert: Bool = false
    @State private var didManuallySelectCategory = false
    @State private var lastNormalizedDescription = ""
    @State private var lastNormalizedMerchant = ""
    private let transactionManager: FirebaseTransactionManager = .shared
    private let categoryClassifier = CategoryClassificationService()
    private let merchantClassifier = MerchantClassificationService()
    private var transaction: Transaction?
    private let isEditing: Bool

    private var categories: [CategoryDefinition] {
        categoryStore.categories(for: transactionType)
    }

    private var isFormValid: Bool {
        !(amount.isEmpty) && !description.isEmpty
    }

    private var normalizedMerchantOrNil: String? {
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

    private var categorySelectionBinding: Binding<String> {
        Binding(
            get: { selectedCategoryId },
            set: { newValue in
                selectedCategoryId = newValue
                didManuallySelectCategory = true
            }
        )
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
        self.merchant = txn.merchant ?? ""
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

                        // Merchant Input (optional)
                        merchantInputSection

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
                        applyExtractedTransaction(data)
                    }
                }
                .onChange(of: description) { _, newValue in
                    if isDescriptionChangeBecauseOfSelection {
                        lastNormalizedDescription = SuggestionEngine.normalize(newValue)
                        showSuggestions = false
                        isDescriptionChangeBecauseOfSelection = false
                        return
                    }

                    let normalized = SuggestionEngine.normalize(newValue)
                    if normalized != lastNormalizedDescription {
                        didManuallySelectCategory = false
                        lastNormalizedDescription = normalized
                        // Allow AI merchant re-inference when description changes,
                        // unless the user edited merchant themselves.
                        if !didManuallyEditMerchant {
                            isMerchantChangeFromInference = true
                            merchant = ""
                        }
                    }

                    let shouldShowSuggestions: Bool = {
                        guard isEditing else {
                            return true
                        }

                        return newValue != self.transaction?.title
                    }()

                    guard shouldShowSuggestions else {
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
                .onChange(of: merchant) { _, newValue in
                    if isMerchantChangeFromInference {
                        lastNormalizedMerchant = SuggestionEngine.normalize(newValue)
                        showMerchantSuggestions = false
                        isMerchantChangeFromInference = false
                        return
                    }

                    if isMerchantChangeBecauseOfSelection {
                        lastNormalizedMerchant = SuggestionEngine.normalize(newValue)
                        showMerchantSuggestions = false
                        isMerchantChangeBecauseOfSelection = false
                        didManuallyEditMerchant = true
                        return
                    }

                    didManuallyEditMerchant = true
                    lastNormalizedMerchant = SuggestionEngine.normalize(newValue)

                    let shouldShowSuggestions: Bool = {
                        guard isEditing else { return true }
                        return newValue != (self.transaction?.merchant ?? "")
                    }()

                    guard shouldShowSuggestions else { return }

                    if newValue.count > 2 {
                        merchantSuggestionEngine.queryDebounced(newValue, limit: 2) { results in
                            self.merchantSuggestions = results
                            self.showMerchantSuggestions = !results.isEmpty
                        }
                    } else {
                        self.showMerchantSuggestions = false
                    }
                }
                .onChange(of: self.showSuggestions) { _, show in
                    if !show {
                        self.suggestions = []
                    }
                }
                .onChange(of: self.showMerchantSuggestions) { _, show in
                    if !show {
                        self.merchantSuggestions = []
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
                        self.showMerchantSuggestions = false
                    }, label: {
                        Image(systemName: "xmark")
                            .xpnseAdaptiveForeground()
                            .bold()
                            .padding(.all, 8)
                    })
                }

                ToolbarItem(placement: .principal) {
                    Text("Add Transaction")
                        .font(.title2)
                        .fontWeight(.bold)
                        .xpnseAdaptiveForeground()
                }

                if isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            self.showDeleteAlert = true
                        }, label: {
                            Image(systemName: "trash")
                                .xpnseAdaptiveForeground()
                                .bold()
                                .padding(.all, 8)
                        })
                    }
                }
            }
            .onAppear {
                self.mapEditableDatas()
                self.applyExtractedTransactionIfNeeded()
                lastNormalizedDescription = SuggestionEngine.normalize(description)
                lastNormalizedMerchant = SuggestionEngine.normalize(merchant)
                suggestionEngine.load()
                merchantSuggestionEngine.load()
            }
            .onDisappear {
                categoryClassifier.cancel()
                merchantClassifier.cancel()
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
                Text("Turn on notifications for SnapLedger in Settings to get reminders for this recurring transaction.")
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
        TransactionTypePicker(selection: $transactionType) { type in
            selectedCategoryId = BuiltinCategories.defaultCategoryId(for: type)
            didManuallySelectCategory = false
            showSuggestions = false
        }
    }

    // MARK: - Amount Input Section
    private var amountInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount")
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()

            HStack {
                Text(CurrencyManager.shared.selectedCurrency.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .xpnseAdaptiveForeground()

                TextField("0.00", text: $amount)
                    .font(.system(size: 24, weight: .bold))
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
                .xpnseAdaptiveForeground()

            Spacer(minLength: 0)

            DropDownMenu(
                options: categories,
                menuWdith: 250,
                maxItemDisplayed: 6,
                selectedCategoryId: categorySelectionBinding,
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
                    .xpnseAdaptiveForeground()
            }
            .toggleStyle(.switch)
            .tint(XpnseColorKey.secondaryButtonBGColor.color)

            if isRecurring {
                HStack {
                    Text("Frequency")
                        .font(.system(size: 16, weight: .medium))
                        .xpnseAdaptiveForeground()

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
                        .xpnseAdaptiveForeground()
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
                }

                if !recurringDateRangeValid {
                    Text("End date must be on or after start date.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }

                Toggle(isOn: $remindRecurring) {
                    Text("Remind me")
                        .font(.system(size: 16, weight: .medium))
                        .xpnseAdaptiveForeground()
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
                .xpnseAdaptiveForeground()

            VStack(alignment: .leading, spacing: 0) {
                TextField("Add a description", text: $description)
                    .font(.system(size: 20, weight: .bold))
                    .textFieldStyle(XpnseTextFieldStyle())
                    .focused(self.$focussedField, equals: .description)

                if showSuggestions {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggestions:")
                            .font(.system(size: 16, weight: .semibold))
                            .xpnseAdaptiveForeground()
                            .padding(.top, 12)
                            .padding(.leading, 8)

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, item in
                                Button {
                                    suggestionEngine.cancelPendingQuery()
                                    isDescriptionChangeBecauseOfSelection = true
                                    description = item.title
                                    if let cat = item.categoryIdentifier {
                                        selectedCategoryId = cat
                                    }
                                    showSuggestions = false
                                } label: {
                                    HStack {
                                        Text(item.title)
                                            .xpnseAdaptiveForeground()
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                        if let cat = item.categoryIdentifier {
                                            Text(categoryStore.categoryDisplayName(for: cat))
                                                .xpnseAdaptiveForeground(muted: true)
                                                .font(.system(size: 14))
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                }

                                if idx != self.suggestions.count - 1 {
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
        .onChange(of: self.focussedField) { oldVal, newVal in
            if newVal != .description {
                self.showSuggestions = false
            }
            if newVal != .merchant {
                self.showMerchantSuggestions = false
            }
            if oldVal == .description, newVal != .description {
                classifyCategoryAfterDescriptionBlur()
                inferMerchantFromDescriptionIfNeeded()
            }
            if newVal != nil {
                self.showDropdownForCategory = false
            }
        }
    }

    // MARK: - Merchant Input Section
    private var merchantInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Merchant")
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()

            VStack(alignment: .leading, spacing: 0) {
                TextField("Merchant (optional)", text: $merchant)
                    .font(.system(size: 20, weight: .bold))
                    .textFieldStyle(XpnseTextFieldStyle())
                    .focused(self.$focussedField, equals: .merchant)

                if showMerchantSuggestions {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggestions:")
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

                                if idx != self.merchantSuggestions.count - 1 {
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

    // MARK: - Date Input Section
    private var dateInputSection: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Date of transaction")
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()

            Spacer(minLength: 0)

            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
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

            if !self.isEditing, FoundationModelsAvailability.isAvailable {
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
            title: description,
            merchant: normalizedMerchantOrNil
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
                if let merchantName = normalizedMerchantOrNil {
                    merchantSuggestionEngine.upsert(
                        from: TransactionAdapter(
                            title: merchantName,
                            categoryIdentifier: nil,
                            date: Date(timeIntervalSince1970: transaction.date)
                        )
                    )
                }
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
                    merchant: normalizedMerchantOrNil,
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
                if let merchantName = normalizedMerchantOrNil {
                    merchantSuggestionEngine.upsert(
                        from: TransactionAdapter(
                            title: merchantName,
                            categoryIdentifier: nil,
                            date: Date(timeIntervalSince1970: transaction.date)
                        )
                    )
                }
                await transactionManager.addTransaction(transaction)
            }

            await MainActor.run {
                isLoading = false
                self.dismiss()
            }
        }
    }

    private func classifyCategoryAfterDescriptionBlur() {
        guard !isEditing else { return }

        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return }

        if let knownCategory = suggestionEngine.categoryForExactTitle(description) {
            selectedCategoryId = knownCategory
            isDescriptionChangeBecauseOfSelection = false
            return
        }

        if isDescriptionChangeBecauseOfSelection {
            isDescriptionChangeBecauseOfSelection = false
            return
        }

        guard !didManuallySelectCategory else { return }

        Task {
            if let categoryId = await categoryClassifier.classify(
                description: description,
                transactionType: transactionType
            ) {
                selectedCategoryId = categoryId
            }
        }
    }

    /// Infers merchant via Foundation Models from the description.
    /// Never prefills from past description→merchant history (unlike category exact-title mapping).
    private func inferMerchantFromDescriptionIfNeeded() {
        guard !isEditing else { return }
        guard !didManuallyEditMerchant else { return }

        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return }

        Task {
            guard let inferred = await merchantClassifier.infer(from: description) else { return }
            guard !didManuallyEditMerchant else { return }
            isMerchantChangeFromInference = true
            merchant = inferred
        }
    }

    private func applyExtractedTransactionIfNeeded() {
        guard !isEditing, let data = billScannerService.extractedTransaction else { return }
        applyExtractedTransaction(data)
    }

    private func applyExtractedTransaction(_ data: ScannedTransaction) {
        self.amount = AmountFormatter.format(data.amount)
        self.description = data.title
        // Leave merchant for on-device inference from the description (not a history lookup).
        self.didManuallyEditMerchant = false
        self.isMerchantChangeFromInference = true
        self.merchant = ""
        self.transactionType = data.type
        self.selectedCategoryId = data.categoryId
        self.selectedDate = data.formattedDate
        inferMerchantFromDescriptionIfNeeded()
    }

    private func scanBill() {
        self.homeCoordinator.push(.billScanner)
    }

    private func deleteTransaction() async {
        guard let transaction else { return }
        await self.transactionManager.deleteTransaction(transaction)
        suggestionEngine.decrement(title: transaction.title)
        if let merchantName = transaction.merchant {
            merchantSuggestionEngine.decrement(title: merchantName)
        }
        self.dismiss()
    }

    private func mappedRecurrenceFrequency() -> RecurrenceFrequency {
        recurrenceFrequency.aligned(to: selectedDate)
    }

}
