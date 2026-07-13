//
//  ReaderDataView.swift
//  MrFor
//
//  Debug view of one raw card read from the DynaFlex — every field labeled and
//  individually copyable, plus "Copy all as JSON". No API is called; this is for
//  grabbing values (KSN, SRED, ARQC, etc.) to test in Swagger.
//

import SwiftUI
import UIKit

struct ReaderDataView: View {
    let data: EncryptedCardData
    let onDone: () -> Void

    @State private var copiedField: String?

    private var fields: [(label: String, value: String)] {
        [
            ("Transaction Type", data.transactionType),
            ("Device KSN", data.ksn),
            ("Device Serial Number", data.deviceSerialNumber),
            ("Card Type", data.cardType),
            ("Card Holder Name", data.cardHolderName),
            ("Masked Track 2", data.maskedTrack2),
            ("SRED Data (emvSredData)", data.sredData),
            ("ARQC Data", data.arqcData),
            ("Batch Data", data.batchData),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        copyAllButton
                        ForEach(fields, id: \.label) { field in
                            fieldCard(label: field.label, value: field.value)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.secondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Reader Data").font(.headline).foregroundStyle(AppTheme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone).fontWeight(.semibold).tint(AppTheme.primary)
                }
            }
            .onAppear { AppLogger.shared.screen("ReaderDataView") }
        }
    }

    private var copyAllButton: some View {
        Button {
            copy(data.debugJSON, field: "all")
        } label: {
            Label(copiedField == "all" ? "Copied JSON ✓" : "Copy all as JSON", systemImage: "doc.on.doc")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.primary.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.primary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private func fieldCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondary.opacity(0.6))
                    .textCase(.uppercase)
                Spacer()
                Button {
                    copy(value, field: label)
                } label: {
                    Label(copiedField == label ? "Copied" : "Copy",
                          systemImage: copiedField == label ? "checkmark" : "doc.on.doc")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(copiedField == label ? .green : AppTheme.secondary)
                }
                .disabled(value.isEmpty)
                .opacity(value.isEmpty ? 0.35 : 1)
            }

            Text(value.isEmpty ? "—" : value)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(value.isEmpty ? AppTheme.secondary.opacity(0.4) : AppTheme.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .spatialCard(cornerRadius: 16, shadowOpacity: 0.18)
    }

    private func copy(_ value: String, field: String) {
        guard !value.isEmpty else { return }
        UIPasteboard.general.string = value
        withAnimation { copiedField = field }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { if copiedField == field { copiedField = nil } }
        }
    }
}
