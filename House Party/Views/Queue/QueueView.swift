//
//  QueueView.swift
//  House Party
//
//  Created by Marcel Schafaczek on 26.07.26.
//

import SwiftUI
import SpotifyWebAPI

struct QueueView: View {
    
    @Environment(QueueService.self)
    private var queueService
    
    @Environment(AppRemoteService.self)
    private var appRemote
    
//    @State
//    private var emptyState: EmptyState? = .init(title: "Wird geladen", showLoadingIndicator: true)
    
    var body: some View {
        self.listBody
            .navigationTitle("Warteschlange")
    }
    
    private var listBody: some View {
        GeometryReader { geometry in
            List {
                Section(header: Text("Aktuelle Wiedergabe")) {
                    QueueCurrentlyPlayingView()
                }
                    
                Section(header: Text("Warteschlange")) {
                    ForEach(self.queueService.firebaseQueue) { queueItem in
                        QueueItemView(item: queueItem)
                    }
                }
                
                if !self.queueService.spotifyQueue.queue.isEmpty {
                    Section(header: Text("Danach")) {
                        ForEach(self.queueService.spotifyQueue.queue, id: \.id) { track in
                            TrackCell(track: track)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .task {
                let _ = await self.queueService.loadSpotifyQueue()
            }
            .refreshable{
                let _ = await self.queueService.loadSpotifyQueue()
            }
            .onAppear {
                self.queueService.startListeningToQueue()
            }
            .onDisappear {
                self.queueService.stopListeningToQueue()
            }
            .onChange(of: self.appRemote.currentTrackURI) { _, newTrackURI in
                guard newTrackURI != nil else {
                    self.queueService.clearSpotifyQueue()
                    return
                }
                
                Task {
                    await self.queueService.loadSpotifyQueue()
                }
            }
        }
    }
}

#Preview {
    let spotifyAPI = SpotifyAPI(
        authorizationManager: AuthorizationCodeFlowPKCEManager(
            clientId: SpotifyConstants.spotifyClientID
        )
    )
    let spotifyWebAPI = SpotifyWebAPIService(api: spotifyAPI, auth: SpotifyAuth(api: spotifyAPI))
    let firebaseAuth = FirebaseAuth()
    let firestore = FirestoreService()
    let firebaseState = FirebaseState()
    
    NavigationStack {
        QueueView()
    }
    .environment(
        QueueService(
            firebaseAuth: firebaseAuth,
            firestore: firestore,
            firebaseState: firebaseState,
            webAPI: spotifyWebAPI
        )
    )
}
