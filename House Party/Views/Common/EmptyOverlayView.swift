//
//  EmptyOverlayView.swift
//  House Party
//
//  Created by Marcel Schafaczek on 29.07.26.
//

import SwiftUI

public struct EmptyState {
    let title: String
    let subtitle: String?
    let showLoadingIndicator: Bool
    
    init(title: String, subtitle: String? = nil, showLoadingIndicator: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.showLoadingIndicator = showLoadingIndicator
    }
}

public struct EmptyOverlayView: View {
    public let state: EmptyState
    public let minHeight: CGFloat
    
    public var body: some View {
        VStack(spacing: 10) {
            if self.state.showLoadingIndicator {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .padding(.bottom)
            }
            
            Text(self.state.title)
                .font(.headline)
            
            if let subtitle = self.state.subtitle {
                Text(subtitle)
                    .font(.subheadline)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: self.minHeight)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}
