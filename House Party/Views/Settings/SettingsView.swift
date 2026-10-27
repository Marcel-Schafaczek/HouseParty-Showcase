//
//  SettingsView.swift
//  House Party
//
//  Created by Marcel Schafaczek on 03.08.26.
//

import SwiftUI
import SpotifyWebAPI

struct SettingsView: View {
    
    @Environment(SpotifyAuth.self)
    private var spotifyAuth
    
    @Environment(FirebaseAuth.self)
    private var firebaseAuth
    
    var body: some View {
        VStack(spacing: 30) {
            Button("Bei Spotify ausloggen", action: self.signOutSpotify)
                .disabled(!self.spotifyAuth.isAuthorized)
            Button("Bei Firebase ausloggen", action: self.signOutFirebase)
                .disabled(!self.firebaseAuth.isSignedIn)
        }
    }
    
    private func signOutSpotify() {
        self.spotifyAuth.signOut()
    }
    
    private func signOutFirebase() {
        self.firebaseAuth.signOut()
    }
}

#Preview {
    let spotifyAPI = SpotifyAPI(
        authorizationManager: AuthorizationCodeFlowPKCEManager(
            clientId: SpotifyConstants.spotifyClientID
        )
    )
    let spotifyAuth = SpotifyAuth(api: spotifyAPI)
    
    SettingsView()
        .environment(spotifyAuth)
}
