//
//  PaymentAlertView.swift
//  MrFor
//
//  A modern success / failure popup with a single OK button, shown after the
//  DynaFlex payment API responds. Animated, theme-styled, dims the screen behind.
//

import SwiftUI

struct PaymentAlert: Identifiable, Equatable {
    let id = UUID()
    let isSuccess: Bool
    let title: String
    let message: String

    static func success(_ title: String, _ message: String) -> PaymentAlert {
        PaymentAlert(isSuccess: true, title: title, message: message)
    }
    static func failure(_ title: String, _ message: String) -> PaymentAlert {
        PaymentAlert(isSuccess: false, title: title, message: message)
    }
}

struct PaymentAlertView: View {
    let alert: PaymentAlert
    let onDismiss: () -> Void

    @State private var shown = false

    private var tint: Color {
        alert.isSuccess ? Color(red: 0.05, green: 0.55, blue: 0.34)
                        : Color(red: 0.83, green: 0.24, blue: 0.24)
    }
    private var icon: String { alert.isSuccess ? "checkmark" : "xmark" }

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.5 : 0)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(tint.opacity(0.12)).frame(width: 100, height: 100)
                    Circle().fill(tint.opacity(0.22)).frame(width: 76, height: 76)
                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(tint)
                }
                .scaleEffect(shown ? 1 : 0.4)
                .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.05), value: shown)

                Text(alert.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.secondary)
                    .multilineTextAlignment(.center)

                Text(alert.message)
                    .font(.callout)
                    .foregroundStyle(AppTheme.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: dismiss) {
                    Text("OK")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(BouncyButtonStyle())
                .padding(.top, 6)
            }
            .padding(26)
            .frame(maxWidth: 330)
            .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(AppTheme.secondary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 30, y: 16)
            .scaleEffect(shown ? 1 : 0.85)
            .opacity(shown ? 1 : 0)
            .padding(.horizontal, 32)
        }
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { shown = true } }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.16)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: onDismiss)
    }
}

#Preview {
    ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        PaymentAlertView(alert: .success("Payment Successful", "DynaFlex payment completed successfully.")) {}
    }
}
