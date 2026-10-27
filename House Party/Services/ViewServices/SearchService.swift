//
//  SearchService.swift
//  House Party
//
//  Created by Marcel Schafaczek on 09.08.26.
//

import Foundation
import Observation
import SpotifyWebAPI

@MainActor
@Observable
public final class SearchService {
    private static let maxSearchLimit: Int = 10
    private static let defaultSearchLimit: Int = 6
    private static let debounceTimeInSeconds: Double = 0.5
    
    private let firebaseAuth: FirebaseAuth
    private let firestore: FirestoreService
    private let firebaseState:  FirebaseState
    private let webAPI: SpotifyWebAPIService
    
    public private(set) var isLoading: Bool = false
    public private(set) var searchResult: SearchResult? = nil
    public let availableSearchScopes: [ContentCategory] = SpotifyConstants.availableSearchScopes
    
    @ObservationIgnored
    private var searchTask: Task<Void, Never>? = nil
    
    public init(
        firebaseAuth: FirebaseAuth,
        firestore: FirestoreService,
        firebaseState: FirebaseState,
        webAPI: SpotifyWebAPIService
    ) {
        self.firebaseAuth = firebaseAuth
        self.firestore = firestore
        self.firebaseState = firebaseState
        self.webAPI = webAPI
    }
    
    public func search(query: String, selectedSearchScopes: [ContentCategory], debounce: Bool) {
        self.searchTask?.cancel()
        self.searchTask = Task { [weak self] in
            guard let self else {
                return
            }
            
            if debounce {
                try? await Task.sleep(nanoseconds: UInt64(Self.debounceTimeInSeconds * Double(NSEC_PER_SEC)))
            }
            
            guard !Task.isCancelled else {
                return
            }
            
            await self.performSearch(query: query, selectedSearchScopes: selectedSearchScopes)
        }
    }
    
    public func loadNextPageOfTracks() async {
        await self.loadNextPage(of: self.searchResult?.tracks) { searchResult, tracks in
            SearchResult(
                artists: searchResult.artists,
                albums: searchResult.albums,
                tracks: tracks,
                playlists: searchResult.playlists,
                episodes: searchResult.episodes,
                shows: searchResult.shows,
                audiobooks: searchResult.audiobooks
            )
        }
    }
    
    public func loadNextPageOfPlaylists() async {
        await self.loadNextPage(of: self.searchResult?.playlists) { searchResult, playlists in
            SearchResult(
                artists: searchResult.artists,
                albums: searchResult.albums,
                tracks: searchResult.tracks,
                playlists: playlists,
                episodes: searchResult.episodes,
                shows: searchResult.shows,
                audiobooks: searchResult.audiobooks
            )
        }
    }
    
    public func loadNextPageOfAlbums() async {
        await self.loadNextPage(of: self.searchResult?.albums) { searchResult, albums in
            SearchResult(
                artists: searchResult.artists,
                albums: albums,
                tracks: searchResult.tracks,
                playlists: searchResult.playlists,
                episodes: searchResult.episodes,
                shows: searchResult.shows,
                audiobooks: searchResult.audiobooks
            )
        }
    }
    
    public func loadNextPageOfArtists() async {
        await self.loadNextPage(of: self.searchResult?.artists) { searchResult, artists in
            SearchResult(
                artists: artists,
                albums: searchResult.albums,
                tracks: searchResult.tracks,
                playlists: searchResult.playlists,
                episodes: searchResult.episodes,
                shows: searchResult.shows,
                audiobooks: searchResult.audiobooks
            )
        }
    }
    
    private func performSearch(query: String, selectedSearchScopes: [ContentCategory]) async {
        self.isLoading = true
        defer { self.isLoading = false }
        
        do {
            self.searchResult = try await self.webAPI.search(
                query: query,
                categories: selectedSearchScopes,
                limit: selectedSearchScopes.count == 1 ? Self.maxSearchLimit : Self.defaultSearchLimit
            )
        } catch {
            print("Failed to perform search: \(error)")
        }
    }
    
    private func loadNextPage<Item: Codable & Hashable>(
        of pagingObject: PagingObject<Item>?,
        updatingSearchResult: @escaping (SearchResult, PagingObject<Item>) -> SearchResult
    ) async {
        guard let pagingObject, let next = pagingObject.next else {
            return
        }
        
        do {
            let nextPage = try await self.webAPI.getNextPage(href: next, innerResponseType: Item.self)
            let mergedPage = Self.mergedPage(currentPage: pagingObject, nextPage: nextPage)
            
            guard let searchResult = self.searchResult else {
                return
            }
            
            self.searchResult = updatingSearchResult(searchResult, mergedPage)
        } catch {
            print("Failed to load next page: \(error)")
        }
    }
    
    private static func mergedPage<Item: Codable & Hashable>(
        currentPage: PagingObject<Item>,
        nextPage: PagingObject<Item>
    ) -> PagingObject<Item> {
        PagingObject(
            href: currentPage.href,
            items: currentPage.items + nextPage.items,
            limit: nextPage.limit,
            next: nextPage.next,
            previous: currentPage.previous,
            offset: currentPage.offset,
            total: nextPage.total
        )
    }
}
