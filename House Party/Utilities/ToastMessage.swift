//
//  ToastMessage.swift
//  House Party
//
//  Created by Marcel Schafaczek on 13.08.26.
//

import Foundation

public struct ToastMessage: Equatable {
    public enum MessageType: Equatable {
        case success, error
    }
    
    public let text: String
    public let style: MessageType
    public let duration: TimeInterval
    
    init(text: String, style: MessageType, duration: TimeInterval = 2) {
        self.text = text
        self.style = style
        self.duration = duration
    }
}
