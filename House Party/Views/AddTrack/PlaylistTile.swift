//
//  PlaylistTile.swift
//  House Party
//
//  Created by Marcel Schafaczek on 11.08.26.
//

import SwiftUI
import SpotifyWebAPI

struct PlaylistTile: View {
    let playlist: Playlist<PlaylistItemsReference>
    let coverImageSize: CGSize
    let onClick: (() async -> Void)?
    
    init(
        playlist: Playlist<PlaylistItemsReference>,
        coverImageSize: CGSize,
        onClick: (() async -> Void)? = nil
    ) {
        self.playlist = playlist
        self.coverImageSize = coverImageSize
        self.onClick = onClick
    }
    
    var body: some View {
        Button {
            Task {
                await self.onClick?()
            }
        } label: {
            HStack {
                RemoteImage(url: playlist.images.first?.url, size: self.coverImageSize)
                
                Text(playlist.name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .buttonStyle(.plain)
        .disabled(self.onClick == nil)
    }
}
