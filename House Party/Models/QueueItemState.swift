//
//  QueueItemState.swift
//  House Party
//
//  Created by Marcel Schafaczek on 01.09.26.
//


import Foundation

public enum QueueItemState: String, Codable, CaseIterable {
    case queuedFirebase
    case willBeSkipped
    case queuedSpotify
    case playing
    case played
    case wasSkipped
    
    public static var isInQueueStates: [QueueItemState] {
        return self.allCases.filter{ $0.isInQueue }
    }
    
    public static var isDoneStates: [QueueItemState] {
        return self.allCases.filter{ !$0.isDone }
    }
    
    public var isInQueue: Bool {
        return self.isPlayableAndInQueue || self == .willBeSkipped
    }
    
    public var isPlayableAndInQueue: Bool {
        return self == .queuedFirebase || self == .queuedSpotify
    }
    
    public var isDone: Bool {
        return self == .played || self == .wasSkipped
    }
    
    public var nextState: QueueItemState? {
        switch self {
            case .queuedFirebase:
                return .queuedSpotify
            case .willBeSkipped:
                return .wasSkipped
            case .queuedSpotify:
                return .playing
            case .playing:
                return .played
            case .played, .wasSkipped:
                return nil
        }
    }
    
    public var doneState: QueueItemState? {
        switch self {
            case .willBeSkipped:
                return .wasSkipped
            case .playing:
                return .played
            case .queuedFirebase, .queuedSpotify, .played, .wasSkipped:
                return nil
        }
    }
}

extension Array<QueueItemState> {
    public var rawValues: [String] {
        return self.map{ $0.rawValue }
    }
}
