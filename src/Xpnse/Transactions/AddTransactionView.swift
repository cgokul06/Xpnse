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

    @StateObject private var billScannerService = BillScannerService()
    @State private var showingBillScanner = false

    @State private var transactionType: TransactionType = .expense
    @State private var amount: String = ""
    @State private var selectedCategory: TransactionCategory?
    @State private var description: String = ""
    @State private var selectedDate = Date()
    @State private var isLoading = false
    private let transactionManager: FirebaseTransactionManager = .shared

    private var categories: [TransactionCategory] {
        TransactionCategory.categories(for: transactionType)
    }

    private var isFormValid: Bool {
        !(amount.isEmpty || selectedCategory == nil)
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
//                .onChange(of: billScannerService.extractedData) { extractedData in
//                    if let data = extractedData {
//                        // Auto-fill the form with extracted data
//                        if let cost = data.amount {
//                            amount = String(format: "%.2f", cost)
//                        }
//                        if let merchant = data.merchant {
//                            description = merchant
//                        }
//                        if let category = data.category {
//                            selectedCategory = category
//                        }
//                        if let date = data.date {
//                            selectedDate = date
//                        }
//
//                        // Close the scanner after auto-filling
//                        showingBillScanner = false
//                    }
//                }
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
                            .bold()
                            .padding(.all, 8)
                    })
                    .foregroundStyle(Color.white)
                }

                ToolbarItem(placement: .principal) {
                    Text("Add Transaction")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .navigationBarBackButtonHidden()
    }

    // MARK: - Transaction Type Selector
    private var transactionTypeSelector: some View {
        HStack(spacing: 12) {
            Button(action: {
                transactionType = .expense
                selectedCategory = nil
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
                .background(transactionType == .expense ? XpnseColorKey.primaryButtonBGColor.color : Color.gray.opacity(0.3))
                .xpnseRoundedCorner()
            }

            Button(action: {
                transactionType = .income
                selectedCategory = nil
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
                .background(transactionType == .income ? XpnseColorKey.primaryButtonBGColor.color : Color.gray.opacity(0.3))
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            // Square scrollable box
            GeometryReader { geometry in
                let boxSize = min(geometry.size.width, 320)
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(selectedCategory == category ? XpnseColorKey.primaryButtonBGColor.color : Color.gray.opacity(0.3))
                                        .clipShape(Circle())

                                    Text(category.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .frame(height: 30, alignment: .top)
                                }
                            }
                        }
                    }
                    .padding(.all, 12)
                }
                .frame(height: boxSize)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(XpnseColorKey.whiteWithAlphaThirty.color, lineWidth: 2)
                )
            }
            .frame(height: 320)
        }
    }

    // MARK: - Description Input Section
    private var descriptionInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            TextField("Add a description", text: $description)
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
                addTransaction()
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

                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isFormValid ? XpnseColorKey.primaryButtonBGColor.color : Color.gray.opacity(0.3))
                .xpnseRoundedCorner()
            }
            .disabled(!isFormValid || isLoading)

            // Scan Bill Button
            Button(action: {
                scanBill()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 16, weight: .semibold))

                    Text("Scan Bill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.gray.opacity(0.3))
                .xpnseRoundedCorner()
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Actions
    private func addTransaction() {
        guard let category = selectedCategory, !amount.isEmpty else { return }

        isLoading = true

        let transaction = Transaction(
            id: UUID().uuidString,
            type: transactionType,
            category: category,
            amount: Double(amount) ?? 0.0,
            date: selectedDate.timeIntervalSince1970,
            title: description
        )
         Task {
             await transactionManager.addTransaction(transaction)
             await MainActor.run {
                 isLoading = false
                 self.dismiss()
             }
         }
    }

    private func scanBill() {
        // Implement bill scanning functionality
//        print("Scan bill tapped")
        self.homeCoordinator.push(.billScanner)
    }
}

#Preview {
    AddTransactionView()
        .environmentObject(NavigationCoordinator<HomeRoute>())
}
