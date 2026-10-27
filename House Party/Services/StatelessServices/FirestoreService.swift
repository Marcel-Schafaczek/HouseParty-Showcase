//
//  FirestoreService.swift
//  House Party
//
//  Created by Marcel Schafaczek on 13.08.26.
//

import Foundation
import Combine
import FirebaseFirestore
import SpotifyWebAPI

public final class FirestoreService {
    private lazy var db = Firestore.firestore()
    
    private enum Collection {
        static let parties = "parties"
        static let members = "members"
        static let queue = "queue"
        static let votes = "votes"
    }
    
    private enum ListenerKey: Hashable {
        case party(id: String)
        case members(partyId: String)
        case currentlyPlaying(partyId: String)
        case queue(partyId: String)
        case votes(partyId: String, queueItemId: String)
    }
    
    private var listeners: [ListenerKey: ListenerRegistration] = [:]
    
    // MARK: - Parties
    
    public func createParty(name: String, hostUserId: String, hostDisplayName: String) async throws -> Party {
        let party = Party(
            id: nil,
            name: name,
            hostUserId: hostUserId,
            joinCode: Self.makeJoinCode(),
            createdAt: Date(),
            status: .active
        )
        
        let partyReference = try self.partiesCollection.addDocument(from: party)
        let host = PartyMember(
            id: nil,
            displayName: hostDisplayName,
            joinedAt: Date(),
            role: .host
        )
        
        try partyReference
            .collection(Collection.members)
            .document(hostUserId)
            .setData(from: host)
        
        return try await partyReference.getDocument(as: Party.self)
    }
    
    public func getParty(id: String) async throws -> Party {
        return try await self.partyDocument(id).getDocument(as: Party.self)
    }
    
    public func getActiveParty(joinCode: String) async throws -> Party? {
        return try await self.partiesCollection
            .whereField(Party.CodingKeys.joinCode.rawValue, isEqualTo: joinCode.uppercased())
            .whereField(Party.CodingKeys.status.rawValue, isEqualTo: PartyStatus.active.rawValue)
            .limit(to: 1)
            .getDocuments(as: Party.self)
            .first
    }
    
    @discardableResult
    public func joinParty(id: String, userId: String, displayName: String) async throws -> PartyMember {
        let member = PartyMember(
            id: userId,
            displayName: displayName,
            joinedAt: Date(),
            role: .guest
        )
        
        let memberReference = try self.membersCollection(partyId: id).addDocument(from: member)
        
        return try await memberReference.getDocument(as: PartyMember.self)
    }
    
    public func leaveParty(partyId: String, userId: String) async throws {
        guard let member = try await self.membersCollection(partyId: partyId)
            .whereField(PartyMember.CodingKeys.id.rawValue, isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
            .documents
            .first
        else {
            throw FirestoreServiceError.memberNotFound
        }
        
        try await member.reference.delete()
    }
    
    public func finishParty(id: String) async throws {
        try await self.partyDocument(id).updateData([
            Party.CodingKeys.status.rawValue: PartyStatus.finished.rawValue
        ])
    }
    
    public func listenToParty(id: String) -> AnyPublisher<Party, Error> {
        let listenerKey = ListenerKey.party(id: id)
        let listenerResult = self.partyDocument(id).addSnapshotListener(as: Party.self)
        
        self.store(listenerResult.listener, for: listenerKey)
        
        return listenerResult.publisher
            .tryMap { party in
                guard let party else {
                    throw FirestoreServiceError.partyNotFound
                }
                
                return party
            }
            .eraseToAnyPublisher()
    }
    
    public func stopListeningToParty(id: String) {
        self.stopListening(for: .party(id: id))
    }
    
    // MARK: - Members
    
    public func getMembers(partyId: String) async throws -> [PartyMember] {
        return try await self.membersCollection(partyId: partyId)
            .order(by: PartyMember.CodingKeys.joinedAt.rawValue)
            .getDocuments(as: PartyMember.self)
    }
    
    public func listenToMembers(partyId: String) -> AnyPublisher<[PartyMember], Error> {
        let listenerKey = ListenerKey.members(partyId: partyId)
        let listenerResult = self.membersCollection(partyId: partyId)
            .order(by: PartyMember.CodingKeys.joinedAt.rawValue)
            .addSnapshotListener(as: PartyMember.self)
        
        self.store(listenerResult.listener, for: listenerKey)
        
        return listenerResult.publisher
    }
    
    public func stopListeningToMembers(partyId: String) {
        self.stopListening(for: .members(partyId: partyId))
    }
    
    // MARK: - Queue
    
    public func addTrackToQueue(partyId: String, track: Track, addedBy userId: String) async throws {
        guard let trackId = track.id else {
            throw FirestoreServiceError.missingTrackId
        }
        
        let existingQueueItems = try await self.queueCollection(partyId: partyId)
            .whereField(
                "\(QueueItem.CodingKeys.track.rawValue).id",
                isEqualTo: trackId
            )
            .whereField(
                QueueItem.CodingKeys.state.rawValue,
                in: QueueItemState.isInQueueStates.rawValues
            )
            .limit(to: 1)
            .getDocuments()
        
        guard existingQueueItems.documents.isEmpty else {
            throw FirestoreServiceError.trackAlreadyQueued
        }
        
        let queueItem = QueueItem(
            id: nil,
            track: track,
            addedBy: userId,
            addedAt: Date(),
            upVotes: 0,
            downVotes: 0,
            score: 0,
            state: .queuedFirebase
        )
        
        try self.queueCollection(partyId: partyId).addDocument(from: queueItem)
    }
    
    public func getQueue(partyId: String, includeAchived: Bool = false) async throws -> [QueueItem] {
        return try await self.getQueueQuery(partyId: partyId, includeAchived: includeAchived)
            .getDocuments(as: QueueItem.self)
    }
    
    public func listenToQueue(partyId: String, includeAchived: Bool = false) -> AnyPublisher<[QueueItem], Error> {
        let listenerKey = ListenerKey.queue(partyId: partyId)
        let listenerResult = self.getQueueQuery(partyId: partyId, includeAchived: includeAchived)
            .addSnapshotListener(as: QueueItem.self)
        
        self.store(listenerResult.listener, for: listenerKey)
        
        return listenerResult.publisher
    }
    
    public func stopListeningToQueue(partyId: String) {
        self.stopListening(for: .queue(partyId: partyId))
    }
    
    public func updateQueueItemState(partyId: String, queueItemId: String, state: QueueItemState) async throws {
        try await queueItemDocument(partyId: partyId, queueItemId: queueItemId).updateData([
            QueueItem.CodingKeys.state.rawValue: state.rawValue
        ])
    }
    
    public func removeQueueItem(partyId: String, queueItemId: String) async throws {
        try await queueItemDocument(partyId: partyId, queueItemId: queueItemId).delete()
    }
    
    private func getQueueQuery(partyId: String, includeAchived: Bool) -> Query {
        return self.queueCollection(partyId: partyId)
            .whereField(
                QueueItem.CodingKeys.state.rawValue,
                notIn: QueueItemState.isDoneStates.rawValues
            )
            .order(by: QueueItem.CodingKeys.score.rawValue, descending: true)
            .order(by: QueueItem.CodingKeys.addedAt.rawValue)
    }
    
    // MARK: - Votes
    
    func vote(partyId: String, queueItemId: String, userId: String, direction: VoteDirection) async throws {
        let queueItemReference = self.queueItemDocument(partyId: partyId, queueItemId: queueItemId)
        let voteReference = queueItemReference
            .collection(Collection.votes)
            .document(userId)
        
        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let queueItemSnapshot = try transaction.getDocument(queueItemReference)
                guard let queueItem = try? queueItemSnapshot.data(as: QueueItem.self) else {
                    throw FirestoreServiceError.queueItemNotFound
                }
                
                let voteSnapshot = try transaction.getDocument(voteReference)
                let previousDirection = try voteSnapshot.exists ? voteSnapshot.data(
                    as: TrackVote.self
                ).direction : nil
                
                let voteDeltas = Self.voteDeltas(from: previousDirection, to: direction)
                let vote = TrackVote(id: nil, direction: direction, createdAt: Date())
                let encodedVote = try Firestore.Encoder().encode(vote)
                
                transaction.setData(encodedVote, forDocument: voteReference)
                transaction.updateData([
                    QueueItem.CodingKeys.upVotes.rawValue: queueItem.upVotes + voteDeltas.upVotes,
                    QueueItem.CodingKeys.downVotes.rawValue: queueItem.downVotes + voteDeltas.downVotes,
                    QueueItem.CodingKeys.score.rawValue: queueItem.score + voteDeltas.score
                ], forDocument: queueItemReference)
                
                return nil
            }
            catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    public func removeVote(partyId: String, queueItemId: String, userId: String) async throws {
        let queueItemReference = queueItemDocument(partyId: partyId, queueItemId: queueItemId)
        let voteReference = queueItemReference
            .collection(Collection.votes)
            .document(userId)
        
        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let queueItemSnapshot = try transaction.getDocument(queueItemReference)
                guard let queueItem = try? queueItemSnapshot.data(as: QueueItem.self) else {
                    throw FirestoreServiceError.queueItemNotFound
                }
                
                let voteSnapshot = try transaction.getDocument(voteReference)
                guard voteSnapshot.exists else {
                    return nil
                }
                
                let vote = try voteSnapshot.data(as: TrackVote.self)
                let voteDeltas = Self.voteDeltas(from: vote.direction, to: nil)
                
                transaction.deleteDocument(voteReference)
                transaction.updateData([
                    QueueItem.CodingKeys.upVotes.rawValue: queueItem.upVotes + voteDeltas.upVotes,
                    QueueItem.CodingKeys.downVotes.rawValue: queueItem.downVotes + voteDeltas.downVotes,
                    QueueItem.CodingKeys.score.rawValue: queueItem.score + voteDeltas.score
                ], forDocument: queueItemReference)
                
                return nil
            }
            catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    public func listenToVotes(partyId: String, queueItemId: String) -> AnyPublisher<[TrackVote], Error> {
        let listenerKey = ListenerKey.votes(partyId: partyId, queueItemId: queueItemId)
        let listenerResult = self.queueItemDocument(partyId: partyId, queueItemId: queueItemId)
            .collection(Collection.votes)
            .addSnapshotListener(as: TrackVote.self)
        
        self.store(listenerResult.listener, for: listenerKey)
        
        return listenerResult.publisher
    }
    
    public func stopListeningToVotes(partyId: String, queueItemId: String) {
        return self.stopListening(for: .votes(partyId: partyId, queueItemId: queueItemId))
    }
    
    // MARK: - References
    
    private var partiesCollection: CollectionReference {
        return self.db.collection(Collection.parties)
    }
    
    private func partyDocument(_ partyId: String) -> DocumentReference {
        return self.partiesCollection.document(partyId)
    }
    
    private func membersCollection(partyId: String) -> CollectionReference {
        return self.partyDocument(partyId).collection(Collection.members)
    }
    
    private func queueCollection(partyId: String) -> CollectionReference {
        return self.partyDocument(partyId).collection(Collection.queue)
    }
    
    private func queueItemDocument(partyId: String, queueItemId: String) -> DocumentReference {
        return self.queueCollection(partyId: partyId).document(queueItemId)
    }
    
    // MARK: - Helpers
    
    public func stopAllListeners() {
        self.listeners.values.forEach { $0.remove() }
        self.listeners.removeAll()
    }
    
    private func store(_ listener: ListenerRegistration, for key: ListenerKey) {
        self.stopListening(for: key)
        self.listeners[key] = listener
    }
    
    private func stopListening(for key: ListenerKey) {
        self.listeners[key]?.remove()
        self.listeners[key] = nil
    }
    
    private static func voteDeltas(from oldDirection: VoteDirection?, to newDirection: VoteDirection?) -> (
        upVotes: Int,
        downVotes: Int,
        score: Int
    ) {
        guard oldDirection != newDirection else {
            return (0, 0, 0)
        }
        
        var upVotes = 0
        var downVotes = 0
        var score = 0
        
        switch oldDirection {
        case .up:
            upVotes -= 1
            score -= 1
        case .down:
            downVotes -= 1
            score += 1
        case nil:
            break
        }
        
        switch newDirection {
        case .up:
            upVotes += 1
            score += 1
        case .down:
            downVotes += 1
            score -= 1
        case nil:
            break
        }
        
        return (upVotes, downVotes, score)
    }
    
    private static func makeJoinCode(length: Int = 10) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890")
        return String((0..<length).compactMap { _ in alphabet.randomElement() })
    }
}

public enum FirestoreServiceError: LocalizedError {
    case partyNotFound
    case memberNotFound
    case queueItemNotFound
    case missingTrackId
    case trackAlreadyQueued
    
    public var errorDescription: String {
        switch self {
            case .partyNotFound:
                return "Party wurde nicht gefunden"
            case .memberNotFound:
                return "Partymitglied wurde nicht gefunden"
            case .queueItemNotFound:
                return "Queue-Eintrag wurde nicht gefunden"
            case .missingTrackId:
                return "Track-ID fehlt"
            case .trackAlreadyQueued:
                return "Song ist bereits in Warteschlange"
        }
    }
}
