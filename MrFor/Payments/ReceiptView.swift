//
//  ReceiptView.swift
//  MrFor
//
//  Shown after a successful charge. Fetches the receipt from the backend
//  (GET /api/payments/receipt/:id) and only reveals the details once that data
//  has loaded, so everything appears together — amount, card, auth code,
//  transaction id and date are Forte's record of truth. Styled as a floating
//  "spatial" card on the shared brand gradient (see Theme/AppTheme.swift).
//

import SwiftUI

struct ReceiptView: View {
    let transactionID: String
    /// Used only in the (rare) case the receipt API can't be reached.
    let fallbackAmount: Decimal
    let onDone: () -> Void

    @State private var receipt: Receipt?
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                Group {
                    if loading {
                        loadingState
                    } else if let receipt {
                        loadedState(receipt)
                    } else {
                        errorState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.secondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Receipt")
                        .font(.headline)
                        .foregroundStyle(AppTheme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .fontWeight(.semibold)
                        .tint(AppTheme.primary)
                }
            }
            .task { await load() }
        }
    }

    // MARK: Loading

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(AppTheme.primary)
            Text("Loading receipt…").font(.subheadline).foregroundStyle(AppTheme.primary.opacity(0.75))
        }
    }

    // MARK: Loaded — everything shown together

    private func loadedState(_ receipt: Receipt) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                successHeader(receipt)
                detailCard(receipt)
            }
            .padding(20)
        }
        .transition(.opacity)
    }

    private func successHeader(_ receipt: Receipt) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(AppTheme.primary.opacity(0.14)).frame(width: 96, height: 96)
                Circle().fill(AppTheme.primary.opacity(0.26)).frame(width: 74, height: 74)
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.primary)
            }
            Text("Payment successful")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(amountText(receipt))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primary)
            if let merchant = receipt.merchant_name {
                Text(merchant).font(.subheadline).foregroundStyle(AppTheme.primary.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private func detailCard(_ receipt: Receipt) -> some View {
        VStack(spacing: 0) {
            if let card = receipt.card, (card.masked != nil || card.type != nil) {
                cardRow(card)
                divider
            }
            row("Status", value: (receipt.status ?? "ready").capitalized, valueColor: .green)
            divider
            row("Authorization", value: receipt.authorization_code ?? "—", mono: true)
            divider
            row("Date", value: formattedDate(receipt.date))
            divider
            stackedRow("Transaction ID", value: receipt.transaction_id ?? transactionID)
        }
        .padding(.vertical, 4)
        .spatialCard(cornerRadius: 22, shadowOpacity: 0.28)
    }

    // MARK: Error fallback

    private var errorState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(AppTheme.primary.opacity(0.14)).frame(width: 96, height: 96)
                Circle().fill(AppTheme.primary.opacity(0.26)).frame(width: 74, height: 74)
                Image(systemName: "checkmark").font(.system(size: 34, weight: .bold)).foregroundStyle(AppTheme.primary)
            }
            Text("Payment successful")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(fallbackAmount.formatted(.currency(code: "USD")))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primary)
            VStack(spacing: 4) {
                Text("Couldn’t load full receipt details.")
                    .font(.footnote).foregroundStyle(AppTheme.primary.opacity(0.7))
                Text(transactionID)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(AppTheme.primary.opacity(0.6))
            }
            Button("Retry") { Task { await load() } }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondary)
                .padding(.horizontal, 22).padding(.vertical, 10)
                .background(AppTheme.primary, in: Capsule())
                .buttonStyle(BouncyButtonStyle())
        }
        .padding(28)
    }

    // MARK: Rows

    private func cardRow(_ card: Receipt.ReceiptCard) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.secondary.opacity(0.08)).frame(width: 36, height: 36)
                Image(systemName: "creditcard.fill").font(.callout).foregroundStyle(AppTheme.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text([card.type?.capitalized, card.masked].compactMap { $0 }.joined(separator: "  "))
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.secondary)
                if let name = card.name_on_card {
                    Text(name).font(.caption).foregroundStyle(AppTheme.secondary.opacity(0.6))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func row(_ label: String, value: String, mono: Bool = false, valueColor: Color = AppTheme.secondary) -> some View {
        HStack {
            Text(label).foregroundStyle(AppTheme.secondary.opacity(0.75))
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
                .font(mono ? .system(.callout, design: .monospaced) : .callout)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    /// Label above, full value below — so a long transaction id shows in full.
    private func stackedRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).foregroundStyle(AppTheme.secondary.opacity(0.55)).font(.callout)
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(AppTheme.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    private var divider: some View {
        Rectangle().fill(AppTheme.secondary.opacity(0.1)).frame(height: 1).padding(.leading, 16)
    }

    // MARK: Formatting

    private func amountText(_ receipt: Receipt) -> String {
        let value = receipt.amount.map { Decimal($0) } ?? fallbackAmount
        return value.formatted(.currency(code: receipt.currency ?? "USD"))
    }

    /// Forte sends e.g. "2026-07-09T03:00:19.717" (no timezone, variable fractional
    /// digits). Parse robustly and show a readable date with time.
    private func formattedDate(_ raw: String?) -> String {
        guard let raw else { return "—" }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss.SS",
                    "yyyy-MM-dd'T'HH:mm:ss.S", "yyyy-MM-dd'T'HH:mm:ss"] {
            parser.dateFormat = fmt
            if let date = parser.date(from: raw) {
                let out = DateFormatter()
                out.dateFormat = "MMM d, yyyy 'at' h:mm a"
                return out.string(from: date)
            }
        }
        return raw
    }

    private func load() async {
        loading = true
        let fetched = await PaymentAPIClient.receipt(transactionID: transactionID)
        withAnimation(.snappy) {
            receipt = fetched
            loading = false
        }
    }
}

#Preview {
    ReceiptView(transactionID: "trn_3adea083-e78f-47ee-b3a7-f6217313886d", fallbackAmount: 42.75) {}
}
