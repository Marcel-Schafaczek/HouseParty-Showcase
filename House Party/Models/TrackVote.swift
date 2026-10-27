//
//  TrackVote.swift
//  House Party
//
//  Created by Marcel Schafaczek on 13.08.26.
//

import FirebaseFirestore

public struct TrackVote: Codable, Identifiable {

    @DocumentID
    public var id: String?

    public let direction: VoteDirection
    public let createdAt: Date
    
    public enum CodingKeys: String, CodingKey {
        case id
        case direction
        case createdAt
    }
}

public enum VoteDirection: String, Codable {
    case up
    case down
}
