//
//  FirebaseAuthManager.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation
import FirebaseAuth
import GoogleSignIn
import Combine
import FirebaseCore
import FirebaseFirestore

class FirebaseAuthManager: AuthManagerProtocol {
    @Published var isAuthenticated: Bool?
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        setupAuthListener()
    }

    deinit {
        // Remove listener on main thread since Firebase Auth operations should be on main thread
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Authentication Listener

    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isAuthenticated = user != nil
                self?.currentUser = user
                print("authent: \(self?.isAuthenticated): \(self?.currentUser)")
                // Ensure Firestore has a profile document for this user
                if let strongSelf = self, let user = user {
                    Task { await strongSelf.upsertUserProfile(for: user) }
                }
            }
        }
    }

    private func removeAuthListener() {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
            authStateListener = nil
        }
    }

    // MARK: - Anonymous Authentication

    func signInAnonymously() async {
        isLoading = true
        do {
            let result = try await Auth.auth().signInAnonymously()
            print("Signed in anonymously: \(result.user.uid)")
        } catch {
            errorMessage = "Anonymous sign in failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Email/Password Authentication

    func signInWithEmail(_ email: String, password: String) async {
        isLoading = true
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("Signed in with email: \(result.user.email ?? "")")
        } catch {
            errorMessage = "Email sign in failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func createAccount(email: String, password: String) async {
        isLoading = true
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print("Account created: \(result.user.email ?? "")")
        } catch {
            errorMessage = "Account creation failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func resetPassword(email: String) async {
        isLoading = true
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("Password reset email sent to: \(email)")
        } catch {
            errorMessage = "Password reset failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async {
        isLoading = true

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Google client ID not found"
            isLoading = false
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            errorMessage = "No root view controller found"
            isLoading = false
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get ID token"
                isLoading = false
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            print("Signed in with Google: \(authResult.user.email ?? "")")

        } catch {
            errorMessage = "Google sign in failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        isLoading = true
        do {
            // Sign out from Google if signed in with Google
            if let user = Auth.auth().currentUser,
               user.providerData.contains(where: { $0.providerID == "google.com" }) {
                GIDSignIn.sharedInstance.signOut()
            }

            try Auth.auth().signOut()
            errorMessage = nil
            print("Signed out successfully")
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Profile Management

    func updateProfile(displayName: String? = nil, photoURL: URL? = nil) async {
        guard let user = Auth.auth().currentUser else { return }

        isLoading = true
        let changeRequest = user.createProfileChangeRequest()

        if let displayName = displayName {
            changeRequest.displayName = displayName
        }

        if let photoURL = photoURL {
            changeRequest.photoURL = photoURL
        }

        do {
            try await changeRequest.commitChanges()
            print("Profile updated successfully")
            // Reflect updates in Firestore profile document as well
            await upsertUserProfile(for: user)
        } catch {
            errorMessage = "Profile update failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func deleteAccount() async {
        guard let user = Auth.auth().currentUser else { return }

        isLoading = true
        do {
            try await user.delete()
            print("Account deleted successfully")
        } catch {
            errorMessage = "Account deletion failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - User Info

    var userId: String? {
        return Auth.auth().currentUser?.uid
    }

    var userEmail: String? {
        return Auth.auth().currentUser?.email
    }

    var displayName: String? {
        return Auth.auth().currentUser?.displayName
    }

    var photoURL: URL? {
        return Auth.auth().currentUser?.photoURL
    }

    var isEmailVerified: Bool {
        return Auth.auth().currentUser?.isEmailVerified ?? false
    }

    var providerData: [UserInfo] {
        return Auth.auth().currentUser?.providerData ?? []
    }

    var isGoogleUser: Bool {
        return providerData.contains { $0.providerID == "google.com" }
    }

    var isEmailUser: Bool {
        return providerData.contains { $0.providerID == "password" }
    }

    var isAnonymousUser: Bool {
        return providerData.isEmpty
    }

    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Firestore User Profile

    private func upsertUserProfile(for user: User) async {
        let db = Firestore.firestore()

        // Determine currency code from current selection
        let currencyCode = CurrencyManager.shared.selectedCurrency.code

        let profile = UserProfile(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            photoURL: user.photoURL?.absoluteString,
            providerIds: user.providerData.map { $0.providerID },
            isEmailVerified: user.isEmailVerified,
            currency: currencyCode
        )

        var data = profile.toFirestoreData()
        data["updatedAt"] = FieldValue.serverTimestamp()
        if let creationDate = user.metadata.creationDate {
            data["createdAt"] = Timestamp(date: creationDate)
        }

        do {
            try await db.collection("users")
                .document(user.uid)
                .collection("profile_data")
                .document("profile_\(user.uid)")
                .setData(data, merge: true)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Failed to upsert user profile: \(error.localizedDescription)"
            }
        }
    }
}
