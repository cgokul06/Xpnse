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
    @State private var selectedCategory: TransactionCategory = .other
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
    private let transactionManager: FirebaseTransactionManager = .shared
    private var transaction: Transaction?
    private let isEditing: Bool

    private var categories: [TransactionCategory] {
        TransactionCategory.categories(for: transactionType)
    }

    private var isFormValid: Bool {
        !(amount.isEmpty) && !description.isEmpty
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
        self.selectedCategory = txn.category
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
                        self.selectedCategory = data.category
                        self.selectedDate = data.formattedDate
                    }
                }
                .onChange(of: description) { _, newValue in
                    guard !self.isDescriptionChangeBecauseOfSelection  else {
                        self.showSuggestions = false
                        return
                    }

                    if newValue.count > 2 {
                        suggestionEngine.queryDebounced(newValue, limit: 6) { results in
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
                // Load persisted suggestions and seed from manager if empty
                suggestionEngine.load()
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
        }
        .navigationBarBackButtonHidden()
    }

    // MARK: - Transaction Type Selector
    private var transactionTypeSelector: some View {
        HStack(spacing: 12) {
            Button(action: {
                transactionType = .expense
                selectedCategory = .other
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
                selectedCategory = .other
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
                selectedCategory: self.$selectedCategory,
                showDropdown: self.$showDropdownForCategory
            )
            .focused(self.$focussedField, equals: .category)
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
                                    if let cat = item.categoryIdentifier, let mapped = TransactionCategory(rawValue: cat) {
                                        self.selectedCategory = mapped
                                    }
                                    self.showSuggestions = false
                                    self.isDescriptionChangeBecauseOfSelection = true
                                } label: {
                                    HStack {
                                        Text(item.title)
                                            .foregroundColor(XpnseColorKey.white.color)
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                        if let cat = item.categoryIdentifier, let mapped = TransactionCategory(rawValue: cat) {
                                            Text(mapped.displayName)
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
            .disabled(!isFormValid || isLoading)

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
            category: self.selectedCategory,
            amount: Double(amount) ?? 0.0,
            date: selectedDate.timeIntervalSince1970,
            title: description
        )

        // Update suggestion engine immediately
        suggestionEngine.upsert(from: TransactionAdapter(title: transaction.title, categoryIdentifier: transaction.category.rawValue, date: Date(timeIntervalSince1970: transaction.date)))

         Task {
             if isEditing {
                 await transactionManager.updateTransaction(transaction)
             } else {
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
        self.dismiss()
    }


}
