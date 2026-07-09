//
//  PaymentView.swift
//  MrFor
//
//  The payment screen. The amount is editable; a connection pill shows reader
//  status (green/red); the top-right button opens Bluetooth, the gear opens
//  server settings. On a successful charge, a receipt is presented with the
//  transaction's real data fetched from the backend.
//

import SwiftUI

struct PaymentView: View {
    @State private var reader = ReaderEngine()

    @State private var amount: Decimal = 25.00
    @State private var showingBluetooth = false
    @State private var showingSettings = false
    @State private var isCharging = false
    @State private var outcome: PaymentOutcome?

    // Receipt presentation
    @State private var receiptTransactionID: String?
    @State private var chargedAmount: Decimal = 0

    @FocusState private var amountFocused: Bool

    private let orderNumber = "evt-1001"

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    connectionPill
                        .padding(.horizontal).padding(.top, 8)

                    Spacer()

                    VStack(spacing: 6) {
                        Text("Desert Rose Festival")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.primary)
                        Text("General admission")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.primary.opacity(0.7))
                    }

                    amountEditor.padding(.top, 24)

                    if isCharging, let prompt = reader.statusMessage, !prompt.isEmpty {
                        Text(prompt)
                            .font(.callout.weight(.medium)).foregroundStyle(AppTheme.primary.opacity(0.85))
                            .padding(.top, 16)
                            .transition(.opacity)
                    }

                    if let outcome, !isApproved(outcome) {
                        resultBanner(outcome).padding(.top, 24)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer()

                    chargeButton.padding(.horizontal).padding(.bottom, 12)
                }
                .animation(.easeInOut(duration: 0.25), value: outcome == nil)
                .animation(.easeInOut(duration: 0.25), value: isCharging)
            }
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.secondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                        .tint(AppTheme.primary)
                        .accessibilityLabel("Server settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingBluetooth = true } label: {
                        Image(systemName: reader.connectionState.isConnected ? "creditcard.wireless" : "dot.radiowaves.left.and.right")
                            .foregroundStyle(reader.connectionState.isConnected ? Color.green : Color.red)
                    }
                    .accessibilityLabel("Bluetooth reader")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFocused = false }
                }
            }
            .sheet(isPresented: $showingBluetooth) { BluetoothDevicesView(reader: reader) }
            .sheet(isPresented: $showingSettings) { ServerSettingsView() }
            .sheet(item: $receiptTransactionID) { txn in
                ReceiptView(transactionID: txn, fallbackAmount: chargedAmount) {
                    receiptTransactionID = nil
                }
            }
        }
    }

    // MARK: Editable amount

    private var amountEditor: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.secondary.opacity(0.55))
                TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.secondary)
                    .fixedSize()
                    .multilineTextAlignment(.leading)
            }
            Label("Tap to edit amount", systemImage: "pencil")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.secondary.opacity(0.55))
                .opacity(amountFocused ? 0 : 1)
        }
        .padding(.vertical, 22).padding(.horizontal, 30)
        .spatialCard(cornerRadius: 24, shadowOpacity: 0.22)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(amountFocused ? AppTheme.secondary.opacity(0.55) : .clear, lineWidth: 2)
        )
        .padding(.horizontal, 32)
        .scaleEffect(amountFocused ? 1.02 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: amountFocused)
        .onTapGesture { amountFocused = true }
    }

    // MARK: Connection pill

    private var connectionPill: some View {
        HStack(spacing: 8) {
            Circle().fill(reader.connectionState.isConnected ? Color.green : Color.red).frame(width: 10, height: 10)
            Text(reader.connectionState.isConnected
                 ? "Reader connected\(reader.connectedName.map { " · \($0)" } ?? "")"
                 : "No reader connected")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.primary.opacity(reader.connectionState.isConnected ? 1 : 0.8))
            Spacer()
            Button("Bluetooth") { showingBluetooth = true }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderless)
                .foregroundStyle(AppTheme.primary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background((reader.connectionState.isConnected ? Color.green : Color.red).opacity(0.16), in: .capsule)
        .overlay(
            Capsule().strokeBorder(AppTheme.primary.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: Charge

    private var chargeDisabled: Bool { isCharging || !reader.connectionState.isConnected || amount <= 0 }
    private var testChargeDisabled: Bool { isCharging || amount <= 0 }

    private var chargeButton: some View {
        VStack(spacing: 12) {
            Button {
                amountFocused = false
                Task { await charge() }
            } label: {
                HStack(spacing: 10) {
                    if isCharging {
                        ProgressView().tint(AppTheme.primary)
                    } else {
                        Image(systemName: "creditcard.fill")
                    }
                    Text(isCharging ? "Waiting for card…" : "Charge \(amountString)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .foregroundStyle(AppTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.accentGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppTheme.primary.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 14, y: 7)
            }
            .buttonStyle(BouncyButtonStyle())
            .disabled(chargeDisabled)
            .opacity(chargeDisabled ? 0.5 : 1)
            .animation(.easeInOut(duration: 0.2), value: chargeDisabled)

            if !reader.connectionState.isConnected {
                Text("Connect the DynaFlex II Go to take a card payment.")
                    .font(.caption).foregroundStyle(AppTheme.primary.opacity(0.75))
            }

            // Sandbox-only shortcut: charge a static test card via /test-sale, so the
            // whole app → backend → Forte path (and the receipt) is testable without
            // the reader. Remove before production. The slide-reveal animation gives
            // this secondary action a distinct, deliberate feel before it fires.
            SlideRevealButton(
                title: "Test charge (sandbox card)",
                systemImage: "creditcard.and.123",
                isDisabled: testChargeDisabled
            ) {
                amountFocused = false
                Task { await testCharge() }
            }
        }
    }

    private var amountString: String { amount.formatted(.currency(code: "USD")) }

    private func charge() async {
        MTLog("🛒 Charge tapped: \(amountString) order=\(orderNumber)")
        isCharging = true
        outcome = nil
        let result = await reader.runSale(amount: amount, orderNumber: orderNumber)
        MTLog("🛒 Charge finished: \(String(describing: result))")
        handle(result)
    }

    private func testCharge() async {
        MTLog("🧪 Test charge (sandbox card): \(amountString)")
        isCharging = true
        outcome = nil
        let result = await PaymentAPIClient.testSale(amount: amount, orderNumber: orderNumber, card: .sandboxVisa)
        MTLog("🧪 Test charge finished: \(String(describing: result))")
        handle(result)
    }

    /// On approval, present the receipt; otherwise show the inline banner.
    private func handle(_ result: PaymentOutcome) {
        isCharging = false
        outcome = result
        if case .approved(let txn, _) = result, let txn {
            chargedAmount = amount
            receiptTransactionID = txn
        }
    }

    private func isApproved(_ o: PaymentOutcome) -> Bool {
        if case .approved = o { return true } else { return false }
    }

    // MARK: Result banner (declined / failed only)

    @ViewBuilder
    private func resultBanner(_ outcome: PaymentOutcome) -> some View {
        switch outcome {
        case .approved:
            EmptyView()
        case .declined(let message):
            banner("Declined", detail: message, tint: .orange, icon: "xmark.circle.fill")
        case .failed(let message):
            banner("Couldn’t complete", detail: message, tint: .red, icon: "exclamationmark.triangle.fill")
        }
    }

    private func banner(_ title: String, detail: String, tint: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Label(title, systemImage: icon).foregroundStyle(tint).font(.headline)
            if !detail.isEmpty {
                Text(detail).font(.footnote).foregroundStyle(AppTheme.primary.opacity(0.8)).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding()
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

/// Lets an optional transaction id drive `.sheet(item:)`.
extension String: @retroactive Identifiable {
    public var id: String { self }
}

#Preview {
    PaymentView()
}
