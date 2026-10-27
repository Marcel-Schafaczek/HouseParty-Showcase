//
//  QueueItem.swift
//  House Party
//
//  Created by Marcel Schafaczek on 13.08.26.
//

import FirebaseFirestore
import SpotifyWebAPI

public struct QueueItem: Codable, Identifiable {

    @DocumentID
    public var id: String?

    public let track: Track

    public let addedBy: String
    public let addedAt: Date

    public let upVotes: Int
    public let downVotes: Int
    public let score: Int

    public let state: QueueItemState
    
    public enum CodingKeys: String, CodingKey {
        case id
        case track
        case addedBy
        case addedAt
        case upVotes
        case downVotes
        case score // Denormalized: upVotes - downVotes, used for Firestore ordering.
        case state
    }
}
