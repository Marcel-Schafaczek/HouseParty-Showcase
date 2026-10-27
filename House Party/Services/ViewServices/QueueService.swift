//
//  QueueService.swift
//  House Party
//
//  Created by Marcel Schafaczek on 14.08.26.
//

import Combine
import Foundation
import Observation
import SpotifyWebAPI

@MainActor
@Observable
public final class QueueService {
    private let webAPI: SpotifyWebAPIService
    private let firestore: FirestoreService
    private let firebaseAuth: FirebaseAuth
    private let firebaseState: FirebaseState
    
    public private(set) var firebaseQueue: [QueueItem] = []
    public private(set) var spotifyQueue: SpotifyQueue = .empty
    public private(set) var hasActiveDevice: Bool? = nil
    public private(set) var userVoteDirections: [String: VoteDirection] = [:]
    
    @ObservationIgnored
    private var queueCancellable: AnyCancellable? = nil
    @ObservationIgnored
    private var voteCancellables: [String: AnyCancellable] = [:]
    
    public init(
        firebaseAuth: FirebaseAuth,
        firestore: FirestoreService,
        firebaseState: FirebaseState,
        webAPI: SpotifyWebAPIService
    ) {
        self.webAPI = webAPI
        self.firestore = firestore
        self.firebaseAuth = firebaseAuth
        self.firebaseState = firebaseState
    }
    
    public func loadSpotifyQueue() async {
        do {
            let spotifyQueue = try await self.webAPI.getQueue()
            let trackIdsFromFirebase = self.firebaseQueue.compactMap{ $0.track.id }
            self.spotifyQueue.updateQueue(newQueue: spotifyQueue, trackIdsToIgnore: trackIdsFromFirebase)
        } catch WebAPIError.noActiveDevice {
            print("Keine aktive Spotify Wiedergabe gefunden")
            self.spotifyQueue = .empty
        } catch {
            print(error)
            self.spotifyQueue = .empty
        }
    }
    
    public func addTrackToFirebaseQueue(track: Track) async {
        guard
            let partyId = self.firebaseState.currentPartyId,
            let userId = self.firebaseAuth.currentUserId
        else {
            return
        }
        
        do {
            try await self.firestore.addTrackToQueue(partyId: partyId, track: track, addedBy: userId)
            ToastMessageUtility.show(message: .init(text: "Song hinzugefügt", style: .success))
        } catch (FirestoreServiceError.trackAlreadyQueued) {
            ToastMessageUtility
                .show(message: .init(text: FirestoreServiceError.trackAlreadyQueued.errorDescription, style: .error))
        } catch {
            print(error)
            ToastMessageUtility.show(message: .init(text: "Fehler beim Hinzufügen", style: .error))
        }
    }
    
    public func addNextTrackToSpotifyQueue() async {
        guard
            let partyId = self.firebaseState.currentPartyId,
            let nextQueueItem = self.firebaseQueue.first(where: { $0.state == .queuedFirebase }),
            let nextQueueItemId = nextQueueItem.id,
            let nextTrackId = nextQueueItem.track.id,
            let nextTrackURI = nextQueueItem.track.uri
        else {
            return
        }
                
        do {
            let tracksFromSpotifyQueue = try await self.webAPI.getQueue().queue
            if tracksFromSpotifyQueue.contains(where: { $0.id == nextTrackId }) {
                print("Track is already in spotify queue")
                return
            }
            
            try await self.firestore
                .updateQueueItemState(partyId: partyId, queueItemId: nextQueueItemId, state: .queuedSpotify)
            try await self.webAPI.addTrackToQueue(trackUri: nextTrackURI)
        } catch {
            print("Failed to update item state or add track to spotify queue: \(error)")
            
            do {
                try await self.firestore
                    .updateQueueItemState(partyId: partyId, queueItemId: nextQueueItemId, state: .wasSkipped)
            } catch {
                print("Failed to force set item state to wasSkipped: \(error)")
            }
        }
    }
    
    public func archiveTracksUntilNextPlayableTracks() async {
        let firebaseQueueCopy = self.firebaseQueue
        
        guard
            let partyId = self.firebaseState.currentPartyId,
            let indexOfFirstPlayableTrack = firebaseQueueCopy.firstIndex(where: { $0.state.isPlayableAndInQueue })
        else {
            return
        }
        
        for index in (0..<indexOfFirstPlayableTrack).reversed() {
            let queueItem = firebaseQueueCopy[index]
            guard
                let queueItemId = queueItem.id,
                let doneState = queueItem.state.doneState
            else { continue }
            
            do {
                try await self.firestore
                    .updateQueueItemState(partyId: partyId, queueItemId: queueItemId, state: doneState)
            }
            catch {
                print("Failed to archive queue item: \(error)")
            }
        }
    }
    
    public func clearSpotifyQueue() {
        self.spotifyQueue = .empty
    }
    
    public func vote(direction: VoteDirection, queueItemId: QueueItem.ID) async {
        guard
            let partyId = self.firebaseState.currentPartyId,
            let queueItemId,
            let userId = self.firebaseAuth.currentUserId
        else {
            return
        }
        
        do {
            try await self.firestore.vote(
                partyId: partyId,
                queueItemId: queueItemId,
                userId: userId,
                direction: direction
            )
        } catch {
            print("Failed to vote: \(error)")
        }
    }
    
    public func startListeningToQueue() {
        guard let partyId = self.firebaseState.currentPartyId else {
            return
        }
        
        self.queueCancellable = self.firestore
            .listenToQueue(partyId: partyId)
            .sink(receiveCompletion: { [weak self] completion in
                guard case .failure(let error) = completion else {
                    return
                }
                
                Task { @MainActor in
                    print("Failed to listen to queue: \(error)")
                    self?.queueCancellable = nil
                }
            }, receiveValue: { [weak self] firebaseQueue in
                Task { @MainActor in
                    self?.firebaseQueue = firebaseQueue
                }
            })
    }
    
    public func stopListeningToQueue() {
        self.queueCancellable?.cancel()
        self.queueCancellable = nil
    }
    
    public func startListeningToVotes(queueItemId: String) {
        guard
            let partyId = self.firebaseState.currentPartyId,
            let userId = self.firebaseAuth.currentUserId,
            self.voteCancellables[queueItemId] == nil
        else {
            return
        }
        
        self.voteCancellables[queueItemId] = self.firestore
            .listenToVotes(partyId: partyId, queueItemId: queueItemId)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard case .failure(let error) = completion else {
                        return
                    }
                    
                    Task { @MainActor in
                        print("Failed to listen to votes: \(error)")
                        self?.userVoteDirections[queueItemId] = nil
                        self?.voteCancellables[queueItemId] = nil
                    }
                },
                receiveValue: { [weak self] votes in
                    let userVoteDirection = votes.first { $0.id == userId }?.direction
                    
                    Task { @MainActor in
                        self?.userVoteDirections[queueItemId] = userVoteDirection
                    }
                }
            )
    }
    
    public func stopListeningToVotes(queueItemId: String) {
        guard let partyId = self.firebaseState.currentPartyId else {
            return
        }
        
        self.firestore.stopListeningToVotes(partyId: partyId, queueItemId: queueItemId)
        self.voteCancellables[queueItemId]?.cancel()
        self.voteCancellables[queueItemId] = nil
        self.userVoteDirections[queueItemId] = nil
    }
}
