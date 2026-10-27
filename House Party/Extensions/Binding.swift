//
//  Binding+Bool.swift
//  House Party
//
//  Created by Marcel Schafaczek on 29.07.26.
//

import SwiftUI

public extension Binding where Value == Bool {
    var inverted: Binding<Bool> {
        Binding<Bool>(
            get: { !self.wrappedValue },
            set: { self.wrappedValue = !$0 }
        )
    }
}

public extension Binding where Value == Bool? {
    var invertedIfNotNil: Binding<Bool?> {
        Binding<Bool?>(
            get: { self.wrappedValue != nil ? !self.wrappedValue! : nil },
            set: { $0 != nil ? self.wrappedValue = !$0! : nil }
        )
    }
}
