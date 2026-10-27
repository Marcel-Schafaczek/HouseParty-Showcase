//
//  SpotifySignInView.swift
//  House Party
//
//  Created by Marcel Schafaczek on 21.08.26.
//

import SwiftUI
import SpotifyWebAPI

struct SpotifySignInView: View {
    
    @Environment(SpotifyAuth.self)
    private var spotifyAuth
    var body: some View {
        VStack {
            Text("Lass uns die Party starten!")
                .multilineTextAlignment(.center)
                .font(.headline)
                .padding(.horizontal)
                .padding(.bottom, 10)
            
            Text("Verbinde diese App einfach mit deinem Spotify Account und leg los")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.bottom, 80)
            
            HStack {
                Button(action: self.spotifyAuth.authorize) {
                    Image("SpotifyIconWhite")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 40)
                    
                    Text("Mit Spotify anmelden")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 35)
            .background(Color(red: 30 / 255, green: 215 / 255, blue: 96 / 255))
            .clipShape(Capsule())
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SpotifySignInView()
}
