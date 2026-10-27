//
//  RootView.swift
//  House Party
//
//  Created by Marcel Schafaczek on 21.08.26.
//

import SwiftUI

struct RootView: View {
    @Environment(SpotifyAuth.self)
    private var spotifyAuth
    
    @Environment(PartyService.self)
    private var partyService
    
    var body: some View {
        Group {
            if self.partyService.party != nil {
                MainTabView()
            }
            else {
                NavigationStack {
                    if self.spotifyAuth.isAuthorized {
                        PartyManagementView()
                    }
                    else {
                        SpotifySignInView()
                    }
                }
            }
        }
        .tabViewStyle(.tabBarOnly)
    }
}

#Preview {
    RootView()
}
