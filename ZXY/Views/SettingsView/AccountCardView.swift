//
//  AccountCardView.swift
//
//  Account info + Switch profile / Trakt / Logout / Delete actions.
//

import SwiftUI

struct AccountCardView: View {
    let profile: Profile
    let waitingTraktLogin: Bool
    let onSwitchProfile: () -> Void
    let onLogout: () -> Void
    let onDeleteAccount: (() -> Void)?
    let onTraktLogin: () -> Void
    let onTraktLogout: () -> Void

    @State private var showDeleteConfirm = false
    @State private var showLogoutConfirm = false

    var body: some View {
        SettingsCard {
            profileHeader
            divider
            AccountActionRow(
                icon: "person.2.fill",
                label: "Switch Profile",
                action: onSwitchProfile
            )
            divider
            traktRow
            divider
            AccountActionRow(
                icon: "rectangle.portrait.and.arrow.right",
                label: "Log Out",
                isDestructive: true,
                action: { showLogoutConfirm = true }
            )

            if let onDeleteAccount {
                divider
                AccountActionRow(
                    icon: "trash.fill",
                    label: "Delete Account",
                    isDestructive: true,
                    action: { showDeleteConfirm = true }
                )

                Color.clear.frame(height: 0).alert(
                    "Delete Account",
                    isPresented: $showDeleteConfirm
                ) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive, action: onDeleteAccount)
                } message: {
                    Text("This will permanently delete your account and all associated data. This action cannot be undone.")
                }
            }
        }
        .alert("Log out?", isPresented: $showLogoutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive, action: onLogout)
        }
    }

    private var profileHeader: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            SettingsProfileAvatar(name: profile.name, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.elementWhite)

                if profile.isAdmin {
                    Text("Admin")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                }
            }

            Spacer()
        }
        .padding(AppTheme.Spacing.md)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
    }

    @ViewBuilder
    private var traktRow: some View {
        if waitingTraktLogin {
            HStack(spacing: AppTheme.Spacing.md) {
                ProgressView().tint(AccountCardView.traktRed)
                Text("Waiting for Trakt login…")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
                Spacer()
            }
            .padding(AppTheme.Spacing.md)
        } else if profile.traktValid {
            TraktConnectedRow(onLogout: onTraktLogout)
        } else {
            TraktLoginRow(
                label: profile.traktExpiry != nil ? "Re-login with Trakt" : "Login with Trakt",
                onTap: onTraktLogin
            )
        }
    }

    static let traktRed = Color(hex: "#ED1C24")
}

struct AccountActionRow: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        isDestructive ? AppTheme.Colors.error : AppTheme.Colors.elementWhite
                    )
                    .frame(width: 22)

                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        isDestructive ? AppTheme.Colors.error : AppTheme.Colors.elementWhite
                    )

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.elementMuted)
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(hovered ? Color.white.opacity(0.04) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct TraktConnectedRow: View {
    let onLogout: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            traktBadge

            VStack(alignment: .leading, spacing: 2) {
                Text("Trakt")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.elementWhite)

                HStack(spacing: 5) {
                    Circle()
                        .fill(AppTheme.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("Connected")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                }
            }

            Spacer()

            Button(action: onLogout) {
                Text("Logout")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AccountCardView.traktRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AccountCardView.traktRed.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AccountCardView.traktRed.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(AppTheme.Spacing.md)
    }

    private var traktBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AccountCardView.traktRed.opacity(0.12))
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AccountCardView.traktRed.opacity(0.3), lineWidth: 1)
            Circle()
                .fill(AccountCardView.traktRed)
                .frame(width: 18, height: 18)
                .overlay(
                    Text("T")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                )
        }
        .frame(width: 32, height: 32)
    }
}

private struct TraktLoginRow: View {
    let label: String
    let onTap: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AccountCardView.traktRed.opacity(0.10))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AccountCardView.traktRed.opacity(0.2), lineWidth: 1)
                    Circle()
                        .fill(AccountCardView.traktRed)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text("T")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(.white)
                        )
                }
                .frame(width: 32, height: 32)

                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.elementWhite)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.elementMuted)
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(hovered ? Color.white.opacity(0.04) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
