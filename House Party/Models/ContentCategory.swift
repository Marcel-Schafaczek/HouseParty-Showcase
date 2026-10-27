//
//  ContentCategory.swift
//  House Party
//
//  Created by Marcel Schafaczek on 06.08.26.
//

import Foundation
import SpotifyWebAPI

public struct ContentCategory: Identifiable, Hashable {
    public var id: IDCategory.RawValue {
        self.spotifyValue.rawValue
    }
    public let spotifyValue: IDCategory
    public let displayValue: String
}

extension [ContentCategory] {
    public func allSpotifyValues() -> [IDCategory] {
        self.map(\.spotifyValue)
    }
}
