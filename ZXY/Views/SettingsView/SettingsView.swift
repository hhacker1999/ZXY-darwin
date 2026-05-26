//
//  SettingsView.swift
//
//  SwiftUI port of `app/lib/views/settings_view/settings_view.dart`. The
//  Profiles (admin) section is intentionally omitted for now.
//

import SwiftUI

struct SettingsView: View {
    @State private var vm: SettingsViewModel
    @State private var settingsBloc = SettingsBloc.bloc
    @State private var userBloc = UserBloc.bloc
    @Environment(\.openURL) private var openURL

    init(authUc: AuthUsecase) {
        _vm = State(initialValue: SettingsViewModel(authUc: authUc))
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    Text("Settings")
                        .font(AppTheme.Typography.displayMedium)
                        .foregroundStyle(AppTheme.Colors.elementWhite)

                    if let profile = userBloc.profile {
                        accountBlock(profile: profile)
                        generalBlock(profile: profile)
                        libraryBlock(profile: profile)
                        sourcesBlock(profile: profile)
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .padding(.horizontal, AppTheme.Layout.tabScreenHorizontalPadding)
                .padding(.top, AppTheme.Spacing.xl)
                .padding(.bottom, AppTheme.Spacing.xxl)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let profile = userBloc.profile {
                vm.initIfNeeded(for: profile)
            }
            #if os(macOS)
                DiscordRichPresenceBloc.bloc.setBrowsing(page: "Settings")
            #endif
        }
    }

    @ViewBuilder
    private func accountBlock(profile: Profile) -> some View {
        SettingsSectionLabel("Account")
        AccountCardView(
            profile: profile,
            waitingTraktLogin: vm.waitingTraktLogin,
            onSwitchProfile: { vm.switchProfile() },
            onLogout: { vm.logout() },
            onDeleteAccount: profile.isAdmin ? { Task { await vm.deleteAccount() } } : nil,
            onTraktLogin: {
                Task {
                    await vm.loginTrakt { url in openURL(url) }
                }
            },
            onTraktLogout: { Task { await vm.deleteTrakt() } }
        )
    }

    @ViewBuilder
    private func generalBlock(profile _: Profile) -> some View {
        SettingsSectionLabel("General")
        GeneralSection(bloc: settingsBloc)
    }

    @ViewBuilder
    private func libraryBlock(profile _: Profile) -> some View {
        SettingsSectionLabel("Library Customization")
        LibraryCustomizationSection(vm: vm)
    }

    @ViewBuilder
    private func sourcesBlock(profile: Profile) -> some View {
        SettingsSectionLabel("Sources")
        SourcesSection(profile: profile, vm: vm)
    }
}

struct SettingsSectionLabel: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.elementWhite)
            .padding(.bottom, AppTheme.Spacing.xs)
    }
}

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct SettingsProfileAvatar: View {
    let name: String
    let size: CGFloat

    private static let palette: [Color] = [
        Color(hex: "#229ED9"),
        Color(hex: "#E50914"),
        Color(hex: "#2E7D32"),
        Color(hex: "#FFA000"),
        Color(hex: "#7B1FA2"),
        Color(hex: "#00ACC1"),
    ]

    private var color: Color {
        let idx = abs(name.hashValue) % Self.palette.count
        return Self.palette[idx]
    }

    private var initial: String {
        guard let first = name.first else { return "?" }
        return String(first).uppercased()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}
