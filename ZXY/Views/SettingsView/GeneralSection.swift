
import SwiftUI

struct GeneralSection: View {
    @Bindable var bloc: SettingsBloc

    private var languageOptions: [String] {
        let langs = LangHelper.iso6391List.map { $0.1 }.sorted()
        return langs
    }

    private var subtitleLanguageOptions: [String] {
        ["None"] + LangHelper.iso6391List.map { $0.1 }.sorted()
    }

    var body: some View {
        SettingsCard {
            // ── Language ─────────────────────────────────────────
            SettingsPickerRow(
                icon: "globe",
                label: "Default Language",
                helper: "Used for default stream language",
                selection: $bloc.language,
                options: languageOptions
            )
            sectionDivider

            // ── Subtitle language ────────────────────────────────
            SettingsPickerRow(
                icon: "captions.bubble",
                label: "Default Subtitle Language",
                helper: nil,
                selection: $bloc.subtitleLanguage,
                options: subtitleLanguageOptions
            )
            sectionDivider

            // ── Resolution ───────────────────────────────────────
            SettingsPickerRow(
                icon: "tv.fill",
                label: "Preferred Resolution",
                helper: "Highest acceptable quality on stream selection",
                selection: $bloc.resolution,
                options: SettingsBloc.resolutions
            )
            sectionDivider

            // ── Skip duration ────────────────────────────────────
            SettingsPickerRow(
                icon: "goforward",
                label: "Skip Duration",
                helper: "Seconds to skip with the player skip controls",
                selection: Binding(
                    get: { String(bloc.skipDuration) },
                    set: { bloc.skipDuration = Int($0) ?? bloc.skipDuration }
                ),
                options: SettingsBloc.skipDurationOptions.map(String.init),
                displayLabel: { "\($0)s" }
            )
            sectionDivider

            // // ── AMOLED theme ─────────────────────────────────────
            // SettingsToggleRow(
            //     icon: "moon.fill",
            //     label: "AMOLED Theme",
            //     helper: "Use pure black backgrounds",
            //     isOn: $bloc.isAmoled
            // )
            // sectionDivider

            // ── Poster ratings ───────────────────────────────────
            // SettingsToggleRow(
            //     icon: "star.fill",
            //     label: "Show Poster Ratings",
            //     helper: "Display IMDb ratings on poster cards",
            //     isOn: $bloc.showPosterRatings
            // )
            // sectionDivider

            // ── Formatted streams ────────────────────────────────
            // SettingsToggleRow(
            //     icon: "list.bullet.rectangle.portrait",
            //     label: "Formatted Stream List",
            //     helper: "Use compact, parsed stream titles",
            //     isOn: $bloc.showFormattedStreams
            // )
            // sectionDivider

            // ── Auto select best stream ──────────────────────────
            SettingsToggleRow(
                icon: "wand.and.stars",
                label: "Auto-Select Best Stream",
                helper: "Pick the highest matching stream automatically",
                isOn: $bloc.autoSelectBestStream
            )
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let label: String
    let helper: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                if let helper {
                    Text(helper)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.elementMuted)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(AppTheme.Colors.success)
        }
        .padding(AppTheme.Spacing.md)
    }
}

struct SettingsPickerRow: View {
    let icon: String
    let label: String
    let helper: String?
    @Binding var selection: String
    let options: [String]
    var displayLabel: (String) -> String = { $0 }

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                if let helper {
                    Text(helper)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.elementMuted)
                }
            }

            Spacer()

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        if option == selection {
                            Label(displayLabel(option), systemImage: "checkmark")
                        } else {
                            Text(displayLabel(option))
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(displayLabel(selection))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.elementWhite)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(AppTheme.Spacing.md)
    }
}
