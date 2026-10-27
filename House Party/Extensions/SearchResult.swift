//
//  SearchResult.swift
//  House Party
//
//  Created by Marcel Schafaczek on 06.08.26.
//

import Foundation
import SpotifyWebAPI

extension SearchResult {
    static let empty: SearchResult = .init(
        artists: nil,
        albums: nil,
        tracks: nil,
        playlists: nil,
        episodes: nil,
        shows: nil,
        audiobooks: nil
    )
}
