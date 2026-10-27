//
//  Spotify.swift
//  House Party
//
//  Created by Marcel Schafaczek on 22.07.26.
//

import Foundation
import SpotifyWebAPI

public struct SpotifyConstants {
    public static let spotifyClientID: String = ""
    public static let redirectURL = URL(string: "")!
    public static let scopes: Set<Scope> = [
        .appRemoteControl,
        .userReadPlaybackState,
        .userModifyPlaybackState,
        .userReadCurrentlyPlaying,
        .userTopRead,
        .userReadPrivate,
        .userReadRecentlyPlayed,
        .userLibraryRead,
        .userLibraryModify,
        .playlistReadPrivate,
        .playlistModifyPrivate,
        .playlistModifyPublic,
        .playlistReadCollaborative
    ]
    
    public static let availableSearchScopes: [ContentCategory] = [
        .init(spotifyValue: .track, displayValue: Self.tracksDisplayValue),
        .init(spotifyValue: .playlist, displayValue: Self.playlistsDisplayValue),
        .init(spotifyValue: .album, displayValue: Self.albumsDisplayValue),
        .init(spotifyValue: .artist, displayValue: Self.artistsDisplayValue),
//        .init(spotifyValue: .user, displayValue: Self.usersDisplayValue),
//        .init(spotifyValue: .genre, displayValue: Self.genresDisplayValue)
    ]
    
    public static let tracksDisplayValue: String = "Songs"
    public static let playlistsDisplayValue: String = "Playlists"
    public static let albumsDisplayValue: String = "Alben"
    public static let artistsDisplayValue: String = "Künstler*innen"
    public static let usersDisplayValue: String = "Profile"
    public static let genresDisplayValue: String = "genres und Stimmungen"
    
    private init() { }
}
