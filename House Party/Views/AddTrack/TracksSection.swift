//
//  SearchTracksListView.swift
//  House Party
//
//  Created by Marcel Schafaczek on 08.08.26.
//

import SwiftUI
import SpotifyWebAPI

struct TracksSection: View {
    private let paginatedTracks: PagingObject<Track>?
    private let manualLoadNextAction: (() async -> Void)?
    private let onClick: ((_ selectedTrack: Track) async -> Void)?
    
    init(
        paginatedTracks: PagingObject<Track>?,
        manualLoadNextAction: (() async -> Void)?,
        onClick: ((_ selectedTrack: Track) async -> Void)? = nil
    ) {
        self.paginatedTracks = paginatedTracks
        self.manualLoadNextAction = manualLoadNextAction
        self.onClick = onClick
    }
    
    @State
    private var isLoading: Bool = false
    
    var body: some View {
        if let paginatedTracks {
            Section(header: Text(SpotifyConstants.tracksDisplayValue)) {
                ForEach(paginatedTracks.items, id: \.id) { track in
                    TrackCell(track: track, coverImageSize: UIConstants.coverImageSizeMedium, onClick: self.onClick)
                }
                
                if let _ = paginatedTracks.next, let manualLoadNextAction {
                    Button {
                        defer { self.isLoading = false }
                        
                        Task {
                            self.isLoading = true
                            await manualLoadNextAction()
                        }
                    } label: {
                        Text("Weitere \(SpotifyConstants.tracksDisplayValue) laden")
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.accent.opacity(0.5))
                    }
                    .disabled(self.isLoading)
                }
            }
        }
    }
}
