//
//  ProfileSelectViewTVOS.swift
//
//  tvOS-native profile picker — Apple TV "Who's watching?" style.
//

import SwiftUI

#if os(tvOS)

struct ProfileSelectViewTVOS: View {
    private let vm: ProfileSelectViewModel
    let profiles: [Profile]

    init(profiles: [Profile], authUc: AuthUsecase) {
        self.profiles = profiles
        self.vm = ProfileSelectViewModel(authUc: authUc)
    }

    var body: some View {
        ZStack {
            TVOSBackdrop()

            VStack(spacing: 0) {
                Spacer()

                header
                    .padding(.bottom, 80)

                profileRow

                Spacer()
            }

            if vm.showPinInput {
                TVOSPinOverlay(vm: vm)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: vm.showPinInput)
    }

    private var header: some View {
        VStack(spacing: 16) {
            Text("Who's watching?")
                .font(.system(size: 76, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.Colors.elementWhite)

            Text("Choose a profile to continue")
                .font(TVOSTypography.heroSubtitle)
                .foregroundStyle(AppTheme.Colors.elementSubtle)
        }
        .multilineTextAlignment(.center)
    }

    private var profileRow: some View {
        HStack(spacing: 60) {
            ForEach(profiles, id: \.id) { profile in
                TVOSProfileCard(
                    profile: profile,
                    isLoading: vm.isLoading && vm.selectedProfile?.id == profile.id
                ) {
                    vm.selectProfile(profile)
                }
            }
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 48)
        .focusSection()
    }
}

// MARK: - Profile Card

private struct TVOSProfileCard: View {
    let profile: Profile
    let isLoading: Bool
    let action: () -> Void

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
        Button(action: action) {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(avatarGradient)
                        .frame(width: 220, height: 220)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 2)
                        )

                    if isLoading {
                        Circle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 220, height: 220)
                        ProgressView()
                            .tint(.white)
                            .controlSize(.large)
                    } else {
                        Text(initials.isEmpty ? "?" : initials)
                            .font(.system(size: 72, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    if profile.isPinProtected {
                        lockBadge
                            .offset(x: 82, y: 82)
                    }
                }

                VStack(spacing: 6) {
                    Text(profile.name)
                        .font(TVOSTypography.profileName)
                        .foregroundStyle(AppTheme.Colors.elementWhite)
                        .lineLimit(1)

                    if profile.isAdmin {
                        Text("Admin")
                            .font(.system(size: 22, weight: .semibold))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(AppTheme.Colors.elementMuted)
                    } else {
                        Text(" ")
                            .font(.system(size: 22, weight: .semibold))
                            .opacity(0)
                    }
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 32)
            .padding(.horizontal, 32)
            .frame(width: 300)
        }
        .buttonStyle(.card)
    }

    private var lockBadge: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.backgroundTertiary)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                )

            Image(systemName: "lock.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - PIN Overlay

private struct TVOSPinOverlay: View {
    @Bindable var vm: ProfileSelectViewModel
    @State private var shake: CGFloat = 0

    private let pinLength = 6

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 36) {
                VStack(spacing: 16) {
                    TVOSMiniAvatar(profile: vm.selectedProfile)

                    Text(vm.selectedProfile?.name ?? "Profile")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.elementWhite)

                    Text("Enter your PIN")
                        .font(TVOSTypography.heroSubtitle)
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                }

                TVOSPinDots(
                    text: vm.pinText,
                    dotCount: pinLength,
                    hasError: vm.err != nil
                )
                .modifier(TVOSShakeEffect(travel: shake))

                if let err = vm.err {
                    Text(err)
                        .font(TVOSTypography.caption)
                        .foregroundStyle(AppTheme.Colors.error)
                }

                TVOSNumericKeypad(
                    text: $vm.pinText,
                    maxLength: pinLength,
                    onSubmit: { submit() }
                )
                .padding(.top, 8)

                HStack(spacing: 24) {
                    TVOSSecondaryButton(title: "Cancel") {
                        vm.cancelPinInput()
                    }

                    TVOSPrimaryButton(
                        title: "Continue",
                        isLoading: vm.isLoading
                    ) {
                        submit()
                    }
                    .opacity(
                        (vm.pinText.count == pinLength || vm.isLoading) ? 1 : 0.55
                    )
                    .disabled(vm.pinText.count != pinLength && !vm.isLoading)
                }
                .frame(maxWidth: 520)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 52)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(AppTheme.Colors.backgroundTertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(AppTheme.Colors.borderStrong, lineWidth: 1)
                    )
            )
            .frame(maxWidth: 720)
        }
        .onChange(of: vm.err) { _, newErr in
            guard newErr != nil else { return }
            triggerShake()
        }
        .focusSection()
    }

    private func submit() {
        guard vm.pinText.count == pinLength else {
            vm.err = "PIN must be 6 digits"
            return
        }
        vm.submitPin()
    }

    private func triggerShake() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) {
            shake = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            shake = 0
            vm.pinText = ""
        }
    }
}

private struct TVOSMiniAvatar: View {
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
                .frame(width: 96, height: 96)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                )

            Text(initials)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

private struct TVOSShakeEffect: GeometryEffect {
    var travel: CGFloat = 0

    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let amplitude: CGFloat = 12
        let x = sin(travel * .pi * 5) * amplitude
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

#endif
