//
//  FirebaseManager.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation
import Combine

//@MainActor
//class FirebaseManager: ObservableObject {
//    @Published var authManager: FirebaseAuthManager
//    @Published var transactionManager: FirebaseTransactionManager
//
//    @Published var isAuthenticated: Bool = false
//    private var cancellables: Set<AnyCancellable> = []
//
//    init() {
//        let authManager = FirebaseAuthManager()
//        self.authManager = authManager
//        self.transactionManager = FirebaseTransactionManager(authManager: authManager)
//        self.startObservers()
//    }
//
//    private func startObservers() {
//        self.authManager.$isAuthenticated
//            .receive(on: RunLoop.main)
//            .sink(receiveValue: { val in
//                self.isAuthenticated = val
//            })
//            .store(in: &cancellables)
//    }
//
//    // MARK: - Convenience Methods
//    
//    var transactions: [Transaction] {
//        return transactionManager.transactions
//    }
//    
//    var isLoading: Bool {
//        return transactionManager.isLoading
//    }
//    
//    var errorMessage: String? {
//        return authManager.errorMessage ?? transactionManager.errorMessage
//    }
//    
//    // MARK: - Authentication Methods
//    
//    func signInAnonymously() async {
//        await authManager.signInAnonymously()
//    }
//    
//    func signOut() {
//        authManager.signOut()
//    }
//    
//    // MARK: - Transaction Methods
//    
//    func addTransaction(_ transaction: Transaction) async {
//        await transactionManager.addTransaction(transaction)
//    }
//    
//    func updateTransaction(_ transaction: Transaction) async {
//        await transactionManager.updateTransaction(transaction)
//    }
//    
//    func deleteTransaction(_ transaction: Transaction) async {
//        await transactionManager.deleteTransaction(transaction)
//    }
//    
//    func loadTransactions() async {
//        await transactionManager.loadTransactions()
//    }
//    
//    // MARK: - Statistics
//    
//    func getTotalBalance() -> Double {
//        return transactionManager.getTotalBalance()
//    }
//    
//    func getTotalIncome() -> Double {
//        return transactionManager.getTotalIncome()
//    }
//    
//    func getTotalExpenses() -> Double {
//        return transactionManager.getTotalExpenses()
//    }
//    
//    func getExpensesByCategory() -> [TransactionCategory: Double] {
//        return transactionManager.getExpensesByCategory()
//    }
//    
//    // MARK: - Error Handling
//    
//    func clearError() {
//        authManager.clearError()
//        transactionManager.clearError()
//    }
//}
