//
//  CGFloat.swift
//  House Party
//
//  Created by Marcel Schafaczek on 26.08.26.
//

import Foundation

extension CGFloat {
    public func toSquareSize() -> CGSize {
        return .init(width: self, height: self)
    }
}
