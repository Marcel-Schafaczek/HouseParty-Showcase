//
//  PartyService.swift
//  House Party
//
//  Created by Marcel Schafaczek on 21.08.26.
//

import Foundation
import Combine

@MainActor
@Observable
public final class PartyService {
    private let firestore: FirestoreService
    private let firebaseAuth: FirebaseAuth
    private let firebaseState: FirebaseState
    
    public private(set) var party: Party? = nil
    public private(set) var members: [PartyMember]? = nil
    
    @ObservationIgnored
    private var partyCancellable: AnyCancellable? = nil
    @ObservationIgnored
    private var membersCancellable: AnyCancellable? = nil
    
    public init(
        firebaseAuth: FirebaseAuth,
        firestore: FirestoreService,
        firebaseState: FirebaseState
    ) {
        self.firestore = firestore
        self.firebaseAuth = firebaseAuth
        self.firebaseState = firebaseState
        
        self.startListeningToParty()
    }
    
    isolated deinit {
        self.stopListeningToParty()
    }
    
    @discardableResult
    public func createParty(name: String, hostDisplayName: String) async -> Party? {
        guard let hostUserId = self.firebaseAuth.currentUserId else {
            print("Not signed in and so can't create party")
            return nil
        }
        
        do {
            let party = try await self.firestore
                .createParty(name: name, hostUserId: hostUserId, hostDisplayName: hostDisplayName)
            self.firebaseState.setCurrentPartyId(party.id)
            self.restartListeningToParty()
            self.restartListeningToMembers()
            
            return party
        }
        catch {
            print(error)
            
            return nil
        }
    }
    
    @discardableResult
    public func joinParty(joinCode: String, userDisplayName: String) async -> Party? {
        guard let userId = self.firebaseAuth.currentUserId else {
            print("Not signed in and so can't join party")
            return nil
        }
        
        do {
            guard let party = try await self.firestore.getActiveParty(joinCode: joinCode), let partyId = party.id else {
                print("Party with join code \(joinCode) not found")
                return nil
            }
            try await self.firestore
                .joinParty(id: partyId, userId: userId, displayName: userDisplayName)
            self.firebaseState.setCurrentPartyId(partyId)
            self.restartListeningToParty()
            self.restartListeningToMembers()
            
            return party
        }
        catch {
            print(error)
            
            return nil
        }
    }
    
    public func leaveParty() async {
        guard let partyId = self.firebaseState.currentPartyId, let userId = self.firebaseAuth.currentUserId else {
            print("Not signed in or not member of party so can't leave party")
            return
        }
        
        do {
            try await self.firestore.leaveParty(partyId: partyId, userId: userId)
            self.firebaseState.setCurrentPartyId(nil)
            self.stopListeningToParty()
            self.stopListeningToMembers()
            
            return
        } catch FirestoreServiceError.memberNotFound {
            print("Failed to leave Party: \(FirestoreServiceError.memberNotFound.localizedDescription)")
            ToastMessageUtility.show(message: .init(text: "Kein Party-Teilnehmer", style: .error))
        } catch {
            print("Failed to leave Party: \(error)")
        }
        
        //TODO: Weitermachen
    }
    
    public func onPartyChanged(partyId: String?) {
        if let partyId = partyId {
            self.startListeningToParty()
            self.startListeningToMembers()
        }
        else {
            self.stopListeningToParty()
            self.stopListeningToMembers()
        }
    }
    
    public func startListeningToParty() {
        guard let partyId = self.firebaseState.currentPartyId else {
            return
        }
        
        self.partyCancellable = self.firestore
            .listenToParty(id: partyId)
            .sink(receiveCompletion: { [weak self] completion in
                guard case .failure(let error) = completion else {
                    return
                }
                
                Task { @MainActor in
                    print("Failed to listen to party: \(error)")
                    self?.party = nil
                    self?.partyCancellable = nil
                }
            }, receiveValue: { [weak self] party in
                Task { @MainActor in
                    self?.party = party
                }
            })
    }
    
    public func stopListeningToParty() {
        self.partyCancellable?.cancel()
        self.partyCancellable = nil
    }
    
    private func restartListeningToParty() {
        self.stopListeningToParty()
        self.startListeningToParty()
    }
    
    public func startListeningToMembers() {
        guard let partyId = self.firebaseState.currentPartyId else {
            return
        }
        
        self.membersCancellable = self.firestore
            .listenToMembers(partyId: partyId)
            .sink(receiveCompletion: { [weak self] completion in
                guard case .failure(let error) = completion else {
                    return
                }
                
                Task { @MainActor in
                    print("Failed to listen to members: \(error)")
                    self?.members = nil
                    self?.membersCancellable = nil
                }
            }, receiveValue: { [weak self] members in
                Task { @MainActor in
                    self?.members = members
                }
            })
    }
    
    public func stopListeningToMembers() {
        self.membersCancellable?.cancel()
        self.membersCancellable = nil
    }
    
    private func restartListeningToMembers() {
        self.stopListeningToMembers()
        self.startListeningToMembers()
    }
}
