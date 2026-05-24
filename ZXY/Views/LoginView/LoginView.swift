//
//  LoginView.swift
//
//  Created by Harsh Kumar on 28/03/26.
//

import SwiftUI

struct LoginView: View {
    private var vm: LoginViewModel

    init(authUc: AuthUsecase) {
        vm = LoginViewModel(authUc: authUc)
    }

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var appeared = false

    private var primaryActionEnabled: Bool {
        guard !email.isEmpty, !password.isEmpty else { return false }
        if vm.isSignup { return !confirmPassword.isEmpty }
        return true
    }

    var body: some View {
        #if os(tvOS)
        LoginViewTVOS(authUc: vm.authUc)
        #else
        defaultBody
        #endif
    }

    private var defaultBody: some View {
        GeometryReader { proxy in
            ZStack {
                LoginBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: max(proxy.size.height * 0.1, 40))

                        VStack(spacing: 40) {
                            hero
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : -14)

                            form
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 18)
                        }
                        .frame(maxWidth: 380)
                        .padding(.horizontal, AppTheme.Spacing.lg)

                        Spacer(minLength: 40)

                        footer
                            .opacity(appeared ? 1 : 0)
                    }
                    .frame(minHeight: proxy.size.height)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 22) {
            AppMark()

            VStack(spacing: 8) {
                Text(vm.isSignup ? "Create your account" : "Welcome back")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(
                    vm.isSignup
                        ? "Sign up to start watching."
                        : "Sign in to continue watching."
                )
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
            }
        }
    }

    private var form: some View {
        VStack(spacing: 18) {
            LoginFieldGroup {
                if vm.isSignup {
                    LoginField(
                        placeholder: "Enter Name",
                        text: $name,
                        kind: .text
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(
                                with: .move(edge: .top)
                            ),
                            removal: .opacity
                        )
                    )
                    LoginFieldDivider()
                }
                LoginField(
                    placeholder: "Email",
                    text: $email,
                    kind: .email
                )

                LoginFieldDivider()

                LoginField(
                    placeholder: "Password",
                    text: $password,
                    kind: .password
                )

                if vm.isSignup {
                    LoginFieldDivider()

                    LoginField(
                        placeholder: "Confirm password",
                        text: $confirmPassword,
                        kind: .password
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(
                                with: .move(edge: .top)
                            ),
                            removal: .opacity
                        )
                    )
                }
            }
            .animation(
                .spring(response: 0.38, dampingFraction: 0.85),
                value: vm.isSignup
            )

            if let err = vm.err {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 1)
                    Text(err)
                        .font(.system(size: 13, weight: .regular))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(AppTheme.Colors.error)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.error.opacity(0.10))
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 12,
                                style: .continuous
                            )
                            .stroke(
                                AppTheme.Colors.error.opacity(0.35),
                                lineWidth: 1
                            )
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            PrimaryButton(
                title: vm.isSignup ? "Create Account" : "Sign In",
                isLoading: vm.isLoading
            ) {
                Task {
                    if vm.isSignup {
                        await vm.signup(name: name, email: email, pwd: password, confirmPwd: confirmPassword)
                    } else {
                        await vm.login(email: email, pwd: password)
                    }
                }
            }
            .opacity(primaryActionEnabled || vm.isLoading ? 1 : 0.5)
            .disabled(!primaryActionEnabled || vm.isLoading)
            .animation(.easeInOut(duration: 0.18), value: primaryActionEnabled)
        }
        .animation(.easeInOut(duration: 0.2), value: vm.err)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(vm.isSignup ? "Already have an account?" : "New here?")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))

            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    vm.isSignup.toggle()
                }
            } label: {
                Text(vm.isSignup ? "Sign in" : "Create an account")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 28)
    }
}

private struct LoginBackdrop: View {
    var body: some View {
        ZStack {
            Color(hex: "#070707").ignoresSafeArea()

            // Soft top spotlight
            RadialGradient(
                colors: [
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.03),
                    Color.clear,
                ],
                center: .init(x: 0.5, y: -0.08),
                startRadius: 0,
                endRadius: 560
            )
            .ignoresSafeArea()

            // Faint bottom lift
            RadialGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear,
                ],
                center: .init(x: 0.5, y: 1.15),
                startRadius: 0,
                endRadius: 440
            )
            .ignoresSafeArea()
        }
    }
}

private struct AppMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .frame(width: 78, height: 78)

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.7),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 12)
        .shadow(color: Color.white.opacity(0.08), radius: 24, x: 0, y: 0)
    }
}

private struct LoginFieldGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.35), radius: 22, x: 0, y: 12)
    }
}

private struct LoginFieldDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 18)
    }
}

private enum LoginFieldKind {
    case email
    case password
    case text
}

private struct LoginField: View {
    let placeholder: String
    @Binding var text: String
    let kind: LoginFieldKind

    @FocusState private var focused: Bool
    @State private var reveal = false

    private var isSecure: Bool {
        kind == .password
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .allowsHitTesting(false)
                }

                Group {
                    if isSecure && !reveal {
                        SecureField("", text: $text)
                            .focused($focused)
                    } else {
                        TextField("", text: $text)
                            .focused($focused)
                        #if os(iOS)
                            .keyboardType(
                                kind == .email ? .emailAddress : .default
                            )
                            .textContentType(
                                kind == .email ? .emailAddress : .none
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        #endif
                    }
                }
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white)
                .tint(.white)
                .accentColor(.white)
                .textFieldStyle(.plain)
            }

            if isSecure && !text.isEmpty {
                Button {
                    reveal.toggle()
                } label: {
                    Image(systemName: reveal ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            focused
                                ? Color.white.opacity(0.85)
                                : Color.white.opacity(0.45)
                        )
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.white.opacity(focused ? 0.05 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .animation(.easeInOut(duration: 0.18), value: focused)
        .animation(.easeInOut(duration: 0.15), value: reveal)
    }
}

#Preview {
    LoginView(authUc: AuthUsecase())
}
