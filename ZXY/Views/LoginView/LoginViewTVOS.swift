//
//  LoginViewTVOS.swift
//
//  tvOS-native login & signup — focus-driven, 10-foot UI.
//

import SwiftUI

#if os(tvOS)

struct LoginViewTVOS: View {
    private var vm: LoginViewModel

    init(authUc: AuthUsecase) {
        vm = LoginViewModel(authUc: authUc)
    }

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var primaryActionEnabled: Bool {
        guard !email.isEmpty, !password.isEmpty else { return false }
        if vm.isSignup { return !name.isEmpty && !confirmPassword.isEmpty }
        return true
    }

    var body: some View {
        ZStack {
            TVOSBackdrop()

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: topInset(for: proxy.size.height))

                        VStack(spacing: vm.isSignup ? 40 : 56) {
                            hero
                            form
                        }
                        .frame(maxWidth: 820)
                        .padding(.horizontal, 80)

                        Spacer(minLength: 48)

                        footer
                            .padding(.bottom, 60)
                    }
                    .frame(minHeight: proxy.size.height)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func topInset(for height: CGFloat) -> CGFloat {
        vm.isSignup ? 48 : max(height * 0.12, 60)
    }

    private var hero: some View {
        VStack(spacing: vm.isSignup ? 20 : 28) {
            TVOSAppMark(size: vm.isSignup ? 88 : 120)

            VStack(spacing: 12) {
                Text(vm.isSignup ? "Create your account" : "Welcome back")
                    .font(TVOSTypography.heroTitle)
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                    .multilineTextAlignment(.center)

                Text(
                    vm.isSignup
                        ? "Sign up to start watching on Apple TV."
                        : "Sign in to continue watching."
                )
                .font(TVOSTypography.heroSubtitle)
                .foregroundStyle(AppTheme.Colors.elementSubtle)
                .multilineTextAlignment(.center)
            }
        }
    }

    private var form: some View {
        VStack(spacing: vm.isSignup ? 20 : 28) {
            VStack(spacing: vm.isSignup ? 16 : 24) {
                if vm.isSignup {
                    TVOSTextField(label: "Name", text: $name)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                TVOSTextField(label: "Email", text: $email)

                TVOSTextField(label: "Password", text: $password, isSecure: true)

                if vm.isSignup {
                    TVOSTextField(
                        label: "Confirm Password",
                        text: $confirmPassword,
                        isSecure: true
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.85), value: vm.isSignup)

            if let err = vm.err {
                TVOSErrorBanner(message: err)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            TVOSPrimaryButton(
                title: vm.isSignup ? "Create Account" : "Sign In",
                isLoading: vm.isLoading
            ) {
                Task {
                    if vm.isSignup {
                        await vm.signup(
                            name: name,
                            email: email,
                            pwd: password,
                            confirmPwd: confirmPassword
                        )
                    } else {
                        await vm.login(email: email, pwd: password)
                    }
                }
            }
            .opacity(primaryActionEnabled || vm.isLoading ? 1 : 0.55)
            .disabled(!primaryActionEnabled || vm.isLoading)
        }
        .animation(.easeInOut(duration: 0.2), value: vm.err)
        .focusSection()
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(vm.isSignup ? "Already have an account?" : "New here?")
                .font(TVOSTypography.caption)
                .foregroundStyle(AppTheme.Colors.elementMuted)

            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    vm.isSignup.toggle()
                    vm.err = nil
                }
            } label: {
                Text(vm.isSignup ? "Sign in" : "Create an account")
                    .font(TVOSTypography.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.elementWhite)
            }
            .buttonStyle(.card)
        }
    }
}

#endif
