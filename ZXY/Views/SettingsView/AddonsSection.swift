import SwiftUI

struct AddonsSection: View {
    let addons: [StreamAddon]
    let onToggle: (Int, Bool) -> Void

    var body: some View {
        if addons.isEmpty {
            SettingsCard {
                Text("No addons available for this profile.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
                    .padding(AppTheme.Spacing.md)
            }
        } else {
            VStack(spacing: AppTheme.Spacing.md) {
                ForEach(addons) { addon in
                    AddonCard(
                        addon: addon,
                        onToggle: { enabled in
                            onToggle(addon.profileAddon.id, enabled)
                        }
                    )
                }
            }
        }
    }
}

private struct AddonCard: View {
    let addon: StreamAddon
    let onToggle: (Bool) -> Void

    private var logoURL: URL? {
        let logo = addon.addonManifest.logo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !logo.isEmpty else { return nil }
        return URL(string: logo)
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

                    Toggle("", isOn: Binding(
                        get: { addon.profileAddon.enabled },
                        set: { onToggle($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(AppTheme.Colors.success)
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
}
