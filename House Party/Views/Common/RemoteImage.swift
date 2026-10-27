//
//  RemoteImage.swift
//  House Party
//
//  Created by Marcel Schafaczek on 28.07.26.
//

import SwiftUI

public struct RemoteImage: View {
    let url: URL?
    let size: CGSize
    let placeholder: String?
    
    init(url: URL?, size: CGSize, placeholder: String? = nil) {
        self.url = url
        self.size = size
        self.placeholder = placeholder
    }
    
    public var body: some View {
        AsyncImage(url: self.url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: self.size.width, height: self.size.height)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: self.size.width, height: self.size.height)
            case .failure:
                self.placeholderView
            @unknown default:
                self.placeholderView
            }
        }
    }
    
    private var placeholderView: some View {
        Image(systemName: self.placeholder ?? "music.note")
            .resizable()
            .scaledToFit()
            .frame(width: self.size.width, height: self.size.height)
    }
}
