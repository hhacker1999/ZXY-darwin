import SwiftUI

struct SourcesSection: View {
    let profile: Profile
    @Bindable var vm: SettingsViewModel
    @State private var configuringService: ProfileService?

    var body: some View {
        SettingsCard {
            if profile.services.isEmpty {
                Text("No sources available for this profile.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
                    .padding(AppTheme.Spacing.md)
            } else {
                ForEach(Array(profile.services.enumerated()), id: \.element.id) { index, service in
                    ServiceRow(
                        service: service,
                        onToggle: { newValue in
                            handleToggle(service: service, enable: newValue)
                        }
                    )

                    if index < profile.services.count - 1 {
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                    }
                }
            }
        }
        .sheet(item: $configuringService) { service in
            ServiceValueDialog(
                service: service,
                onSave: { value in
                    Task { await vm.updateSource(type: service.id, value: value, enabled: true) }
                    configuringService = nil
                },
                onCancel: { configuringService = nil }
            )
        }
    }

    private func handleToggle(service: ProfileService, enable: Bool) {
        if !enable {
            Task { await vm.updateSource(type: service.id, enabled: false) }
            return
        }

        switch service.inputType.lowercased() {
        case "bool":
            Task { await vm.updateSource(type: service.id, enabled: true) }
        default:
            // `string` (and any unknown input types) need a value before we
            // can enable them — collect it via the dialog.
            configuringService = service
        }
    }
}

private struct ServiceRow: View {
    let service: ProfileService
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: iconForInputType(service.inputType))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                Text(service.enabled ? "Enabled" : "Not configured")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.elementMuted)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { service.enabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(AppTheme.Colors.success)
        }
        .padding(AppTheme.Spacing.md)
    }

    private func iconForInputType(_ type: String) -> String {
        switch type.lowercased() {
        case "bool": return "switch.2"
        case "string": return "key.fill"
        default: return "server.rack"
        }
    }
}

private struct ServiceValueDialog: View {
    let service: ProfileService
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var inputText: String = ""
    @State private var revealText: Bool = false

    private var trimmed: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(AppTheme.Typography.headingMedium)
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                Text("Enter api key")
                    .font(AppTheme.Typography.bodySmall)
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
            }

            HStack(spacing: 8) {
                Group {
                    if revealText {
                        TextField("Value", text: $inputText)
                    } else {
                        SecureField("Value", text: $inputText)
                    }
                }
                .textFieldStyle(.plain)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundStyle(AppTheme.Colors.elementWhite)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

                Button {
                    revealText.toggle()
                } label: {
                    Image(systemName: revealText ? "eye.slash" : "eye")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                }
                .buttonStyle(.plain)
            }
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
                    onSave(trimmed)
                } label: {
                    Text("Save")
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
