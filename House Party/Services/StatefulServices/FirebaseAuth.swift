//
//  FirebaseAuth.swift
//  House Party
//
//  Created by Marcel Schafaczek on 13.08.26.
//

import Foundation
import FirebaseAuth
import Observation

@Observable
public final class FirebaseAuth {
    
    public private(set) var currentUser: User?
    public private(set) var isSignedIn = false
    public private(set) var isSigningIn = false
    
    @ObservationIgnored
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    public var currentUserId: String? {
        return self.currentUser?.uid
    }
    
    public init() {
        self.currentUser = Auth.auth().currentUser
        self.isSignedIn = self.currentUser != nil
        self.observeAuthState()
    }
    
    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }
    
    @MainActor
    public func signInAnonymously() async {
        guard !self.isSigningIn else {
            return
        }
        
        guard Auth.auth().currentUser == nil else {
            self.updateCurrentUser(Auth.auth().currentUser)
            return
        }
        
        self.isSigningIn = true
        
        do {
            let authResult = try await Auth.auth().signInAnonymously()
            self.updateCurrentUser(authResult.user)
        }
        catch {
            print("Couldn't sign in anonymously with Firebase: \(error)")
        }
        
        self.isSigningIn = false
    }
    
    @MainActor
    public func signOut() {
        do {
            try Auth.auth().signOut()
            self.updateCurrentUser(nil)
        }
        catch {
            print("Couldn't sign out from Firebase: \(error)")
        }
    }
    
    private func observeAuthState() {
        self.authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.updateCurrentUser(user)
            }
        }
    }
    
    @MainActor
    private func updateCurrentUser(_ user: User?) {
        self.currentUser = user
        self.isSignedIn = user != nil
    }
}
