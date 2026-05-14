//
//  PrimaryButton.swift
//
//  Created by Harsh Kumar on 29/03/26.
//
import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.09)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    pressed = false
                }
            }
            action()
        } label: {
            ZStack {
                // Anchor the intrinsic height to the title text so switching
                // to the spinner does not change button size.
                Text(title)
                    .font(AppTheme.Typography.labelLarge)
                    .foregroundColor(AppTheme.Colors.buttonPrimaryLabel)
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    SpinningIndicator(
                        color: AppTheme.Colors.buttonPrimaryLabel
                    )
                    .frame(width: 18, height: 18)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .fill(AppTheme.Gradients.primaryButton)
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .fill(Color.black.opacity(pressed ? 0.10 : 0))
                }
            )
            .shadow(
                color: AppTheme.Shadows.card,
                radius: pressed ? 4 : 12,
                x: 0,
                y: pressed ? 2 : 5
            )
            .scaleEffect(pressed ? 0.975 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isLoading)
        }
        .buttonStyle(.plain)
    }
}


private struct SpinningIndicator: View {
    let color: Color
    @State private var rotating = false

    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.75)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
            )
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .animation(
                .linear(duration: 0.85).repeatForever(autoreverses: false),
                value: rotating
            )
            .onAppear { rotating = true }
    }
}

struct SecondaryButton: View {
    let icon: String
    let label: String
    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.09)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    pressed = false
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(label)
                    .font(AppTheme.Typography.labelMedium)
            }
            .foregroundColor(AppTheme.Colors.elementWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .fill(
                            pressed
                                ? AppTheme.Colors.surfaceHovered
                                : AppTheme.Colors.surface
                        )
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                }
            )
            .scaleEffect(pressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.65),
            value: pressed
        )
    }
}
