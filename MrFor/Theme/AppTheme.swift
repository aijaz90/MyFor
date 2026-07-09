//
//  AppTheme.swift
//  MrFor
//
//  Single source of truth for the app's color theme, gradients, and shared
//  button/card styling ("Spatial UI"). Colors are dynamic — they live in
//  Assets.xcassets (`BrandPrimary`, `BrandSecondary`) rather than being
//  hard-coded, so every screen stays in sync and dark/light variants can be
//  tuned in one place.
//

import SwiftUI

enum AppTheme {
    /// Warm cream — #FFEFB3. Elevated surfaces and text that sits on `secondary`.
    static let primary = Color("BrandPrimary")
    /// Deep teal — #013E37. The app's anchor color for backgrounds & headline text.
    static let secondary = Color("BrandSecondary")

    /// Full-screen backdrop gradient used across Payment & Receipt.
    static let backgroundGradient = LinearGradient(
        colors: [secondary, secondary.opacity(0.94), secondary.opacity(0.8)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Directional accent gradient for filled controls (buttons, progress fills).
    static let accentGradient = LinearGradient(
        colors: [secondary, secondary.opacity(0.8)],
        startPoint: .leading, endPoint: .trailing
    )
}

/// Gentle press feedback shared by every button in the app — scales and dims
/// the label so controls feel tactile without changing what they do.
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

/// A floating, layered "spatial" surface: soft depth via shadow + hairline
/// border, reused for cards on the Payment and Receipt screens.
struct SpatialCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var fill: Color = AppTheme.primary
    var borderOpacity: Double = 0.08
    var shadowOpacity: Double = 0.22

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.secondary.opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(color: .black.opacity(shadowOpacity), radius: 18, y: 10)
    }
}

extension View {
    func spatialCard(cornerRadius: CGFloat = 24, fill: Color = AppTheme.primary,
                      borderOpacity: Double = 0.08, shadowOpacity: Double = 0.22) -> some View {
        modifier(SpatialCard(cornerRadius: cornerRadius, fill: fill,
                              borderOpacity: borderOpacity, shadowOpacity: shadowOpacity))
    }
}
