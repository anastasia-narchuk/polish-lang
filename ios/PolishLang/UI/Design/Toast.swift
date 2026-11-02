import SwiftUI

/// Shows `ToastCenter.message` at the bottom. Applied to the root and to sheets, which cover the root.
struct ToastOverlay: ViewModifier {
    @Environment(ToastCenter.self) private var toasts
    var bottomPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message = toasts.message {
                    Text(message)
                        .font(.callout.weight(.medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 3)
                        .padding(.horizontal, 24)
                        .padding(.bottom, bottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: toasts.message)
    }
}

extension View {
    func toastOverlay(bottomPadding: CGFloat = 24) -> some View {
        modifier(ToastOverlay(bottomPadding: bottomPadding))
    }
}
