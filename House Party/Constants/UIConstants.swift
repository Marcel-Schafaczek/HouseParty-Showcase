//
//  UIConstants.swift
//  House Party
//
//  Created by Marcel Schafaczek on 08.08.26.
//

import Foundation
import SwiftUI

public struct UIConstants {
    public static let coverImageSizeBig: CGSize = CGFloat(80).toSquareSize()
    public static let coverImageSizeMedium: CGSize = CGFloat(50).toSquareSize()
    public static let coverImageSizeSmall: CGSize = CGFloat(40).toSquareSize()
    public static let coverImageBestResolution: CGSize = CGFloat(200).toSquareSize()
    
    public static let buttonShape: some Shape = RoundedRectangle(cornerRadius: 15)
    
    private init() { }
}
