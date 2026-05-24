//
//  ProfileSelectView.swift
//
//  Created by Harsh Kumar on 31/03/26.
//

import SwiftUI

struct ProfileSelectView: View {
    private let vm: ProfileSelectViewModel
    @State private var appeared = false
    let profiles: [Profile]

    init(profiles: [Profile], authUc: AuthUsecase) {
        self.profiles = profiles
        self.vm = ProfileSelectViewModel(authUc: authUc)
    }

    var body: some View {
        ZStack {
            ProfileBackdrop()

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: max(proxy.size.height * 0.12, 48))

                        header
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : -12)

                        Spacer(minLength: 40).frame(maxHeight: 72)

                        profileGrid
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)

                        Spacer(minLength: 60)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
            }

            if vm.showPinInput {
                PinOverlay(vm: vm)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(
                                with: .scale(scale: 0.94, anchor: .center)
                            ),
                            removal: .opacity.combined(
                                with: .scale(scale: 0.96, anchor: .center)
                            )
                        )
                    )
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.dark)
        .animation(
            .spring(response: 0.42, dampingFraction: 0.82),
            value: vm.showPinInput
        )
        .onAppear {
            withAnimation(
                .spring(response: 0.65, dampingFraction: 0.82).delay(0.05)
            ) {
                appeared = true
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Who's watching?")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.Colors.elementWhite)

            Text("Choose a profile to continue")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppTheme.Colors.elementSubtle)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }

    private var profileGrid: some View {
        let cardWidth: CGFloat = 150
        let spacing: CGFloat = 28
        #if os(iOS)
            let maxColumns = 3
        #else
            let maxColumns = 5
        #endif
        let columnCount = max(1, min(profiles.count, maxColumns))
        let gridWidth =
            CGFloat(columnCount) * cardWidth
            + CGFloat(max(columnCount - 1, 0)) * spacing
        let columns = Array(
            repeating: GridItem(.fixed(cardWidth), spacing: spacing),
            count: columnCount
        )

        return LazyVGrid(columns: columns, alignment: .center, spacing: 32) {
            ForEach(Array(profiles.enumerated()), id: \.element.id) {
                index, profile in
                ProfileCard(
                    profile: profile,
                    isSelected: vm.selectedProfile?.id == profile.id,
                    isLoading: vm.isLoading
                        && vm.selectedProfile?.id == profile.id
                ) {
                    vm.selectProfile(profile)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.82)
                        .delay(Double(index) * 0.05),
                    value: appeared
                )
            }
        }
        .frame(width: gridWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.Spacing.lg)
    }
}

private struct ProfileBackdrop: View {
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.02),
                    Color.clear,
                ],
                center: .init(x: 0.5, y: -0.05),
                startRadius: 0,
                endRadius: 640
            )
            .ignoresSafeArea()
        }
    }
}

private struct ProfileCard: View {
    let profile: Profile
    let isSelected: Bool
    let isLoading: Bool
    let action: () -> Void

    @State private var hovering = false
    @State private var pressed = false

    private var initials: String {
        let parts = profile.name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        return parts.joined()
    }

    private var avatarGradient: LinearGradient {
        let hue = Double(abs(profile.id) * 47 % 360) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.65, brightness: 0.95),
                Color(
                    hue: (hue + 0.08).truncatingRemainder(dividingBy: 1),
                    saturation: 0.55,
                    brightness: 0.55
                ),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.08)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.68)) {
                    pressed = false
                }
            }
            action()
        } label: {
            VStack(spacing: 14) {
                avatar

                VStack(spacing: 4) {
                    Text(profile.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            (hovering || isSelected)
                                ? AppTheme.Colors.elementWhite
                                : AppTheme.Colors.elementSubtle
                        )
                        .lineLimit(1)

                    if profile.isAdmin {
                        Text("Admin")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.4)
                            .textCase(.uppercase)
                            .foregroundStyle(AppTheme.Colors.elementMuted)
                    } else {
                        // Reserve space so names line up
                        Text(" ")
                            .font(.system(size: 10, weight: .semibold))
                            .opacity(0)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.96 : (hovering ? 1.03 : 1.0))
            .animation(
                .spring(response: 0.32, dampingFraction: 0.72),
                value: hovering
            )
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { hovering = $0 }
        #endif
    }

    private var avatar: some View {
        ZStack {
            // Outer focus ring (selected / hovered)
            Circle()
                .stroke(
                    Color.white.opacity(hovering || isSelected ? 0.9 : 0.0),
                    lineWidth: 2.5
                )
                .frame(width: 112, height: 112)
                .animation(
                    .easeInOut(duration: 0.18),
                    value: hovering || isSelected
                )

            Circle()
                .fill(avatarGradient)
                .frame(width: 96, height: 96)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(0.35),
                    radius: 12,
                    x: 0,
                    y: 6
                )

            if isLoading {
                Circle()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 96, height: 96)
                ProgressView()
                    .tint(.white)
                    .controlSize(.regular)
            } else {
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }

            if profile.isPinProtected {
                lockBadge
                    .offset(x: 36, y: 34)
            }
        }
        .shadow(
            color: (hovering || isSelected)
                ? Color.white.opacity(0.18) : .clear,
            radius: 18,
            x: 0,
            y: 0
        )
    }

    private var lockBadge: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .frame(width: 26, height: 26)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}

private struct PinOverlay: View {
    @Bindable var vm: ProfileSelectViewModel
    @FocusState private var pinFocused: Bool
    @State private var shake: CGFloat = 0
    @State private var appeared = false

    private let pinLength = 6

    var body: some View {
        ZStack {
            // Backdrop
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.35).ignoresSafeArea())
                .contentShape(Rectangle())
                .onTapGesture { vm.cancelPinInput() }

            VStack(spacing: 28) {
                header

                PinDotsView(
                    text: vm.pinText,
                    dotCount: pinLength,
                    hasError: vm.err != nil
                )
                .modifier(ShakeEffect(travel: shake))

                if let err = vm.err {
                    Text(err)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.Colors.error)
                        .transition(.opacity)
                } else {
                    Text("Enter your 6-digit PIN")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.Colors.elementMuted)
                }

                #if os(iOS)
                    NumericKeypad(
                        text: $vm.pinText,
                        maxLength: pinLength,
                        onSubmit: { submit() }
                    )
                    .padding(.top, 4)
                #else
                    HiddenPinField(
                        text: $vm.pinText,
                        focused: $pinFocused,
                        onSubmit: { submit() }
                    )
                    .frame(height: 0)
                #endif

                HStack(spacing: 12) {
                    Button {
                        vm.cancelPinInput()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.elementWhite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: AppTheme.Radius.md,
                                    style: .continuous
                                )
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(
                                        cornerRadius: AppTheme.Radius.md,
                                        style: .continuous
                                    )
                                    .stroke(
                                        Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
                                )
                            )
                    }
                    .buttonStyle(.plain)

                    PrimaryButton(
                        title: "Continue",
                        isLoading: vm.isLoading
                    ) {
                        submit()
                    }
                    .opacity(
                        (vm.pinText.count == pinLength || vm.isLoading)
                            ? 1 : 0.55
                    )
                    .disabled(
                        vm.pinText.count != pinLength && !vm.isLoading
                    )
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
            .frame(maxWidth: 380)
            .background(PinCardBackground())
            .contentShape(Rectangle())
            .onTapGesture { /* swallow taps so backdrop doesn't dismiss */ }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .scaleEffect(appeared ? 1 : 0.96)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                pinFocused = true
            }
        }
        .onChange(of: vm.pinText) { _, newValue in
            // Enforce max length (6) and digits-only.
            let filtered = newValue.filter(\.isNumber)
            let clamped = String(filtered.prefix(pinLength))
            if clamped != newValue {
                vm.pinText = clamped
                return
            }
            if clamped.count == pinLength && !vm.isLoading {
                submit()
            }
        }
        .onChange(of: vm.err) { _, newErr in
            guard newErr != nil else { return }
            triggerShake()
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            MiniProfileAvatar(profile: vm.selectedProfile)

            VStack(spacing: 4) {
                Text(vm.selectedProfile?.name ?? "Profile")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.elementWhite)

                Text("Protected profile")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.elementMuted)
            }
        }
    }

    private func submit() {
        guard vm.pinText.count == pinLength else {
            vm.err = "PIN must be 6 digits"
            return
        }
        vm.submitPin()
    }

    private func triggerShake() {
        withAnimation(
            .spring(response: 0.25, dampingFraction: 0.35)
        ) {
            shake = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            shake = 0
            vm.pinText = ""
        }
    }
}

private struct PinDotsView: View {
    let text: String
    let dotCount: Int
    let hasError: Bool

    var body: some View {
        HStack(spacing: 18) {
            ForEach(0..<max(dotCount, text.count), id: \.self) { index in
                Circle()
                    .fill(
                        index < text.count
                            ? (hasError
                                ? AppTheme.Colors.error
                                : AppTheme.Colors.elementWhite)
                            : Color.clear
                    )
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(
                                hasError
                                    ? AppTheme.Colors.error.opacity(0.7)
                                    : Color.white.opacity(
                                        index < text.count ? 0 : 0.35
                                    ),
                                lineWidth: 1.5
                            )
                    )
                    .scaleEffect(index < text.count ? 1.0 : 0.92)
                    .animation(
                        .spring(response: 0.28, dampingFraction: 0.6),
                        value: text.count
                    )
            }
        }
    }
}

private struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 0

    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let amplitude: CGFloat = 8
        let x = sin(travel * .pi * 5) * amplitude
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

private struct MiniProfileAvatar: View {
    let profile: Profile?

    private var initials: String {
        guard let p = profile else { return "?" }
        let parts = p.name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        return parts.joined()
    }

    private var gradient: LinearGradient {
        let id = profile?.id ?? 0
        let hue = Double(abs(id) * 47 % 360) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.65, brightness: 0.95),
                Color(
                    hue: (hue + 0.08).truncatingRemainder(dividingBy: 1),
                    saturation: 0.55,
                    brightness: 0.55
                ),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient)
                .frame(width: 64, height: 64)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            Text(initials)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}

private struct PinCardBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.03))

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.05),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.55), radius: 40, x: 0, y: 24)
    }
}

#if !os(iOS)
    private struct HiddenPinField: View {
        @Binding var text: String
        var focused: FocusState<Bool>.Binding
        let onSubmit: () -> Void

        var body: some View {
            SecureField("", text: $text)
                .focused(focused)
                .onSubmit(onSubmit)
                .textFieldStyle(.plain)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(width: 1, height: 1)
                .opacity(0.01)
        }
    }
#endif

#if os(iOS)
    private struct NumericKeypad: View {
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
            VStack(spacing: 14) {
                ForEach(0..<keys.count, id: \.self) { row in
                    HStack(spacing: 18) {
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
                KeypadButton {
                    guard text.count < maxLength else { return }
                    text.append(digit)
                } label: {
                    Text(digit)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(AppTheme.Colors.elementWhite)
                }
            case .delete:
                KeypadButton {
                    if !text.isEmpty { text.removeLast() }
                } label: {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(AppTheme.Colors.elementWhite)
                }
            case .spacer:
                Color.clear.frame(width: 68, height: 68)
            }
        }
    }

    private enum KeypadKey {
        case digit(String)
        case delete
        case spacer
    }

    private struct KeypadButton<Label: View>: View {
        let action: () -> Void
        @ViewBuilder let label: () -> Label
        @State private var pressed = false

        var body: some View {
            Button {
                action()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            pressed
                                ? Color.white.opacity(0.18)
                                : Color.white.opacity(0.07)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                    label()
                }
                .frame(width: 68, height: 68)
                .scaleEffect(pressed ? 0.94 : 1.0)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed {
                            withAnimation(.easeOut(duration: 0.08)) {
                                pressed = true
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(
                            .spring(response: 0.3, dampingFraction: 0.7)
                        ) {
                            pressed = false
                        }
                    }
            )
        }
    }
#endif

