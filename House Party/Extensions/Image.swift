//
//  Image.swift
//  House Party
//
//  Created by Marcel Schafaczek on 26.08.26.
//

import SwiftUI

extension Image {
    public func toTrackCoverImage(size: CGSize = UIConstants.coverImageSizeMedium) -> some View {
        return self
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size.width, height: size.height)
    }
}
