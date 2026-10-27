//
//  QueueItemView.swift
//  House Party
//
//  Created by Marcel Schafaczek on 14.08.26.
//

import SwiftUI
import SpotifyWebAPI

struct QueueItemView: View {
    let item: QueueItem
    let coverImageSize: CGSize
    
    @Environment(QueueService.self)
    private var queueService: QueueService
    
    private var didVote: Bool {
        self.userVoteDirection != nil
    }
    
    private var userVoteDirection: VoteDirection? {
        self.item.id.flatMap { self.queueService.userVoteDirections[$0] }
    }
    
    init(
        item: QueueItem,
        coverImageSize: CGSize = UIConstants.coverImageSizeMedium,
    ) {
        self.item = item
        self.coverImageSize = coverImageSize
    }
    
    var body: some View {
        HStack {
            RemoteImage(url: self.item.track.album?.images?.first?.url, size: self.coverImageSize)
                
            VStack(alignment: .leading) {
                Text(self.item.track.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    
                if let artists = self.item.track.artists?.map({ $0.name }).joined(separator: ", ") {
                    Text(artists)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            }
            .lineLimit(1)
            .truncationMode(.tail)
            
            VStack {
                self.createVoteButton(direction: .up)
                
                Text("\(self.item.score)")
                    .font(.title3)
                    .foregroundStyle(.white)
                
                self.createVoteButton(direction: .down)
            }
        }
        .listRowSeparator(.hidden)
        .onAppear {
            self.startListeningToVotes()
        }
        .onDisappear{
            self.stopListeningToVotes()
        }
    }
    
    private func createVoteButton(direction: VoteDirection) -> some View {
        Button {
            self.vote(direction: direction)
        } label: {
            Image(systemName: direction == .up ? "chevron.up" : "chevron.down")
                .foregroundStyle(self.userVoteDirection == direction ? .white : .gray)
                .font(.system(size: 25, weight: .medium))
        }
        .buttonStyle(.plain)
        .disabled(self.didVote)
    }
    
    private func vote(direction: VoteDirection) {
        guard let queueItemId = self.item.id else {
            return
        }
        
        Task {
            await self.queueService.vote(direction: direction, queueItemId: queueItemId)
        }
    }
    
    private func startListeningToVotes() {
        guard let itemId = self.item.id else {
            print("QueueItemID is nil and so can't listen to its votes.")
            return
        }
        
        self.queueService.startListeningToVotes(queueItemId: itemId)
    }
    
    private func stopListeningToVotes() {
        guard let itemId = self.item.id else {
            print("QueueItemID is nil and so can't listen to its votes.")
            return
        }
        
        self.queueService.stopListeningToVotes(queueItemId: itemId)
    }
}
