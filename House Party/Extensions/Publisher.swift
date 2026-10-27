//
//  Publisher.swift
//  House Party
//
//  Created by Marcel Schafaczek on 03.08.26.
//

import Foundation
import Combine

public enum PublisherError: Error {
    case noResponseOrCancelled
}

extension Publisher where Failure == Error {
    public func firstResponse() async throws -> Output {        
        var iterator = self.values.makeAsyncIterator()
        
        guard let output = try await iterator.next() else {
            throw PublisherError.noResponseOrCancelled
        }
        
        return output
    }
}
