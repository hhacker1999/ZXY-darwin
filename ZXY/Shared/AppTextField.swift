import SwiftUI

struct AppTextField: View {
    let icon: String
    let placeholder: String
    let isSecure: Bool
    @Binding var text: String

    @FocusState private var focused: Bool
    @State private var showText = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(
                    focused
                        ? AppTheme.Colors.elementWhite
                        : AppTheme.Colors.elementMuted
                )
                .frame(width: 20)
                .animation(.easeInOut(duration: 0.2), value: focused)

            Group {
                if isSecure && !showText {
                    SecureField("", text: $text)
                        .focused($focused)
                } else {
                    TextField("", text: $text)
                        .focused($focused)
                        #if os(iOS)
                            .keyboardType(isSecure ? .default : .emailAddress)
                            .textInputAutocapitalization(.never)  // Use this modern modifier instead of .autocapitalization
                            .autocorrectionDisabled()
                        #endif
                }
            }
            .placeholder(when: text.isEmpty) {
                Text(placeholder)
                    .foregroundColor(AppTheme.Colors.elementPlaceholder)
                    .font(AppTheme.Typography.bodyMedium)
            }
            .font(AppTheme.Typography.bodyMedium)
            .foregroundColor(AppTheme.Colors.elementWhite)
            .tint(AppTheme.Colors.elementWhite)

            if isSecure {
                Button {
                    showText.toggle()
                } label: {
                    Image(systemName: showText ? "eye.slash" : "eye")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.elementMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .fill(
                        focused
                            ? AppTheme.Colors.surfaceHovered
                            : AppTheme.Colors.surface
                    )
                    .animation(.easeInOut(duration: 0.2), value: focused)

                RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                    .stroke(
                        focused
                            ? AppTheme.Colors.borderFocused
                            : AppTheme.Colors.border,
                        lineWidth: focused ? 1.5 : 1
                    )
                    .animation(.easeInOut(duration: 0.2), value: focused)
            }
        )
        // Subtle white glow when focused
        .shadow(
            color: focused
                ? AppTheme.Colors.elementWhite.opacity(0.07) : .clear,
            radius: 12,
            x: 0,
            y: 0
        )
        .animation(.easeInOut(duration: 0.2), value: focused)
    }
}
