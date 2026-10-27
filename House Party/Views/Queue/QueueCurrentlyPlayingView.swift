//
//  QueueCurrentlyPlayingView.swift
//  House Party
//
//  Created by Marcel Schafaczek on 25.08.26.
//

import SwiftUI
import SpotifyWebAPI

public struct QueueCurrentlyPlayingView: View {
    
    @Environment(QueueService.self)
    private var queueService
    @Environment(AppRemoteService.self)
    private var appRemote
    
    public var body: some View {
        VStack {
            HStack {
                if self.appRemote.isConnected {
                    if self.appRemote.hasCurrentTrack {
                        if let uiImage = self.appRemote.currentTrackImage {
                            Image(uiImage: uiImage)
                                .toTrackCoverImage()
                        } else {
                            Image(systemName: "nosign.app")
                                .toTrackCoverImage()
                        }
                        
                        VStack(alignment: .leading) {
                            if let title = self.appRemote.currentTrackTitle {
                                Text(title)
                                    .font(.headline)
                            }
                            
                            if let artists = self.appRemote.currentTrackArtitsts {
                                Text(artists)
                                    .font(.subheadline)
                            }
                        }
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    }
                    else {
                        self.createInfoText("Keine Wiedergabe")
                    }
                } else {
                    self.createInfoText("Keine Verbindung zur Spotify App")
                }
                
                Spacer()
                
                Button(action: {
                    self.appRemote.togglePlaybackState()
                }) {
                    Image(systemName: self.appRemote.isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .padding(10)
                        .clipShape(Circle())
                        .overlay {
                            Circle().strokeBorder(style: .init(lineWidth: 2.5))
                        }
                }
                .buttonStyle(.plain)
            }
            
            if self.appRemote.hasCurrentTrack {
                ProgressView(value: self.appRemote.playbackProgress)
                    .tint(.white)
                    .progressViewStyle(.linear)
            }
        }
        .listRowBackground(Color.accentColor)
    }
    
    private func createInfoText(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.white)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(height: UIConstants.coverImageSizeMedium.height)
    }
}
