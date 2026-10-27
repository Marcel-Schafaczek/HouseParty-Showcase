//
//  PartyMember.swift
//  House Party
//
//  Created by Marcel Schafaczek on 13.08.26.
//

import FirebaseFirestore

public struct PartyMember: Codable, Identifiable {

    /// MemberID equals UserID
    @DocumentID
    public var id: String?

    public let displayName: String
    public let joinedAt: Date
    public let role: PartyMemberRole
    
    public enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case joinedAt
        case role
    }
}

public enum PartyMemberRole: String, Codable {
    case host
    case guest
}
