//
//  SlideRevealButton.swift
//  MrFor
//
//  A reusable "spatial" slide-to-confirm control: a square knob (filled with
//  the brand's deep teal + a soft stroke) sits on the left of a cream track.
//  Dragging the knob from left to right — a deliberate swipe, not a tap —
//  reveals the fill underneath; releasing past the threshold pops the knob
//  with a little "bubble" bounce and fires the action. Releasing early snaps
//  the knob back with the same springy bounce.
//

import SwiftUI

struct SlideRevealButton: View {
    let title: String
    let systemImage: String
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var dragX: CGFloat = 0
    @GestureState private var liveTranslation: CGFloat = 0
    @State private var isCompleting = false
    @State private var knobScale: CGFloat = 1
    @State private var shimmerPhase: CGFloat = -0.6

    private let knobSize: CGFloat = 46
    private let knobWidth: CGFloat = 60
    private let trackHeight: CGFloat = 66
    private let inset: CGFloat = 5
    private let completionThreshold: CGFloat = 0.68

    var body: some View {
        GeometryReader { geo in
            let travel = max(geo.size.width - knobSize - inset * 2, 0)
            let rawX = dragX + liveTranslation
            let knobX = min(max(rawX, 0), travel)
            let progress = travel > 0 ? knobX / travel : 0
            let isLiveDragging = liveTranslation != 0

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(AppTheme.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                            .strokeBorder(AppTheme.secondary.opacity(0.2), lineWidth: 1.5)
                    )

                // Smooth skeleton shimmer sweeping left to right across the whole button —
                // a gentle, warm highlight that stays soft and easy on the eye.
                LinearGradient(
                    colors: [
                        .clear,
                        AppTheme.secondary.opacity(0.10),
                        Color.white.opacity(0.2),
                        AppTheme.secondary.opacity(0.10),
                        .clear
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.4)
                .offset(x: shimmerPhase * geo.size.width)
                .frame(width: geo.size.width, height: trackHeight, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous))
                .opacity(isCompleting ? 0 : 1)
                .allowsHitTesting(false)

                // Fill that reveals as the knob travels right
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(AppTheme.secondary.opacity(0.08 + 0.14 * progress))
                    .frame(width: knobX + knobSize)

                // Label, fades out as the knob covers it
                HStack {
                    Spacer(minLength: knobSize + 10)
                    Text(isCompleting ? "Charging…" : title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.secondary.opacity(1 - 0.7 * progress))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 10)
                }

                // The square knob
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppTheme.primary.opacity(0.55), lineWidth: 1.5)
                    )
                    .frame(width: knobWidth, height: knobSize)
                    .overlay(
                        Image(systemName: isCompleting ? "checkmark" : "chevron.right.dotted.chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.primary)
                            .symbolEffect(.wiggle, options: .repeat(.continuous), isActive: !isCompleting)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    .scaleEffect(isCompleting ? knobScale : (isLiveDragging ? 1.1 : 1))
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isLiveDragging)
                    .padding(.leading, inset)
                    .offset(x: knobX)
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .updating($liveTranslation) { value, state, _ in
                                guard !isDisabled, !isCompleting else { return }
                                state = value.translation.width
                            }
                            .onEnded { value in
                                guard !isDisabled, !isCompleting else { return }
                                let finalX = min(max(dragX + value.translation.width, 0), travel)
                                if travel > 0, finalX / travel > completionThreshold {
                                    complete(travel: travel)
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                                        dragX = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: trackHeight)
        .opacity(isDisabled ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.6
            }
        }
    }

    private func complete(travel: CGFloat) {
        isCompleting = true
        withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
            dragX = travel
            knobScale = 1.22
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
                knobScale = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            action()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                dragX = 0
            }
            isCompleting = false
        }
    }
}

#Preview {
    ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 20) {
            SlideRevealButton(title: "Test charge (sandbox card)", systemImage: "creditcard.and.123") {}
            SlideRevealButton(title: "Disabled", systemImage: "bolt.fill", isDisabled: true) {}
        }
        .padding(.horizontal, 24)
    }
}
