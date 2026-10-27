//
//  House_PartyApp.swift
//  House Party
//
//  Created by Marcel Schafaczek on 22.07.26.
//

import FirebaseCore
import SpotifyWebAPI
import SwiftUI

@main
struct House_PartyApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate
    
    @Environment(\.scenePhase)
    private var scenePhase
    
    @State
    private var spotifyAuth: SpotifyAuth
    @State
    private var spotifyAppRemote: AppRemoteService
    @State
    private var firebaseAuth: FirebaseAuth
    @State
    private var firebaseState: FirebaseState
    @State
    private var partyService: PartyService
    @State
    private var searchService: SearchService
    @State
    private var queueService: QueueService
    
    private let spotifyWebAPI: SpotifyWebAPIService
    private let firestore: FirestoreService
    
    init() {
        FirebaseApp.configure()
        
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
        
        self.spotifyWebAPI = spotifyWebAPI
        self.firestore = firestore
        self._spotifyAuth = State(initialValue: spotifyAuth)
        self._spotifyAppRemote = State(initialValue: spotifyAppRemote)
        self._firebaseAuth = State(initialValue: firebaseAuth)
        self._firebaseState = State(initialValue: firebaseState)
        self._partyService = State(
            initialValue: .init(
                firebaseAuth: firebaseAuth,
                firestore: firestore,
                firebaseState: firebaseState
            )
        )
        self._searchService = State(
            initialValue: .init(
                firebaseAuth: firebaseAuth,
                firestore: firestore,
                firebaseState: firebaseState,
                webAPI: spotifyWebAPI
            )
        )
        self._queueService = State(
            initialValue: .init(
                firebaseAuth: firebaseAuth,
                firestore: firestore,
                firebaseState: firebaseState,
                webAPI: spotifyWebAPI
            )
        )
        
        self.firebaseState.partyChangedCallback = self.partyService.onPartyChanged
        
        self.spotifyAppRemote.addNextTrackToQueueCallback = self.queueService.addNextTrackToSpotifyQueue
        self.spotifyAppRemote.archiveTracksUntilNextPlayableCallback = self.queueService.archiveTracksUntilNextPlayableTracks
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(self.spotifyAuth)
                .environment(self.spotifyAppRemote)
                .environment(self.firebaseAuth)
                .environment(self.firebaseState)
                .environment(self.partyService)
                .environment(self.searchService)
                .environment(self.queueService)
                .task{
                    await self.firebaseAuth.signInAnonymously()
                }
                .onAppear {
                    self.appDelegate.configure(appRemote: self.spotifyAppRemote)
                }
                .onOpenURL { url in
                    self.spotifyAppRemote.onHandleCallback(url: url)
                }
//                .onChange(of: scenePhase) { oldPhase, newPhase in
//                    switch newPhase {
//                    case .active:
//                        self.spotifyAppRemote.connect()
//                    case .inactive:
//                        break
//                    case .background:
//                        //Don't disconnect to be able to queue new tracks
//                        break
//                    @unknown default:
//                        break
//                    }
//                }
        }
    }
}

fileprivate class AppDelegate: NSObject, UIApplicationDelegate {
    private weak var appRemote: AppRemoteService?
    
    func configure(appRemote: AppRemoteService) {
        self.appRemote = appRemote
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        self.appRemote?.pause()
        self.appRemote?.disconnect()
    }
}
