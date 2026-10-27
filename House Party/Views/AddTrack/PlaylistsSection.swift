//
//  PlaylistsSection.swift
//  House Party
//
//  Created by Marcel Schafaczek on 11.08.26.
//

import SwiftUI
import SpotifyWebAPI

struct PlaylistsSection: View {
    public let paginatedPlaylists: PagingObject<Playlist<PlaylistItemsReference>>?
    public let manualLoadNextAction: (() async -> Void)?
    
    @State
    private var isLoading: Bool = false
    
    var body: some View {
        if let paginatedPlaylists {
            Section(header: Text(SpotifyConstants.playlistsDisplayValue)) {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: nil,
                    pinnedViews: []
                ) {
                    ForEach(paginatedPlaylists.items, id: \.id) { playlist in
                        PlaylistTile(
                            playlist: playlist,
                            coverImageSize: UIConstants.coverImageSizeSmall
                        ) {
                            print("\(playlist.id), \(playlist.name)")
                        }
                    }
                }
                
                if let _ = paginatedPlaylists.next, let manualLoadNextAction {
                    Button {
                        defer { self.isLoading = false }
                        
                        Task {
                            self.isLoading = true
                            await manualLoadNextAction()
                        }
                    } label: {
                        Text("Weitere \(SpotifyConstants.playlistsDisplayValue) laden")
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.accent.opacity(0.5))
                    }
                    .disabled(self.isLoading)
                }
            }
            .listRowSeparator(.hidden)
        }
    }
}
