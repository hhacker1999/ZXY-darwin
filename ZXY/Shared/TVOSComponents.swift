//
//  TVOSComponents.swift
//
//  Shared tvOS UI primitives — large type, card focus, numeric keypad.
//

import SwiftUI

#if os(tvOS)

    enum TVOSTypography {
        static let heroTitle = Font.system(
            size: 57,
            weight: .bold,
            design: .default
        )
        static let heroSubtitle = Font.system(
            size: 29,
            weight: .regular,
            design: .default
        )
        static let fieldLabel = Font.system(
            size: 29,
            weight: .medium,
            design: .default
        )
        static let fieldText = Font.system(
            size: 31,
            weight: .regular,
            design: .default
        )
        static let button = Font.system(
            size: 31,
            weight: .semibold,
            design: .default
        )
        static let caption = Font.system(
            size: 25,
            weight: .regular,
            design: .default
        )
        static let profileName = Font.system(
            size: 31,
            weight: .semibold,
            design: .default
        )
        static let keypadDigit = Font.system(
            size: 38,
            weight: .regular,
            design: .default
        )
    }

    struct TVOSBackdrop: View {
        var body: some View {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.white.opacity(0.02),
                        Color.clear,
                    ],
                    center: .init(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 900
                )
                .ignoresSafeArea()
            }
        }
    }

    struct TVOSAppMark: View {
        var size: CGFloat = 120

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.white.opacity(0.06),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: size * 0.28,
                            style: .continuous
                        )
                        .stroke(Color.white.opacity(0.22), lineWidth: 2)
                    )
                    .frame(width: size, height: size)

                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    struct TVOSTextField: View {
        let label: String
        @Binding var text: String
        var isSecure: Bool = false

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Text(label)
                    .font(TVOSTypography.fieldLabel)
                    .foregroundStyle(AppTheme.Colors.elementSubtle)

                Group {
                    if isSecure {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                            #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            #endif
                    }
                }
                .font(TVOSTypography.fieldText)
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .tint(AppTheme.Colors.elementWhite)
                .padding(.horizontal, 36)
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(
                        cornerRadius: AppTheme.Radius.lg,
                        style: .continuous
                    )
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: AppTheme.Radius.lg,
                            style: .continuous
                        )
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                    )
                )
            }
        }
    }

    struct TVOSPrimaryButton: View {
        let title: String
        var isLoading: Bool = false
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                ZStack {
                    Text(title)
                        .font(TVOSTypography.button)
                        .foregroundStyle(AppTheme.Colors.buttonPrimaryLabel)
                        .opacity(isLoading ? 0 : 1)

                    if isLoading {
                        ProgressView()
                            .tint(AppTheme.Colors.buttonPrimaryLabel)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(
                    RoundedRectangle(
                        cornerRadius: AppTheme.Radius.lg,
                        style: .continuous
                    )
                    .fill(AppTheme.Colors.buttonPrimary)
                )
            }
            .buttonStyle(.card)
            .disabled(isLoading)
        }
    }

    struct TVOSSecondaryButton: View {
        let title: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(TVOSTypography.button)
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(
                            cornerRadius: AppTheme.Radius.lg,
                            style: .continuous
                        )
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: AppTheme.Radius.lg,
                                style: .continuous
                            )
                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                        )
                    )
            }
            .buttonStyle(.card)
        }
    }

    struct TVOSErrorBanner: View {
        let message: String

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 25, weight: .semibold))
                Text(message)
                    .font(TVOSTypography.caption)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(AppTheme.Colors.error)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(
                    cornerRadius: AppTheme.Radius.lg,
                    style: .continuous
                )
                .fill(AppTheme.Colors.error.opacity(0.12))
                .overlay(
                    RoundedRectangle(
                        cornerRadius: AppTheme.Radius.lg,
                        style: .continuous
                    )
                    .stroke(AppTheme.Colors.error.opacity(0.35), lineWidth: 1)
                )
            )
        }
    }

    struct TVOSPinDots: View {
        let text: String
        let dotCount: Int
        var hasError: Bool = false

        var body: some View {
            HStack(spacing: 28) {
                ForEach(0..<dotCount, id: \.self) { index in
                    Circle()
                        .fill(
                            index < text.count
                                ? (hasError
                                    ? AppTheme.Colors.error
                                    : AppTheme.Colors.elementWhite)
                                : Color.clear
                        )
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .stroke(
                                    hasError
                                        ? AppTheme.Colors.error.opacity(0.7)
                                        : Color.white.opacity(
                                            index < text.count ? 0 : 0.35
                                        ),
                                    lineWidth: 2
                                )
                        )
                }
            }
        }
    }

    struct TVOSNumericKeypad: View {
        @Binding var text: String
        let maxLength: Int
        let onSubmit: () -> Void

        private let keys: [[KeypadKey]] = [
            [.digit("1"), .digit("2"), .digit("3")],
            [.digit("4"), .digit("5"), .digit("6")],
            [.digit("7"), .digit("8"), .digit("9")],
            [.spacer, .digit("0"), .delete],
        ]

        var body: some View {
            VStack(spacing: 20) {
                ForEach(0..<keys.count, id: \.self) { row in
                    HStack(spacing: 24) {
                        ForEach(keys[row].indices, id: \.self) { col in
                            keyView(keys[row][col])
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private func keyView(_ key: KeypadKey) -> some View {
            switch key {
            case .digit(let digit):
                Button {
                    guard text.count < maxLength else { return }
                    text.append(digit)
                    if text.count == maxLength {
                        onSubmit()
                    }
                } label: {
                    Text(digit)
                        .font(TVOSTypography.keypadDigit)
                        .foregroundStyle(AppTheme.Colors.elementWhite)
                        .frame(width: 100, height: 100)
                        .background(
                            Circle()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    Circle().stroke(
                                        AppTheme.Colors.border,
                                        lineWidth: 1
                                    )
                                )
                        )
                }
                .buttonStyle(.card)

            case .delete:
                Button {
                    if !text.isEmpty { text.removeLast() }
                } label: {
                    Image(systemName: "delete.left")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(AppTheme.Colors.elementWhite)
                        .frame(width: 100, height: 100)
                        .background(
                            Circle()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    Circle().stroke(
                                        AppTheme.Colors.border,
                                        lineWidth: 1
                                    )
                                )
                        )
                }
                .buttonStyle(.card)

            case .spacer:
                Color.clear.frame(width: 100, height: 100)
            }
        }

        private enum KeypadKey {
            case digit(String)
            case delete
            case spacer
        }
    }

#endif
