//
//  SettingsViewTVOS.swift
//
//  tvOS-native Settings — focus-driven cards for profile, general
//  preferences, and a read-only sources list. Trakt login and library
//  customization are intentionally omitted on tvOS.
//

#if os(tvOS)

import SwiftUI

// MARK: - Layout Constants

private enum TVOSSettingsLayout {
    static let horizontalPadding: CGFloat = 100
    static let topPadding: CGFloat = 80
    static let bottomPadding: CGFloat = 80
    static let contentMaxWidth: CGFloat = 1100
    static let sectionSpacing: CGFloat = 40
    static let sectionTitleSpacing: CGFloat = 20
    static let rowSpacing: CGFloat = 14
    static let rowCornerRadius: CGFloat = AppTheme.Radius.lg
    static let rowHorizontalPadding: CGFloat = 32
    static let rowVerticalPadding: CGFloat = 24
    static let iconWidth: CGFloat = 40
}

// MARK: - Settings View

struct SettingsViewTVOS: View {
    @State private var vm: SettingsViewModel
    @State private var settingsBloc = SettingsBloc.bloc
    @State private var userBloc = UserBloc.bloc

    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false

    init(authUc: AuthUsecase) {
        _vm = State(initialValue: SettingsViewModel(authUc: authUc))
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: TVOSSettingsLayout.sectionSpacing) {
                    Text("Settings")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)

                    if let profile = userBloc.profile {
                        profileSection(profile: profile)
                        generalSection
                        sourcesSection(profile: profile)
                    } else {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.6)
                            .padding(.top, 48)
                    }
                }
                .frame(maxWidth: TVOSSettingsLayout.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, TVOSSettingsLayout.horizontalPadding)
                .padding(.top, TVOSSettingsLayout.topPadding)
                .padding(.bottom, TVOSSettingsLayout.bottomPadding)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let profile = userBloc.profile {
                vm.initIfNeeded(for: profile)
            }
        }
        .alert("Log out?", isPresented: $showLogoutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) { vm.logout() }
        } message: {
            Text("You'll need to sign back in to continue watching.")
        }
        .alert("Delete Account", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await vm.deleteAccount() }
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
    }

    // MARK: - Profile Section

    @ViewBuilder
    private func profileSection(profile: Profile) -> some View {
        TVOSSettingsSection(title: "Profile") {
            TVOSProfileSummaryRow(profile: profile)

            TVOSSettingsActionRow(
                icon: "person.2.fill",
                label: "Switch Profile",
                action: { vm.switchProfile() }
            )

            TVOSSettingsActionRow(
                icon: "rectangle.portrait.and.arrow.right",
                label: "Log Out",
                isDestructive: true,
                action: { showLogoutConfirm = true }
            )

            if profile.isAdmin {
                TVOSSettingsActionRow(
                    icon: "trash.fill",
                    label: "Delete Account",
                    isDestructive: true,
                    action: { showDeleteConfirm = true }
                )
            }
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        TVOSSettingsSection(title: "General") {
            TVOSSettingsPickerRow(
                icon: "globe",
                label: "Default Language",
                helper: "Used for default stream language",
                selection: $settingsBloc.language,
                options: languageOptions
            )

            TVOSSettingsPickerRow(
                icon: "captions.bubble",
                label: "Default Subtitle Language",
                helper: "Preferred subtitle track when available",
                selection: $settingsBloc.subtitleLanguage,
                options: subtitleLanguageOptions
            )

            TVOSSettingsPickerRow(
                icon: "goforward",
                label: "Skip Duration",
                helper: "Seconds to skip with the player skip controls",
                selection: Binding(
                    get: { String(settingsBloc.skipDuration) },
                    set: { settingsBloc.skipDuration = Int($0) ?? settingsBloc.skipDuration }
                ),
                options: SettingsBloc.skipDurationOptions.map(String.init),
                displayLabel: { "\($0)s" }
            )
        }
    }

    private var languageOptions: [String] {
        LangHelper.iso6391List.map { $0.1 }.sorted()
    }

    private var subtitleLanguageOptions: [String] {
        ["None"] + LangHelper.iso6391List.map { $0.1 }.sorted()
    }

    // MARK: - Sources Section

    @ViewBuilder
    private func sourcesSection(profile: Profile) -> some View {
        TVOSSettingsSection(title: "Sources") {
            if profile.services.isEmpty {
                TVOSSettingsInfoRow(
                    icon: "server.rack",
                    message: "No sources available for this profile."
                )
            } else {
                ForEach(profile.services) { service in
                    TVOSSourceStatusRow(service: service)
                }
            }
        }
    }
}

// MARK: - Section Wrapper

private struct TVOSSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: TVOSSettingsLayout.sectionTitleSpacing) {
            Text(title.uppercased())
                .font(.system(size: 22, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(AppTheme.Colors.elementMuted)

            VStack(spacing: TVOSSettingsLayout.rowSpacing) {
                content()
            }
            .focusSection()
        }
    }
}

// MARK: - Row Shell (focusable card row)

private struct TVOSSettingsRowShell<Label: View>: View {
    var isInteractive: Bool = true
    var role: ButtonRole? = nil
    var action: () -> Void = {}
    @ViewBuilder let label: () -> Label

    var body: some View {
        if isInteractive {
            Button(role: role, action: action) {
                content
            }
            .buttonStyle(.card)
        } else {
            content
        }
    }

    private var content: some View {
        label()
            .padding(.horizontal, TVOSSettingsLayout.rowHorizontalPadding)
            .padding(.vertical, TVOSSettingsLayout.rowVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(
                    cornerRadius: TVOSSettingsLayout.rowCornerRadius,
                    style: .continuous
                )
                .fill(AppTheme.Colors.surface)
            )
    }
}

// MARK: - Profile Summary Row (non-interactive)

private struct TVOSProfileSummaryRow: View {
    let profile: Profile

    var body: some View {
        TVOSSettingsRowShell(isInteractive: false) {
            HStack(spacing: 22) {
                SettingsProfileAvatar(name: profile.name, size: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)

                    if profile.isAdmin {
                        Text("Admin")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.elementSubtle)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Action Row (Switch Profile / Log Out / Delete Account)

private struct TVOSSettingsActionRow: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        TVOSSettingsRowShell(
            role: isDestructive ? .destructive : nil,
            action: action
        ) {
            HStack(spacing: 22) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(
                        isDestructive ? AppTheme.Colors.error : AppTheme.Colors.elementWhite
                    )
                    .frame(width: TVOSSettingsLayout.iconWidth, alignment: .leading)

                Text(label)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(
                        isDestructive ? AppTheme.Colors.error : AppTheme.Colors.elementWhite
                    )

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.elementMuted)
            }
        }
    }
}

// MARK: - Toggle Row

private struct TVOSSettingsToggleRow: View {
    let icon: String
    let label: String
    let helper: String?
    @Binding var isOn: Bool

    var body: some View {
        TVOSSettingsRowShell(action: { isOn.toggle() }) {
            HStack(spacing: 22) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                    .frame(width: TVOSSettingsLayout.iconWidth, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.elementWhite)
                    if let helper {
                        Text(helper)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(AppTheme.Colors.elementMuted)
                    }
                }

                Spacer(minLength: 0)

                TVOSToggleIndicator(isOn: isOn)
            }
        }
    }
}

private struct TVOSToggleIndicator: View {
    let isOn: Bool

    var body: some View {
        Capsule(style: .continuous)
            .fill(isOn ? AppTheme.Colors.success : Color.white.opacity(0.16))
            .frame(width: 64, height: 38)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: 30, height: 30)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 4)
            }
            .animation(.easeInOut(duration: 0.18), value: isOn)
    }
}

// MARK: - Picker Row + Sheet

private struct TVOSSettingsPickerRow<Value: Hashable>: View {
    let icon: String
    let label: String
    let helper: String?
    @Binding var selection: Value
    let options: [Value]
    var displayLabel: (Value) -> String = { "\($0)" }

    @State private var showSheet = false

    var body: some View {
        TVOSSettingsRowShell(action: { showSheet = true }) {
            HStack(spacing: 22) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                    .frame(width: TVOSSettingsLayout.iconWidth, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.elementWhite)
                    if let helper {
                        Text(helper)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(AppTheme.Colors.elementMuted)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Text(displayLabel(selection))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.elementWhite)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.elementMuted)
                }
            }
        }
        .sheet(isPresented: $showSheet) {
            TVOSPickerSheet(
                title: label,
                selection: $selection,
                options: options,
                displayLabel: displayLabel,
                onDismiss: { showSheet = false }
            )
        }
    }
}

private struct TVOSPickerSheet<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let displayLabel: (Value) -> String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 36) {
                    Text(title)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)

                    VStack(spacing: 14) {
                        ForEach(options, id: \.self) { option in
                            TVOSPickerOptionRow(
                                text: displayLabel(option),
                                isSelected: option == selection
                            ) {
                                selection = option
                                onDismiss()
                            }
                        }
                    }
                    .focusSection()
                }
                .padding(.horizontal, 100)
                .padding(.top, 80)
                .padding(.bottom, 80)
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct TVOSPickerOptionRow: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(
                    cornerRadius: TVOSSettingsLayout.rowCornerRadius,
                    style: .continuous
                )
                .fill(AppTheme.Colors.surface)
            )
        }
        .buttonStyle(.card)
    }
}

// MARK: - Source Status Row (read-only)

private struct TVOSSourceStatusRow: View {
    let service: ProfileService

    var body: some View {
        TVOSSettingsRowShell(isInteractive: false) {
            HStack(spacing: 22) {
                Image(systemName: iconName)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                    .frame(width: TVOSSettingsLayout.iconWidth, alignment: .leading)

                Text(service.name)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                TVOSStatusBadge(isEnabled: service.enabled)
            }
        }
    }

    private var iconName: String {
        switch service.inputType.lowercased() {
        case "bool": return "switch.2"
        case "string": return "key.fill"
        default: return "server.rack"
        }
    }
}

private struct TVOSStatusBadge: View {
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isEnabled ? AppTheme.Colors.success : Color.white.opacity(0.25))
                .frame(width: 12, height: 12)

            Text(isEnabled ? "Enabled" : "Disabled")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(
                    isEnabled
                        ? AppTheme.Colors.elementWhite
                        : AppTheme.Colors.elementMuted
                )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(
                    isEnabled
                        ? AppTheme.Colors.success.opacity(0.12)
                        : Color.white.opacity(0.04)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            isEnabled
                                ? AppTheme.Colors.success.opacity(0.35)
                                : AppTheme.Colors.border,
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Info Row (empty states)

private struct TVOSSettingsInfoRow: View {
    let icon: String
    let message: String

    var body: some View {
        TVOSSettingsRowShell(isInteractive: false) {
            HStack(spacing: 22) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.elementMuted)
                    .frame(width: TVOSSettingsLayout.iconWidth, alignment: .leading)

                Text(message)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.elementSubtle)

                Spacer(minLength: 0)
            }
        }
    }
}

#endif
