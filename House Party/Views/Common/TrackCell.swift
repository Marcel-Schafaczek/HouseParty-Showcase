//
//  QueueCell.swift
//  House Party
//
//  Created by Marcel Schafaczek on 28.07.26.
//

import SwiftUI
import SpotifyWebAPI

struct TrackCell: View {
    let track: Track
    let coverImageSize: CGSize
    let onClick: ((_ selectedTrack: Track) async -> Void)?
    
    init(
        track: Track,
        coverImageSize: CGSize = UIConstants.coverImageSizeMedium,
        onClick: ((_ selectedTrack: Track) async -> Void)? = nil
    ) {
        self.track = track
        self.coverImageSize = coverImageSize
        self.onClick = onClick
    }
    
    var body: some View {
        Button {
            Task {
                await self.onClick?(track)
            }
        } label: {
            HStack {
                RemoteImage(url: track.album?.images?.first?.url, size: self.coverImageSize)
                
                VStack(alignment: .leading) {
                    Text(track.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    if let artists = track.artists?.map({ $0.name }).joined(separator: ", ") {
                        Text(artists)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
                .lineLimit(1)
                .truncationMode(.tail)
            }
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
    }
}
