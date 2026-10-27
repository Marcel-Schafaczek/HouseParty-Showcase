//
//  CreatePartyView.swift
//  House Party
//
//  Created by Marcel Schafaczek on 21.08.26.
//

import SwiftUI

public struct PartyManagementView: View {
    private enum Mode: Int {
        case create = 0
        case join = 1
    }
    
    @Environment(SpotifyAuth.self)
    private var spotifyAuth
    
    @Environment(PartyService.self)
    private var partyService
    
    @State
    private var partyNameOrJoinCode: String = ""
    @State
    private var username: String = ""
    @State
    private var modeSelection: Mode = .create
    
    private let createText = "Erstellen"
    private let joinText = "Beitreten"
    
    private var createNew: Bool {
        return self.modeSelection == .create
    }
    
    private var navigationTitle: String {
        return self.createNew ? "Party erstellen" : "Party beitreten"
    }
    
    private var partyTextFieldPlaceholder: String {
        return self.createNew ? "Name der Party" : "Party-Code"
    }
    
    private var buttonTitle: String {
        return self.createNew ? self.createText : self.joinText
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .center, spacing: 25) {
                    Picker("", selection: self.$modeSelection) {
                        Text(self.createText).tag(Mode.create)
                        Text(self.joinText).tag(Mode.join)
                    }
                    .pickerStyle(.segmented)
                    
                    TextField(
                        "",
                        text: self.$partyNameOrJoinCode,
                        prompt: Text(self.partyTextFieldPlaceholder)
                    )
                    TextField("", text: self.$username, prompt: Text("Dein Name"))
                    
                    Button {
                        Task {
                            if self.createNew {
                                await self.partyService.createParty(
                                    name: self.partyNameOrJoinCode,
                                    hostDisplayName: self.username
                                )
                            }
                            else {
                                await self.partyService.joinParty(
                                    joinCode: self.partyNameOrJoinCode,
                                    userDisplayName: self.username
                                )
                            }
                        }
                    } label: {
                        Text(self.buttonTitle)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.accent)
                            .clipShape(UIConstants.buttonShape)
                    }
                    .padding(.top)
                }
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, geometry.size.width / 12)
                .frame(maxWidth: .infinity)
                .frame(height: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle(self.navigationTitle)
        .toolbarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Abmelden") {
                    self.spotifyAuth.signOut()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PartyManagementView()
    }
}
