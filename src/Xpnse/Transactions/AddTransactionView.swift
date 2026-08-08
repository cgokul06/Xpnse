//
//  AddTransactionView.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI
import UIKit

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
        guard transactionType == .expense else { return nil }
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var recurringDateRangeValid: Bool {
        guard isRecurring else { return true }
        guard hasRecurringEndDate else { return true }
        let cal = Calendar.current
        let endDay = cal.startOfDay(for: recurringEndDate)
        let startDay = cal.startOfDay(for: selectedDate)
        let today = cal.startOfDay(for: Date())
        return endDay > startDay && endDay >= today
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

        self.amount = AmountFormatter.format(txn.amount)
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

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 24) {
                            // Transaction Type Selector
                            transactionTypeSelector

                            // Date input
                            dateInputSection

                            // Description Input
                            descriptionInputSection

                            // Merchant Input (expenses only)
                            if transactionType == .expense {
                                merchantInputSection
                            }

                            // Amount Input
                            amountInputSection

                            // Category Selection (as a square scrollable box)
                            categorySelectionSection
                                .id("categorySection")

                            if !isEditing {
                                recurringSection
                            }

                            // Extra scroll height while the category menu is open so the full
                            // dropdown can sit above the bottom Save / Scan bar.
                            Color.clear
                                .frame(
                                    height: showDropdownForCategory
                                        ? DropDownMenu.scrollPadding(
                                            optionCount: categories.count,
                                            maxItemDisplayed: 4
                                        )
                                        : 16
                                )
                                .id("categoryDropdownEnd")
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        self.focussedField = nil
                        self.showDropdownForCategory = false
                    }
                    .onChange(of: showDropdownForCategory) { _, isOpen in
                        guard isOpen else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                // Bring the end of the open-menu clearance into view so the
                                // full dropdown sits above the bottom action bar.
                                proxy.scrollTo("categoryDropdownEnd", anchor: .bottom)
                            }
                        }
                    }
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
                        if transactionType == .expense, !didManuallyEditMerchant {
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
                    if hasRecurringEndDate {
                        ensureRecurringEndDateAfterStart(start: newValue)
                    }
                    clampReminderDateTimeToTransactionDay(newValue)
                }
                .onChange(of: hasRecurringEndDate) { _, enabled in
                    guard enabled else { return }
                    ensureRecurringEndDateAfterStart(start: selectedDate)
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
                    Text(isEditing ? "txn.edit.title" : "txn.add.title")
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
                AppAnalytics.logScreen(
                    isEditing ? AppAnalytics.Screen.editTransaction : AppAnalytics.Screen.addTransaction
                )
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
            .onChange(of: transactionType) { _, newType in
                if !categories.contains(where: { $0.id == selectedCategoryId }) {
                    selectedCategoryId = BuiltinCategories.defaultCategoryId(for: newType)
                }
                if newType != .expense {
                    clearMerchantForNonExpenseType()
                }
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("txn.delete.confirm"),
                    primaryButton: .destructive(
                        Text("common.yes"),
                        action: {
                        Task {
                            await self.deleteTransaction()
                        }
                    }),
                    secondaryButton: .default(
                        Text("common.no"),
                        action: {
                        self.showDeleteAlert = false
                    })
                )
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

    /// End date must be after start and on/after today.
    private func ensureRecurringEndDateAfterStart(start: Date) {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: start)
        let today = cal.startOfDay(for: Date())
        let dayAfterStart = cal.date(byAdding: .day, value: 1, to: startDay) ?? startDay
        let minimumEnd = max(dayAfterStart, today)
        if cal.startOfDay(for: recurringEndDate) < minimumEnd {
            recurringEndDate = minimumEnd
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
                    .focused(self.$focussedField, equals: .cost)
            }
        }
    }

    // MARK: - Category Selection Section (Square Scrollable Box)
    private var categorySelectionSection: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("common.category")
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()
                // Keep label centered on the closed dropdown header (64pt), not the expanded list.
                .frame(height: 64, alignment: .center)

            Spacer(minLength: 0)

            DropDownMenu(
                options: categories,
                menuWdith: 250,
                maxItemDisplayed: 4,
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
                Text("common.recurring")
                    .font(.system(size: 18, weight: .semibold))
                    .xpnseAdaptiveForeground()
            }
            .toggleStyle(.switch)
            .tint(XpnseColorKey.secondaryButtonBGColor.color)

            if isRecurring {
                HStack {
                    Text("txn.frequency")
                        .font(.system(size: 16, weight: .medium))
                        .xpnseAdaptiveForeground()

                    Spacer(minLength: 0)

                    Picker("txn.frequency", selection: $recurrenceFrequency) {
                        ForEach(recurrenceOptions, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Toggle(isOn: $hasRecurringEndDate) {
                    Text("txn.set_end_date")
                        .font(.system(size: 16, weight: .medium))
                        .xpnseAdaptiveForeground()
                }
                .toggleStyle(.switch)
                .tint(XpnseColorKey.secondaryButtonBGColor.color)

                if hasRecurringEndDate {
                    DatePicker(
                        "txn.end_date",
                        selection: $recurringEndDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }

                if !recurringDateRangeValid {
                    Text("txn.end_date_invalid")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }

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

                    if !isRecurringReminderScheduleValid {
                        Text("txn.reminder_invalid")
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
            Text("common.description")
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()

            VStack(alignment: .leading, spacing: 0) {
                TextField("txn.field.description_placeholder", text: $description)
                    .font(.system(size: 20, weight: .bold))
                    .xpnseStyledTextField()
                    .focused(self.$focussedField, equals: .description)

                if showSuggestions {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("txn.suggestions")
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
            Text("common.merchant")
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()

            VStack(alignment: .leading, spacing: 0) {
                TextField("txn.field.merchant_placeholder", text: $merchant)
                    .font(.system(size: 20, weight: .bold))
                    .xpnseStyledTextField()
                    .focused(self.$focussedField, equals: .merchant)

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
            Text("txn.date_of_transaction")
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
            Button {
                AppAnalytics.logButtonClick(
                    AppAnalytics.Button.saveTransaction,
                    source: isEditing ? AppAnalytics.Screen.editTransaction : AppAnalytics.Screen.addTransaction
                )
                addOrUpdateTransaction()
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    Text("common.save")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .buttonStyle(
                XpnsePrimaryButtonStyle.defaultButton(
                    isDisabled: .constant(
                        !isFormValid || isLoading || !recurringDateRangeValid
                            || (isRecurring && remindRecurring && !isRecurringReminderScheduleValid)
                    ),
                    isLoading: $isLoading
                )
            )

            if !self.isEditing, FoundationModelsAvailability.isAvailable {
                Button {
                    AppAnalytics.logButtonClick(
                        AppAnalytics.Button.scanBillFromForm,
                        source: AppAnalytics.Screen.addTransaction
                    )
                    scanBill()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 18, weight: .semibold))

                        Text("txn.scan_bill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .buttonStyle(
                    XpnsePrimaryButtonStyle.defaultButton(
                        isDisabled: .constant(false),
                        isLoading: .constant(false)
                    )
                )
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
            amount: Double(truncating: (AmountFormatter.parseDecimal(amount) ?? 0) as NSDecimalNumber),
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
                    amount: AmountFormatter.parseDecimal(amount) ?? 0,
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

            AppAnalytics.logEvent(AppAnalytics.Event.txnSave)

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
        guard transactionType == .expense else { return }
        guard !isEditing else { return }
        guard !didManuallyEditMerchant else { return }

        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return }

        Task {
            guard let inferred = await merchantClassifier.infer(from: description) else { return }
            guard !Task.isCancelled else { return }
            guard transactionType == .expense else { return }
            guard !didManuallyEditMerchant else { return }
            isMerchantChangeFromInference = true
            merchant = inferred
        }
    }

    private func clearMerchantForNonExpenseType() {
        merchantClassifier.cancel()
        if focussedField == .merchant {
            focussedField = nil
        }
        showMerchantSuggestions = false
        merchantSuggestions = []
        if !merchant.isEmpty {
            isMerchantChangeFromInference = true
            merchant = ""
        }
        didManuallyEditMerchant = false
        lastNormalizedMerchant = ""
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
        AppAnalytics.logButtonClick(
            AppAnalytics.Button.deleteTransaction,
            source: AppAnalytics.Screen.editTransaction
        )
        UserEngagementCoordinator.shared.beginBusyWork(.deleteTransaction)
        defer { UserEngagementCoordinator.shared.endBusyWork(.deleteTransaction) }
        await self.transactionManager.deleteTransaction(transaction)
        suggestionEngine.decrement(title: transaction.title)
        if let merchantName = transaction.merchant {
            merchantSuggestionEngine.decrement(title: merchantName)
        }
        AppAnalytics.logEvent(AppAnalytics.Event.txnDelete)
        self.dismiss()
    }

    private func mappedRecurrenceFrequency() -> RecurrenceFrequency {
        recurrenceFrequency.aligned(to: selectedDate)
    }

}
