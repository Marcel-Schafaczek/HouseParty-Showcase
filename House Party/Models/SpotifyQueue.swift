//
//  SpotifyQueue.swift
//  House Party
//
//  Created by Marcel Schafaczek on 04.08.26.
//

import Foundation
import SpotifyWebAPI

public struct SpotifyQueue: Hashable {
    public static let empty = SpotifyQueue(currentlyPlaying: nil, queue: [])
    
    public private(set) var currentlyPlaying: Track?
    public private(set) var queue: [Track]
    
    public mutating func updateQueue(newQueue: SpotifyQueue, trackIdsToIgnore: [String]) {
        self.currentlyPlaying = newQueue.currentlyPlaying
        self.queue = newQueue.queue.filter{ spotifyQueueTrack in
            if let spotifyTrackId = spotifyQueueTrack.id {
                return !trackIdsToIgnore.contains(spotifyTrackId)
            }
            
            return false
        }
    }
}
