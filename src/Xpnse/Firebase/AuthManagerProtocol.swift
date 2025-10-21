//
//  AuthManagerProtocol.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import FirebaseAuth
import Foundation

@MainActor
protocol AuthManagerProtocol: ObservableObject {
    var isAuthenticated: Bool? { get set }
    var currentUser: User? { get set }
    var errorMessage: String? { get set }
    var isLoading: Bool { get set }
    
    func signInAnonymously() async
    func signInWithEmail(_ email: String, password: String) async
    func createAccount(email: String, password: String) async
    func signInWithGoogle() async
    func signOut()
    func resetPassword(email: String) async
    func updateProfile(displayName: String?, photoURL: URL?) async
    func deleteAccount() async
    func clearError()
}
