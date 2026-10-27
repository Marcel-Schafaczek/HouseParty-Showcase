//
//  SpotifyWebAPIService.swift
//  House Party
//
//  Created by Marcel Schafaczek on 24.07.26.
//

import Foundation
import SpotifyWebAPI
import Combine

public final class SpotifyWebAPIService {    
    private let spotifyAPI: SpotifyAPI<AuthorizationCodeFlowPKCEManager>
    private let spotifyAuth: SpotifyAuth
    
    public init(api: SpotifyAPI<AuthorizationCodeFlowPKCEManager>, auth: SpotifyAuth) {
        self.spotifyAPI = api
        self.spotifyAuth = auth
    }
    
    // MARK: - Player
    
    public func getQueue() async throws -> SpotifyQueue {
        try await self.spotifyAuth.refreshAccessTokenIfNeeded()
        
        let hasActiveDevice = try? await self.getHasActiveDevice()
        guard hasActiveDevice == true else {
            throw WebAPIError.noActiveDevice
        }
        
        return try await self.spotifyAPI.queue()
            .map { queue in
                let currentlyPlaying = queue.currentlyPlaying.flatMap { item -> Track? in
                    guard case .track(let item) = item else {
                        return nil
                    }
                    
                    return item
                }
                
                let queue: [Track] = queue.queue.compactMap { item in
                    guard case .track(let item) = item else {
                        return nil
                    }
                    
                    return item
                }
                
                return SpotifyQueue(currentlyPlaying: currentlyPlaying, queue: queue)
            }
            .firstResponse()
    }
    
    public func addTrackToQueue(trackUri: String, deviceId: String? = nil) async  throws {
        try await self.spotifyAuth.refreshAccessTokenIfNeeded()
        
        try await self.spotifyAPI.addToQueue(trackUri, deviceId: deviceId).firstResponse()
    }
    
    public func getHasActiveDevice() async throws -> Bool {
        return try await self.getUsableDevices().contains{ $0.isActive }
    }
    
    public func getHasUsableDevice() async throws -> Bool {
        let devices = try await self.getUsableDevices()
        return !devices.isEmpty
    }
    
    public func getUsableDevices() async throws -> [Device] {
        try await self.spotifyAuth.refreshAccessTokenIfNeeded()
        
        return try await self.spotifyAPI
            .availableDevices()
            .firstResponse()
            .filter{ !$0.isRestricted && $0.id != nil }
    }
    
    public func getAvailableDevices() async throws -> [Device] {
        try await self.spotifyAuth.refreshAccessTokenIfNeeded()
        
        return try await self.spotifyAPI.availableDevices().firstResponse()
    }
    
    // MARK: - Search
    
    public func search(query: String, category: ContentCategory?, limit: Int? = nil, offset: Int? = nil) async throws -> SearchResult {
        let selectedOrAllAvailableCategories = category != nil ? [category!] : SpotifyConstants.availableSearchScopes
        
        return try await self.search(
            query: query,
            categories: selectedOrAllAvailableCategories,
            limit: limit,
            offset: offset
        )
    }
    
    public func search(query: String, categories: [ContentCategory], limit: Int? = nil, offset: Int? = nil) async throws -> SearchResult {
        guard !query.isEmpty else {
            return .empty
        }
        
        try await self.spotifyAuth.refreshAccessTokenIfNeeded()
        
        let selectedOrAllAvailableCategories = categories.isEmpty ? SpotifyConstants.availableSearchScopes : categories
        return try await self.spotifyAPI
            .search(
                query: query,
                categories: selectedOrAllAvailableCategories.allSpotifyValues(),
                market: "from_token",
                limit: limit,
                offset: offset
            )
            .firstResponse()
    }
    
    // MARK: - Pagination
    
    public func getNextPage<Item: Codable & Hashable>(href: URL, innerResponseType: Item.Type) async throws -> PagingObject<Item> {
        try await self.spotifyAuth.refreshAccessTokenIfNeeded()
        
        return try await self.spotifyAPI
            .getFromHref(href, responseType: PagingObject<Item>.self)
            .firstResponse()
    }
}
