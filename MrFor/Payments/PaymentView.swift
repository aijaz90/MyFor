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
    @State private var vm = FortePaymentProcessViewModel()

    @State private var amount: Decimal = 25.00
    @State private var showingBluetooth = false
    @State private var showingSettings = false
    @State private var showingManualCard = false

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

                    if vm.isProcessing {
                        Text(reader.statusMessage ?? vm.processingMessage ?? "Processing…")
                            .font(.callout.weight(.medium)).foregroundStyle(AppTheme.primary.opacity(0.85))
                            .padding(.top, 16)
                            .transition(.opacity)
                    }

                    Spacer()

                    chargeButton.padding(.horizontal).padding(.bottom, 12)
                }
                .animation(.easeInOut(duration: 0.25), value: vm.isProcessing)

                // Success / failure popup (DynaFlex reader flow).
                if let alert = vm.alert {
                    PaymentAlertView(alert: alert) { vm.alert = nil }
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: vm.alert)
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
            .sheet(isPresented: $showingManualCard) {
                ManualCardView(amount: amount, orderNumber: orderNumber) { result in
                    vm.handleManualEntry(result, amount: amount)
                }
            }
            .sheet(item: Binding(get: { vm.receiptTransactionID }, set: { vm.receiptTransactionID = $0 })) { txn in
                ReceiptView(transactionID: txn, fallbackAmount: vm.chargedAmount) {
                    vm.receiptTransactionID = nil
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

    private var chargeDisabled: Bool { vm.isProcessing || !reader.connectionState.isConnected || amount <= 0 }
    private var testChargeDisabled: Bool { vm.isProcessing || amount <= 0 }

    private var chargeButton: some View {
        VStack(spacing: 12) {
            Button {
                amountFocused = false
                Task { await charge() }
            } label: {
                HStack(spacing: 10) {
                    if vm.isProcessing {
                        ProgressView().tint(AppTheme.primary)
                    } else {
                        Image(systemName: "creditcard.fill")
                    }
                    Text(vm.isProcessing ? "Waiting for card…" : "Charge \(amountString)")
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

            // Manual entry: opens the Forte-style card form in a web view. Works
            // without the reader (card-not-present / keyed sale).
            Button {
                amountFocused = false
                showingManualCard = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                    Text("Enter card manually")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.primary.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(BouncyButtonStyle())
            .disabled(testChargeDisabled)
            .opacity(testChargeDisabled ? 0.5 : 1)
        }
    }

    private var amountString: String { amount.formatted(.currency(code: "USD")) }

    /// Reader payment → DynaFlex API → success/failure popup.
    private func charge() async {
        MTLog("🛒 Charge tapped: \(amountString)")
        await vm.processReaderPayment(using: reader, amount: amount)
    }

    /// Sandbox keyed test charge → receipt.
    private func testCharge() async {
        await vm.testCharge(amount: amount, orderNumber: orderNumber)
    }
}

/// Lets an optional transaction id drive `.sheet(item:)`.
extension String: @retroactive Identifiable {
    public var id: String { self }
}

#Preview {
    PaymentView()
}
