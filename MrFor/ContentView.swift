//
//  ContentView.swift
//  MrFor
//
//  Created by Aijaz Ali on 08/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var showingCheckout = false
    @State private var outcome: CheckoutOutcome?

    private let amount: Decimal = 25.00
    private let orderNumber = "evt-1001"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Desert Rose Festival")
                        .font(.title2.weight(.semibold))
                    Text("General admission · 1 ticket")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(amount, format: .currency(code: "USD"))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .padding(.top, 8)
                }

                Button("Checkout") { showingCheckout = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                if let outcome {
                    resultBanner(outcome)
                }
            }
            .padding()
            .navigationTitle("Event Explore")
        }
        .sheet(isPresented: $showingCheckout) {
            NavigationStack {
                ForteCheckoutView(amount: amount, orderNumber: orderNumber) { result in
                    outcome = result
                    showingCheckout = false
                }
                .navigationTitle("Payment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            outcome = .cancelled
                            showingCheckout = false
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resultBanner(_ outcome: CheckoutOutcome) -> some View {
        switch outcome {
        case .approved(let txn):
            label("Payment approved", detail: txn.map { "Transaction \($0)" }, tint: .green, icon: "checkmark.circle.fill")
        case .cancelled:
            label("Cancelled", detail: "No charge was made.", tint: .secondary, icon: "xmark.circle.fill")
        case .failed(let message):
            label("Payment failed", detail: message, tint: .red, icon: "exclamationmark.triangle.fill")
        }
    }

    private func label(_ title: String, detail: String?, tint: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Label(title, systemImage: icon).foregroundStyle(tint).font(.headline)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(tint.opacity(0.1), in: .rect(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
}
