//
//  Party.swift
//  House Party
//
//  Created by Marcel Schafaczek on 13.08.26.
//

import FirebaseFirestore

public struct Party: Codable, Identifiable, Hashable {

    @DocumentID
    public var id: String?

    public let name: String
    public let hostUserId: String
    public let joinCode: String
    public let createdAt: Date
    public let status: PartyStatus
    
    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case hostUserId
        case joinCode
        case createdAt
        case status
    }
}

public enum PartyStatus: String, Codable {
    case active
    case finished
}
