//
//  FirebaseSession.swift
//  House Party
//
//  Created by Marcel Schafaczek on 14.08.26.
//

import Foundation

@Observable
public final class FirebaseState {    
    private struct Keys {
        static let currentPartyID = "CURRENT_PARTY_ID"
        private init() { }
    }
    
    public var partyChangedCallback: ((_ partyId: String?) -> Void)?
    
    public private(set) var currentPartyId: String? = UserDefaults.standard.string(
        forKey: Keys.currentPartyID
    ) {
        didSet {
            UserDefaults.standard.set(self.currentPartyId, forKey: Keys.currentPartyID)
            self.partyChangedCallback?(self.currentPartyId)
        }
    }
    
    public func setCurrentPartyId(_ partyId: String?) {
        self.currentPartyId = partyId
    }
}
