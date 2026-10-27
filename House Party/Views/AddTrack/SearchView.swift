//
//  SearchView.swift
//  House Party
//
//  Created by Marcel Schafaczek on 06.08.26.
//

import SwiftUI
import SpotifyWebAPI

struct SearchView: View {
    
    @Environment(SearchService.self)
    private var searchService
    
    @Environment(QueueService.self)
    private var queueService
    
    @State
    private var query = ""
    @State
    private var selectedSearchScopes: [ContentCategory] = []
    @State
    private var isSearching = false
    
    var body: some View {
        VStack {
            if self.isSearching {
                SearchScopeView(
                    selectedScopes: self.$selectedSearchScopes,
                    availableScopes: self.searchService.availableSearchScopes
                )
                
                List {
                    TracksSection(
                        paginatedTracks: self.searchService.searchResult?.tracks,
                        manualLoadNextAction: self.searchService.loadNextPageOfTracks,
                        onClick: self.queueService.addTrackToFirebaseQueue(track:)
                    )
                    PlaylistsSection(
                        paginatedPlaylists: self.searchService.searchResult?.playlists,
                        manualLoadNextAction: self.searchService.loadNextPageOfPlaylists
                    )
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            else {
                Text("Suche...")
            }
        }
        .searchable(
            text: self.$query,
            isPresented: self.$isSearching,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Suchen...")
        )
        .onChange(of: self.query) {
            _,
            newQuery in
            self.searchService
                .search(
                    query: newQuery,
                    selectedSearchScopes: self.selectedSearchScopes,
                    debounce: true
                )
        }
        .onChange(of: self.selectedSearchScopes) { _, newScopes in
            self.searchService
                .search(query: self.query, selectedSearchScopes: newScopes, debounce: false)
        }
        .navigationTitle("Hinzufügen")
    }
}
