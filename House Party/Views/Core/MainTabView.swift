//
//  ContentView.swift
//  House Party
//
//  Created by Marcel Schafaczek on 22.07.26.
//

import SpotifyWebAPI
import SwiftUI

struct MainTabView: View {
    
    private enum TabType: Hashable {
        case queue
        case add
        case settings
        case controls
    }
    
    @Environment(SpotifyAuth.self)
    private var spotifyAuth
    
    @State
    private var selectedTab: TabType = .queue
    
    var body: some View {
        TabView(selection: self.$selectedTab) {
            Tab("Warteschlange", systemImage: "list.triangle", value: TabType.queue) {
                NavigationStack {
                    QueueView()
                }
            }
            
            Tab("Hinzufügen", systemImage: "plus.circle", value: TabType.add) {
                NavigationStack {
                    SearchView()
                }
            }
            
            Tab("Einstellungen", systemImage: "gear", value: TabType.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toastMessageOverlay()
    }
}

#Preview {
    let spotifyAPI = SpotifyAPI(
        authorizationManager: AuthorizationCodeFlowPKCEManager(
            clientId: SpotifyConstants.spotifyClientID
        )
    )
    let spotifyAuth = SpotifyAuth(api: spotifyAPI)
    let spotifyAppRemote = AppRemoteService(auth: spotifyAuth)
    let spotifyWebAPI = SpotifyWebAPIService(api: spotifyAPI, auth: spotifyAuth)
    let firebaseAuth = FirebaseAuth()
    let firebaseState = FirebaseState()
    let firestore = FirestoreService()
    
    MainTabView()
        .environment(spotifyAuth)
        .environment(spotifyAppRemote)
        .environment(firebaseAuth)
        .environment(firebaseState)
        .environment(
            SearchService(
                firebaseAuth: firebaseAuth,
                firestore: firestore,
                firebaseState: firebaseState,
                webAPI: spotifyWebAPI
            )
        )
        .environment(
            QueueService(
                firebaseAuth: firebaseAuth,
                firestore: firestore,
                firebaseState: firebaseState,
                webAPI: spotifyWebAPI
            )
        )
}
