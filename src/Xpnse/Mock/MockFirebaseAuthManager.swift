//
//  MockFirebaseAuthManager.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
class MockFirebaseAuthManager: ObservableObject, AuthManagerProtocol {
    @Published var isAuthenticated: Bool? = false
    @Published var currentUser: User? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false

    func signInAnonymously() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isAuthenticated = true
        isLoading = false
    }
    func signInWithEmail(_ email: String, password: String) async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isAuthenticated = true
        isLoading = false
    }
    func createAccount(email: String, password: String) async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isAuthenticated = true
        isLoading = false
    }
    func signInWithGoogle() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isAuthenticated = true
        isLoading = false
    }
    func signOut() {
        isAuthenticated = false
    }
    func resetPassword(email: String) async {
        // No-op for mock
    }
    func updateProfile(displayName: String?, photoURL: URL?) async {
        // No-op for mock
    }
    func deleteAccount() async {
        isAuthenticated = false
    }
    func clearError() {
        errorMessage = nil
    }
}
