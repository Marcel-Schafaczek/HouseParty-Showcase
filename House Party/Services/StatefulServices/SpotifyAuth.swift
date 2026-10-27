//
//  SpotifyAuth.swift
//  House Party
//
//  Created by Marcel Schafaczek on 28.07.26.
//

import Foundation
import SpotifyWebAPI
import Combine
import KeychainAccess
import AuthenticationServices
import Observation
import UIKit

@Observable
public final class SpotifyAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    
    private static let authorizationManagerKey = "authorizationManager"
    private static let accessTokenExpirationTolerance: TimeInterval = 120
    
    public private(set) var isAuthorized = false
    public private(set) var isRetrievingTokens = false
    public private(set) var currentUser: SpotifyUser? = nil

    public var accessToken: String? {
        self.spotifyAPI.authorizationManager.accessToken
    }
    
    @ObservationIgnored
    private let keychain = Keychain(service: "Marcel-Schafaczek.House-Party")
    
    @ObservationIgnored
    private let spotifyAPI: SpotifyAPI<AuthorizationCodeFlowPKCEManager>
    
    @ObservationIgnored
    private var currentSession: ASWebAuthenticationSession?
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private var codeVerifier: String?
    @ObservationIgnored
    private var authorizationState: String?
    @ObservationIgnored
    private var presentationAnchor: ASPresentationAnchor?
    @ObservationIgnored
    private var refreshAccessTokenTask: Task<Void, Error>?
    
    public init(api: SpotifyAPI<AuthorizationCodeFlowPKCEManager>) {
        self.spotifyAPI = api
        super.init()
        
        self.spotifyAPI.authorizationManagerDidChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.authorizationManagerDidChange()
            }
            .store(in: &self.cancellables)
        
        self.spotifyAPI.authorizationManagerDidDeauthorize
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.authorizationManagerDidDeauthorize()
            }
            .store(in: &self.cancellables)
        
        self.restoreAuthorizationManager()
    }
    
    public func authorize() {
        guard !self.isRetrievingTokens else {
            return
        }
        
        guard let authorizationURL = self.createAuthorizationURL() else {
            print("Unable to create Spotify authorization URL.")
            return
        }
        
        self.startAuthentication(authURL: authorizationURL)
    }
    
    public func signOut() {
        self.currentSession?.cancel()
        self.currentSession = nil
        self.codeVerifier = nil
        self.authorizationState = nil
        self.refreshAccessTokenTask?.cancel()
        self.refreshAccessTokenTask = nil
        self.currentUser = nil
        self.spotifyAPI.authorizationManager.deauthorize()
    }
    
    @MainActor
    public func refreshAccessTokenIfNeeded() async throws {
        guard self.accessTokenNeedsRefresh else {
            return
        }
        
        if let refreshAccessTokenTask {
            try await refreshAccessTokenTask.value
            return
        }
        
        let refreshAccessTokenTask = Task { @MainActor in
            try await self.refreshAccessTokenPreservingRefreshToken()
        }
        self.refreshAccessTokenTask = refreshAccessTokenTask
        
        do {
            try await refreshAccessTokenTask.value
            self.refreshAccessTokenTask = nil
        }
        catch {
            self.refreshAccessTokenTask = nil
            throw error
        }
    }
    
    private func createAuthorizationURL() -> URL? {
        let codeVerifier = String.randomURLSafe(length: 128)
        let codeChallenge = String.makeCodeChallenge(codeVerifier: codeVerifier)
        let state = String.randomURLSafe(length: 128)
        
        self.codeVerifier = codeVerifier
        self.authorizationState = state
        
        return self.spotifyAPI.authorizationManager.makeAuthorizationURL(
            redirectURI: SpotifyConstants.redirectURL,
            codeChallenge: codeChallenge,
            state: state,
            scopes: SpotifyConstants.scopes
        )
    }
    
    private func startAuthentication(authURL: URL) {
        guard let presentationAnchor = self.activePresentationAnchor() else {
            DispatchQueue.main.async { [weak self] in
                self?.startAuthentication(authURL: authURL)
            }
            return
        }
        
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "houseparty"
        ) { [weak self] callbackURL, error in
            guard let self else {
                return
            }
            
            if let error = error {
                self.currentSession = nil
                self.presentationAnchor = nil
                
                if let authenticationError = error as? ASWebAuthenticationSessionError {
                    if authenticationError.code == .canceledLogin {
                        print("Authorization cancelled by user.")
                    }
                    else {
                        print("Other ASWebAuthenticationSessionError: \(authenticationError)")
                    }
                }
                else {
                    print("Unknown authentication error: \(error)")
                }
                
                self.clearPendingAuthorizationRequest()
                return
            }
            
            guard let callbackURL else {
                self.clearPendingAuthorizationRequest()
                return
            }
            
            self.exchangeCodeForTokens(redirectURIWithQuery: callbackURL)
        }
                
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false // Cookie-Sharing
        self.presentationAnchor = presentationAnchor
        self.currentSession = session
                
        session.start()
    }
    
    private func exchangeCodeForTokens(redirectURIWithQuery: URL) {
        guard
            let codeVerifier = self.codeVerifier,
            let authorizationState = self.authorizationState
        else {
            print("Missing Spotify PKCE authorization request state.")
            self.clearPendingAuthorizationRequest()
            return
        }
        
        DispatchQueue.main.async {
            self.isRetrievingTokens = true
        }
        
        self.spotifyAPI.authorizationManager.requestAccessAndRefreshTokens(
            redirectURIWithQuery: redirectURIWithQuery,
            codeVerifier: codeVerifier,
            state: authorizationState
        )
        .receive(on: RunLoop.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                guard let self else {
                    return
                }
                
                self.isRetrievingTokens = false
                self.currentSession = nil
                self.presentationAnchor = nil
                self.clearPendingAuthorizationRequest()
                
                switch completion {
                case .finished:
                    self.retrieveCurrentUser()
                case .failure(let error):
                    print("Couldn't authorize Spotify: \(error)")
                }
            },
            receiveValue: { }
        )
        .store(in: &self.cancellables)
    }
    
    private func retrieveCurrentUser() {
        Task {
            await self.retrieveCurrentUserAsync()
        }
    }
    
    @MainActor
    private func retrieveCurrentUserAsync() async {
        guard self.spotifyAPI.authorizationManager
            .isAuthorized(for: SpotifyConstants.scopes) else {
            self.currentUser = nil
            return
        }
        
        do {
            try await self.refreshAccessTokenIfNeeded()
            
            self.currentUser = try await self.currentUserProfile()
        }
        catch {
            if let authError = error as? SpotifyAuthenticationError, authError.error == "invalid_grant" {
                print("Did deauthorize Spotify due to invalid grant: \(error)")
                self.authorizationManagerDidDeauthorize()
            }
            else {
                print("Couldn't retrieve current Spotify user: \(error)")
            }
        }
    }
    
    private var accessTokenNeedsRefresh: Bool {
        guard let expirationDate = self.spotifyAPI.authorizationManager.expirationDate else {
            return true
        }
        
        return expirationDate.timeIntervalSinceNow <= Self.accessTokenExpirationTolerance
    }
    
    @MainActor
    private func refreshAccessTokenPreservingRefreshToken() async throws {
        guard let refreshToken = self.spotifyAPI.authorizationManager.refreshToken else {
            self.authorizationManagerDidDeauthorize()
            throw AuthError.missingRefreshToken
        }
        
        let authInfo = try await self.refreshAuthInfo(refreshToken: refreshToken)
        
        guard
            let accessToken = authInfo.accessToken,
            let expirationDate = authInfo.expirationDate
        else {
            throw AuthError.missingAccessTokenOrExpirationDateAfterRefreshingTokens
        }
        
        let refreshedManager = AuthorizationCodeFlowPKCEManager(
            clientId: SpotifyConstants.spotifyClientID,
            accessToken: accessToken,
            expirationDate: expirationDate,
            refreshToken: authInfo.refreshToken ?? refreshToken,
            scopes: authInfo.scopes.isEmpty ? self.spotifyAPI.authorizationManager.scopes : authInfo.scopes
        )
        
        self.spotifyAPI.authorizationManager = refreshedManager
        self.authorizationManagerDidChange()
    }
    
    private func refreshAuthInfo(refreshToken: String) async throws -> AuthInfo {
        let (data, response) = try await self.spotifyAPI.authorizationManager.backend
            .refreshTokens(refreshToken: refreshToken)
            .firstResponse()
        
        return try decodeSpotifyObject(
            data: data,
            httpURLResponse: response,
            responseType: AuthInfo.self
        )
    }
    
    private func currentUserProfile() async throws -> SpotifyUser {
        try await self.spotifyAPI.currentUserProfile()
            .firstResponse()
    }
    
    private func restoreAuthorizationManager() {
        guard let authorizationManagerData = self.keychain[data: Self.authorizationManagerKey] else {
            self.isAuthorized = false
            return
        }
        
        do {
            let authorizationManager = try JSONDecoder().decode(
                AuthorizationCodeFlowPKCEManager.self,
                from: authorizationManagerData
            )
            
            self.spotifyAPI.authorizationManager = authorizationManager
            
            self.retrieveCurrentUser()
        }
        catch {
            print("Couldn't restore Spotify authorization manager: \(error)")
            self.isAuthorized = false
        }
    }
    
    private func authorizationManagerDidChange() {
        self.isAuthorized = self.spotifyAPI.authorizationManager
            .isAuthorized(for: SpotifyConstants.scopes)
        
        do {
            let authorizationManagerData = try JSONEncoder().encode(
                self.spotifyAPI.authorizationManager
            )
            self.keychain[data: Self.authorizationManagerKey] = authorizationManagerData
        }
        catch {
            print("Couldn't save Spotify authorization manager to keychain: \(error)")
        }
    }
    
    private func authorizationManagerDidDeauthorize() {
        self.isAuthorized = false
        self.currentUser = nil
        
        do {
            try self.keychain.remove(Self.authorizationManagerKey)
        }
        catch {
            print("Couldn't remove Spotify authorization manager from keychain: \(error)")
        }
    }
    
    private func clearPendingAuthorizationRequest() {
        self.codeVerifier = nil
        self.authorizationState = nil
    }
    
    // MARK: - ASWebAuthenticationSession
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let presentationAnchor {
            return presentationAnchor
        }
        
        guard let presentationAnchor = self.activePresentationAnchor() else {
            fatalError(
                "Spotify authentication requires an active window scene."
            )
        }
        
        return presentationAnchor
    }
    
    private func activePresentationAnchor() -> ASPresentationAnchor? {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap {
            $0 as? UIWindowScene
        }
        let activeWindowScene = windowScenes.first {
            $0.activationState == .foregroundActive
        }
        
        guard let activeWindowScene else {
            return nil
        }
        
        return activeWindowScene.windows
            .first { $0.isKeyWindow } ?? ASPresentationAnchor(
                windowScene: activeWindowScene
            )
    }
}

extension SpotifyAuth {
    public enum AuthError: Error {
        case missingRefreshToken
        case missingAccessTokenOrExpirationDateAfterRefreshingTokens
    }
}
