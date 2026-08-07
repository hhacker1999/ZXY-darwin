import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct AddonsSection: View {
    let addons: [StreamAddon]
    let onToggle: (Int, Bool) -> Void
    let onAdd: (String) -> Void
    let onRemove: (Int) -> Void

    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            addAddonButton

            if addons.isEmpty {
                SettingsCard {
                    Text("No addons available for this profile.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                        .padding(AppTheme.Spacing.md)
                }
            } else {
                ForEach(addons) { addon in
                    AddonCard(
                        addon: addon,
                        onToggle: { enabled in
                            onToggle(addon.profileAddon.id, enabled)
                        },
                        onRemove: {
                            onRemove(addon.profileAddon.id)
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddAddonDialog(
                onAdd: { url in
                    onAdd(url)
                    showAddSheet = false
                },
                onCancel: { showAddSheet = false }
            )
        }
    }

    private var addAddonButton: some View {
        Button {
            showAddSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Add Addon")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(AppTheme.Colors.buttonPrimaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.Colors.buttonPrimary)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AddonCard: View {
    let addon: StreamAddon
    let onToggle: (Bool) -> Void
    let onRemove: () -> Void

    @Environment(\.openURL) private var openURL

    private var logoURL: URL? {
        let logo = addon.addonManifest.logo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !logo.isEmpty else { return nil }
        return URL(string: logo)
    }

    private var isConfigurable: Bool {
        addon.addonManifest.behaviorHints.configurable
    }

    private var configureURL: URL? {
        let manifestUrl = addon.profileAddon.manifestUrl
        guard let range = manifestUrl.range(
            of: "/manifest.json",
            options: [.backwards, .caseInsensitive]
        ) else { return nil }
        let configureUrl = manifestUrl.replacingCharacters(in: range, with: "/configure")
        return URL(string: configureUrl)
    }

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    if let logoURL {
                        AsyncImage(url: logoURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                addonLogoPlaceholder
                            default:
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(AppTheme.Colors.elementMuted)
                            }
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(addon.addonManifest.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.elementWhite)
                            .lineLimit(2)

                        Text("Version \(addon.addonManifest.version)")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.elementMuted)
                    }

                    Spacer(minLength: AppTheme.Spacing.sm)

                    HStack(spacing: AppTheme.Spacing.sm) {
                        if isConfigurable {
                            Button {
                                if let configureURL {
                                    openURL(configureURL)
                                }
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.Colors.elementWhite)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(configureURL == nil)
                            #if os(macOS)
                            .help("Configure addon")
                            #endif
                        }

                        Button {
                            copyManifestURL()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.elementWhite)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        #if os(macOS)
                        .help("Copy manifest URL")
                        #endif

                        Button(action: onRemove) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.error)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        #if os(macOS)
                        .help("Remove addon")
                        #endif

                        Toggle("", isOn: Binding(
                            get: { addon.profileAddon.enabled },
                            set: { onToggle($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(AppTheme.Colors.success)
                    }
                }

                if !addon.addonManifest.description.isEmpty {
                    Text(addon.addonManifest.description)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
    }

    private var addonLogoPlaceholder: some View {
        Image(systemName: "puzzlepiece.extension.fill")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(AppTheme.Colors.elementMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyManifestURL() {
        let url = addon.profileAddon.manifestUrl
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = url
        #endif
        ToastProgressBloc.bloc.showToast(message: "Manifest URL copied", isError: false)
    }
}

private struct AddAddonDialog: View {
    let onAdd: (String) -> Void
    let onCancel: () -> Void

    @State private var inputText: String = ""

    private var trimmed: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Addon")
                    .font(AppTheme.Typography.headingMedium)
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                Text("Enter the addon manifest URL")
                    .font(AppTheme.Typography.bodySmall)
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
            }

            TextField("https://…/manifest.json", text: $inputText)
                .textFieldStyle(.plain)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundStyle(AppTheme.Colors.elementWhite)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                #endif
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            HStack(spacing: AppTheme.Spacing.sm) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(AppTheme.Typography.labelMedium)
                        .foregroundStyle(AppTheme.Colors.elementWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    guard !trimmed.isEmpty else { return }
                    onAdd(trimmed)
                } label: {
                    Text("Add")
                        .font(AppTheme.Typography.labelMedium)
                        .foregroundStyle(AppTheme.Colors.buttonPrimaryLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.Colors.buttonPrimary)
                        )
                }
                .buttonStyle(.plain)
                .disabled(trimmed.isEmpty)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(minWidth: 360)
        .background(AppTheme.Colors.backgroundTertiary)
        .preferredColorScheme(.dark)
    }
}
