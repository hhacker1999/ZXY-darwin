
import SwiftUI

extension View {
    /// Adds the toast + progress overlays driven by `ToastProgressBloc.bloc`
    /// on top of the receiver. Call once at the app root.
    func withGlobalOverlays() -> some View {
        modifier(GlobalOverlaysModifier())
    }
}

private struct GlobalOverlaysModifier: ViewModifier {
    @State private var bloc = ToastProgressBloc.bloc

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = bloc.toastMessage {
                    GlobalToastView(message: message, isError: bloc.isToastError)
                        .padding(.top, AppTheme.Spacing.md)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .overlay {
                if bloc.showLoading {
                    GlobalProgressOverlay()
                        .transition(.opacity)
                        .zIndex(101)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: bloc.toastMessage)
            .animation(.easeInOut(duration: 0.18), value: bloc.showLoading)
    }
}

struct GlobalToastView: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(
                systemName: isError
                    ? "exclamationmark.circle.fill"
                    : "checkmark.circle.fill"
            )
            .foregroundStyle(
                isError ? AppTheme.Colors.error : AppTheme.Colors.success
            )
            Text(message)
                .font(AppTheme.Typography.bodySmall)
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: AppTheme.Shadows.deep, radius: 18, x: 0, y: 8)
    }
}

struct GlobalProgressOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                // Swallow taps so nothing behind reacts while loading.
                .onTapGesture {}

            VStack(spacing: AppTheme.Spacing.md) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                    .tint(AppTheme.Colors.elementWhite)
            }
            .padding(AppTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: AppTheme.Shadows.deep, radius: 22, x: 0, y: 10)
        }
    }
}
