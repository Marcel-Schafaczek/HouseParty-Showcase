//
//  AppRemoteService.swift
//  House Party
//
//  Created by Marcel Schafaczek on 22.07.26.
//

import Foundation
import Observation
import SpotifyiOS
import UIKit
import SpotifyWebAPI

@Observable
public final class AppRemoteService: NSObject {
    private struct Timing {
        static let accessTokenRenewalThreshold: TimeInterval = 5 * 60
        static let playbackProgressUpdateInterval: TimeInterval = 1
        static let queueNewTrackThreshold: TimeInterval = 10
    }
    
    public var addNextTrackToQueueCallback: (() async -> Void)? = nil
    public var archiveTracksUntilNextPlayableCallback: (() async -> Void)? = nil
    
    public private(set) var isPlaying = false
    /// Current track progress from 0.0 to 1.0.
    public private(set) var playbackProgress: Double = 0
    public private(set) var currentTrackImage: UIImage? = nil
    
    public var hasCurrentTrack: Bool {
        return self.currentTrack != nil
    }
    
    public var currentTrackTitle: String? {
        self.currentTrack?.name
    }
    
    public var currentTrackArtitsts: String? {
        self.currentTrack?.artist.name
    }
    
    public var currentTrackURI: String? {
        self.currentTrack?.uri
    }
    
    public var isConnected: Bool {
        self.appRemote.isConnected
    }
    
    private var currentTrack: SPTAppRemoteTrack? = nil
    
    private let appRemote: SPTAppRemote

    @ObservationIgnored
    private let spotifyAuth: SpotifyAuth
    @ObservationIgnored
    private var playbackProgressTimer: Timer?
    @ObservationIgnored
    private var lastKnownPlaybackPosition: TimeInterval = 0
    @ObservationIgnored
    private var lastPlayerStateUpdateDate: Date?
    @ObservationIgnored
    private var pendingPlaybackURI: String?
    @ObservationIgnored
    private var shouldResumeWhenConnected = false
    @ObservationIgnored
    private var shouldWakeSpotifyAppOnConnectionFailure = false
    
    @ObservationIgnored
    private var currentTrackDuration: TimeInterval {
        return TimeInterval(self.currentTrack?.duration ?? 0)
    }

    public init(auth: SpotifyAuth) {
        let configuration = SPTConfiguration(
            clientID: SpotifyConstants.spotifyClientID,
            redirectURL: SpotifyConstants.redirectURL
        )
        self.appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        self.spotifyAuth = auth
        super.init()
        
        self.appRemote.delegate = self
        self.handleAuthorizationChange(isAuthorized: self.spotifyAuth.isAuthorized)
        self.observeAuthorizationChanges()
    }
    
    deinit {
        self.invalidateTimers()
    }
    
    public func onHandleCallback(url: URL) {
        let result = self.appRemote.authorizationParameters(from: url)
        if let error = result?[SPTAppRemoteErrorDescriptionKey] {
            print("Error handling Spotifys callback: \(error)")
        }
        
        // Don't pass access token from result to appRemote, beauce it should always have a valid access token,
        // since it is handled in the WebAPI.
        // We only use the authorizeAndPlay mehtod to wake up the spotify app!
        
        self.connect()
    }
    
    public func connect() {
        guard self.spotifyAuth.isAuthorized, !self.isConnected else {
            return
        }
        
        Task {
            await self.refreshAcessTokenIfNeeded()
            
            self.appRemote.connect()
        }
    }
    
    @MainActor
    public func disconnect() {
        self.stopPlaybackProgressTimer()
        
        if self.appRemote.isConnected {
            self.appRemote.disconnect()
        }
    }
    
    @MainActor
    public func play(switchToTrack uri: String? = nil) async {
        guard self.spotifyAuth.isAuthorized else {
            return
        }
            
        await self.refreshAcessTokenIfNeeded()
            
        if self.isConnected {
            self.performPlaybackRequest(uri: uri)
            return
        }
            
        self.pendingPlaybackURI = uri
        self.shouldResumeWhenConnected = uri == nil
        self.shouldWakeSpotifyAppOnConnectionFailure = true
        self.connect()
    }
    
    @MainActor
    public func pause() {
        guard self.isConnected else {
            return
        }
        
        self.appRemote.playerAPI?.pause { _, error in
            if let error {
                print("Unable to pause playback: \(error)")
            }
        }
    }
    
    public func togglePlaybackState() {
        if self.isPlaying {
            self.pause()
        }
        else {
            Task {
                await self.play()
            }
        }
    }
    
    public func fetchImageOfTrack(withURI uri: String, size: CGSize) async -> UIImage? {
        guard let imageRepresentable = await self.fetchContentItem(uri: uri) else {
            return nil
        }
        
        return await self.fetchImageOfTrack(imageRepresentable, size: size)
    }
    
    public func fetchImageOfTrack(_ imageRepresentable: SPTAppRemoteImageRepresentable, size: CGSize) async -> UIImage? {
        guard let imageAPI = self.appRemote.imageAPI else {
            print("Error: ImageAPI is nil")
            return nil
        }
                
        return await withCheckedContinuation { continuation in
            imageAPI.fetchImage(forItem: imageRepresentable, with: size) { result, error in
                if let error {
                    print("Failed to fetch image: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                let uiImage = result as? UIImage
                if uiImage == nil {
                    print("Failed to fetch image: result is no UIImage")
                }
                
                continuation.resume(returning: uiImage)
            }
        }
    }
    
    private func refreshAcessTokenIfNeeded() async {
        do {
            try await self.spotifyAuth.refreshAccessTokenIfNeeded()
        }
        catch {
            print("Unable to refresh Spotify access token before playback: \(error)")
            return
        }
            
        self.updateAccessToken()
    }
    
    @MainActor
    private func updatePlaybackState(_ playerState: SPTAppRemotePlayerState) async {
        self.isPlaying = !playerState.isPaused
        
        let oldTrack = self.currentTrack
        self.currentTrack = playerState.track
        
        self.lastKnownPlaybackPosition = TimeInterval(playerState.playbackPosition)
        self.lastPlayerStateUpdateDate = Date()
        self.updatePlaybackProgress(position: self.lastKnownPlaybackPosition)
        
        if self.isPlaying {
            self.startPlaybackProgressTimer()
        }
        else {
            self.stopPlaybackProgressTimer()
        }
        
        if let newTrack = self.currentTrack, oldTrack?.uri != newTrack.uri {
            // Track changed
            self.currentTrackImage = await self.fetchImageOfCurrentTrack(size: UIConstants.coverImageBestResolution)
            await self.archiveTracksUntilNextPlayableCallback?()
        }
    }

    private func observeAuthorizationChanges() {
        withObservationTracking {
            _ = self.spotifyAuth.isAuthorized
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.handleAuthorizationChange(isAuthorized: self.spotifyAuth.isAuthorized)
                self.observeAuthorizationChanges()
            }
        }
    }

    private func handleAuthorizationChange(isAuthorized: Bool) {
        if isAuthorized {
            self.connect()
        }
        else {
            self.disconnect()
            self.appRemote.connectionParameters.accessToken = nil
        }
    }
    
    private func wakeSpotifyAppForPlayback(uri: String?) {
        let playURI = uri ?? ""
        self.appRemote.authorizeAndPlayURI(playURI) { success in
            if !success {
                print("Unable to open Spotify app for playback.")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.updateAccessToken()
                self?.connect()
            }
        }
    }
    
    private func updateAccessToken() {
        self.appRemote.connectionParameters.accessToken = self.spotifyAuth.accessToken
    }
    
    private func performPendingPlaybackRequest() {
        if let pendingPlaybackURI {
            self.pendingPlaybackURI = nil
            self.shouldResumeWhenConnected = false
            self.performPlaybackRequest(uri: pendingPlaybackURI)
        }
        else if self.shouldResumeWhenConnected {
            self.shouldResumeWhenConnected = false
            self.performPlaybackRequest(uri: nil)
        }
    }
    
    private func performPlaybackRequest(uri: String?) {
        if let uri {
            self.appRemote.playerAPI?.play(uri) { _, error in
                if let error {
                    print("Unable to play track \(uri): \(error)")
                }
            }
        }
        else {
            self.appRemote.playerAPI?.resume { _, error in
                if let error {
                    print("Unable to resume playback: \(error)")
                }
            }
        }
    }
    
    private func updatePlaybackProgress(position: TimeInterval) {
        guard self.currentTrackDuration > 0 else {
            self.playbackProgress = 0
            return
        }
        
        let progress = position / self.currentTrackDuration
        self.playbackProgress = min(max(progress, 0), 1)
        
        self.addNextTrackToQueueIfNeccessary(position: position)
    }
    
    private func addNextTrackToQueueIfNeccessary(position: TimeInterval) {
        let remainingDuration = (self.currentTrackDuration - position) / 1000
        guard remainingDuration < Timing.queueNewTrackThreshold else {
            return
        }
        
        Task {
            await self.addNextTrackToQueueCallback?()
        }
    }
    
    private func startPlaybackProgressTimer() {
        guard self.playbackProgressTimer == nil else {
            return
        }
        
        let timer = Timer(timeInterval: Timing.playbackProgressUpdateInterval, repeats: true) { [weak self] _ in
            self?.updatePlaybackProgressFromElapsedTime()
        }
        self.playbackProgressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func stopPlaybackProgressTimer() {
        self.playbackProgressTimer?.invalidate()
        self.playbackProgressTimer = nil
    }
    
    private func updatePlaybackProgressFromElapsedTime() {
        guard
            self.isPlaying,
            let lastPlayerStateUpdateDate
        else {
            return
        }
        
        let elapsedMilliseconds = Date().timeIntervalSince(lastPlayerStateUpdateDate) * 1000
        self.updatePlaybackProgress(position: self.lastKnownPlaybackPosition + elapsedMilliseconds)
    }
    
    private func invalidateTimers() {
        self.stopPlaybackProgressTimer()
    }
    
    private func fetchImageOfCurrentTrack(size: CGSize) async -> UIImage? {
        guard let currentItem = self.currentTrack else {
            print("No current track")
            return nil
        }
        
        return await self.fetchImageOfTrack(currentItem, size: size)
    }
    
    private func fetchContentItem(uri: String) async -> SPTAppRemoteContentItem? {
        guard let contentAPI = self.appRemote.contentAPI else {
            print("Error: ContentAPI is nil")
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            contentAPI.fetchContentItem(forURI: uri) { result, error in
                if let error {
                    print("Failed to load content item: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                let contentItem = result as? SPTAppRemoteContentItem
                if contentItem == nil {
                    print("Failed to fetch content: result is no SPTAppRemoteContentItem")
                }
                
                continuation.resume(returning: contentItem)
            }
        }
    }
}

extension AppRemoteService: SPTAppRemoteDelegate {
    public func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("Did establish connection")
                
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { _, error in
            if let error {
                print("Error subscribing to player state: \(error)")
                return
            }
        })
        self.performPendingPlaybackRequest()
    }
    
    public func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("Failed to connect App Remote: \(String(describing: error))")
        
        guard self.shouldWakeSpotifyAppOnConnectionFailure else {
            return
        }
        
        self.shouldWakeSpotifyAppOnConnectionFailure = false
        self.wakeSpotifyAppForPlayback(uri: self.pendingPlaybackURI)
    }
    
    public func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        self.isPlaying = false
        self.stopPlaybackProgressTimer()
        
        self.currentTrack = nil
        self.currentTrackImage = nil
    }
}

extension AppRemoteService: SPTAppRemotePlayerStateDelegate {
    public func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        Task {
            await self.updatePlaybackState(playerState)
            await self.refreshAcessTokenIfNeeded()
        }
    }
}
