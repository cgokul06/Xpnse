//
//  AddTransactionView.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI

struct AddTransactionView: View {
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var billScannerService: BillScannerService
    @State private var transactionType: TransactionType = .expense
    @State private var amount: String = ""
    @State private var selectedCategory: TransactionCategory = .other
    @State private var description: String = ""
    @State private var selectedDate = Date()
    @State private var isLoading = false
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
                .onChange(of: billScannerService.extractedTransaction) { _, extractedData in
                    if let data = extractedData {
                        // Auto-fill the form with extracted data
                        self.amount = String(format: "%.2f", data.amount)
                        self.description = data.title
                        self.selectedCategory = data.category
                        self.selectedDate = data.formattedDate
                    }
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
            }
            .onAppear {
                self.mapEditableDatas()
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
                selectedCategory: self.$selectedCategory
            )
        }
    }

    // MARK: - Description Input Section
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

        var transaction = Transaction(
            id: isEditing ? (self.transaction?.id ?? UUID().uuidString) : UUID().uuidString,
            type: transactionType,
            category: self.selectedCategory,
            amount: Double(amount) ?? 0.0,
            date: selectedDate.timeIntervalSince1970,
            title: description
        )

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
}
