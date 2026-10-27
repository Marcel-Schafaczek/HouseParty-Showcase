//
//  SearchScopeView.swift
//  House Party
//
//  Created by Marcel Schafaczek on 06.08.26.
//

import SwiftUI

struct SearchScopeView: View {
    @Binding
    public var selectedScopes: [ContentCategory]
    public let availableScopes: [ContentCategory]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(self.availableScopes) { scope in
                    ScopeButton(text: scope.displayValue) { isSelected in
                        if isSelected && !self.selectedScopes.contains(scope) {
                            self.selectedScopes.append(scope)
                        } else if !isSelected && self.selectedScopes.contains(scope) {
                            self.selectedScopes.removeAll(where: { $0.id == scope.id })
                        }
                        else {
                            print("Invalid button selection state.\n" +
                                  "Category: \(scope.displayValue)\n" +
                                  "Is selected: \(isSelected)\n" +
                                  "Total current selection: \(self.selectedScopes.map(\.displayValue).joined(separator: ", "))"
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 15)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct ScopeButton: View {
    let text: String
    let callback: (_ isSelected: Bool) -> Void
    
    @State
    private var isSelected: Bool = false
    
    var body: some View {
        Button {
            self.isSelected.toggle()
            self.callback(self.isSelected)
        } label: {
            Text(self.text)
                .font(.headline)
                .padding(10)
                .foregroundStyle(.white.opacity(self.isSelected ? 1.0 : 0.8))
                .background(self.isSelected ? .accent : .clear)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.8), lineWidth: self.isSelected ? 0 : 1.0)
                }
                .padding(.vertical, 2.5)
        }
    }
}
