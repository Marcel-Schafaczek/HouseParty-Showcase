//
//  ToastMessageUtility.swift
//  House Party
//
//  Created by Marcel Schafaczek on 12.08.26.
//

import SwiftUI

@MainActor
@Observable
public final class ToastMessageUtility {
    public static let shared = ToastMessageUtility()
    
    public private(set) var message: ToastMessage?
    
    private var dismissalTask: Task<Void, Never>?
    
    private init() { }
    
    public nonisolated static func show(message: ToastMessage) {
        Task { @MainActor in
            Self.shared.present(message)
        }
    }
    
    private func present(_ message: ToastMessage) {
        self.dismissalTask?.cancel()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            self.message = message
        }
        
        self.dismissalTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(message.duration * Double(NSEC_PER_SEC)))
            
            guard !Task.isCancelled else {
                return
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self?.message = nil
                }
            }
        }
    }
}

private struct ToastMessageOverlayModifier: ViewModifier {
    @State
    private var toastMessageUtility = ToastMessageUtility.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message = self.toastMessageUtility.message {
                    ToastMessageView(message: message)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
    }
}

private struct ToastMessageView: View {
    let message: ToastMessage
    
    private var iconName: String {
        switch self.message.style {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }
    
    private var tint: Color {
        switch self.message.style {
        case .success:
            return .green
        case .error:
            return .red
        }
    }
    
    var body: some View {
        Label {
            Text(self.message.text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        } icon: {
            Image(systemName: self.iconName)
                .foregroundStyle(self.tint)
        }
        .foregroundStyle(.background)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.primary.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .allowsHitTesting(false)
    }
}

public extension View {
    func toastMessageOverlay() -> some View {
        modifier(ToastMessageOverlayModifier())
    }
}
