//
//  ServerSettingsView.swift
//  MrFor
//
//  Choose which backend the app talks to: Local (your localhost eventExplore)
//  or Production (your deployed server). Both hold the Forte credentials and
//  expose the same endpoints — only the base URL differs.
//

import SwiftUI

struct ServerSettingsView: View {
    @AppStorage(ForteConfig.envKey) private var envRaw = ForteConfig.Environment.local.rawValue
    @AppStorage(ForteConfig.localURLKey) private var localURL = ForteConfig.defaultLocalURL
    @AppStorage(ForteConfig.prodURLKey) private var prodURL = ForteConfig.defaultProdURL

    @Environment(\.dismiss) private var dismiss

    @State private var checking = false
    @State private var checkOK: Bool?
    @State private var checkMessage: String?

    private var env: ForteConfig.Environment {
        ForteConfig.Environment(rawValue: envRaw) ?? .local
    }

    private var activeURL: String {
        env == .local ? localURL : prodURL
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    activeCard
                    environmentSwitcher
                    urlEditor
                    testSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .onChange(of: envRaw) { resetCheck() }
            .onChange(of: activeURL) { resetCheck() }
        }
    }

    // MARK: Active endpoint banner

    private var activeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Active endpoint", systemImage: env.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                statusPill
            }
            Text(activeURL.isEmpty ? "No URL set" : activeURL)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(activeURL.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(checkOK == true ? .green : checkOK == false ? .red : .secondary)
                .frame(width: 8, height: 8)
            Text(checkOK == true ? "Reachable" : checkOK == false ? "Unreachable" : "Untested")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: Environment switcher (two modern pills)

    private var environmentSwitcher: some View {
        HStack(spacing: 12) {
            ForEach(ForteConfig.Environment.allCases, id: \.self) { option in
                envPill(option)
            }
        }
    }

    private func envPill(_ option: ForteConfig.Environment) -> some View {
        let selected = env == option
        return Button {
            withAnimation(.snappy(duration: 0.25)) { envRaw = option.rawValue }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: option.symbol)
                    .font(.title2)
                    .symbolVariant(selected ? .fill : .none)
                Text(option.title).font(.subheadline.weight(.semibold))
                Text(option.subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(selected ? Color.accentColor : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.14) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: URL editor for the selected environment

    private var urlEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(env.title.uppercased()) URL")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "link").foregroundStyle(.secondary)
                TextField(
                    env == .local ? "http://localhost:3000" : "https://your-server.com",
                    text: env == .local ? $localURL : $prodURL
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.system(.body, design: .monospaced))
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(env == .local
                 ? "On a physical device, localhost won't reach your Mac — use its LAN IP (e.g. http://192.168.1.42:3000)."
                 : "Your deployed backend. Use HTTPS — iOS blocks plain HTTP to public hosts.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Test connection

    private var testSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await runCheck() }
            } label: {
                HStack {
                    if checking { ProgressView().tint(.white) }
                    else { Image(systemName: "antenna.radiowaves.left.and.right") }
                    Text(checking ? "Testing…" : "Test connection").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .disabled(checking || activeURL.isEmpty)

            if let checkMessage {
                HStack(spacing: 8) {
                    Image(systemName: checkOK == true ? "checkmark.seal.fill" : "xmark.octagon.fill")
                    Text(checkMessage).font(.footnote)
                    Spacer()
                }
                .foregroundStyle(checkOK == true ? .green : .red)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    (checkOK == true ? Color.green : Color.red).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
        }
    }

    // MARK: Logic

    private func resetCheck() {
        checkOK = nil
        checkMessage = nil
    }

    /// Hits GET /api/payments/verify on the active backend and reports the merchant.
    private func runCheck() async {
        checking = true
        checkMessage = nil
        defer { checking = false }

        struct VerifyResponse: Decodable { let ok: Bool?; let dbaName: String?; let error: String? }
        do {
            var req = URLRequest(url: ForteConfig.endpoint("api/payments/verify"))
            req.timeoutInterval = 15
            let (data, _) = try await URLSession.shared.data(for: req)
            let r = try JSONDecoder().decode(VerifyResponse.self, from: data)
            if r.ok == true {
                checkOK = true
                checkMessage = "Connected: \(r.dbaName ?? "merchant verified")"
            } else {
                checkOK = false
                checkMessage = r.error ?? "Reached the server, but Forte verification failed."
            }
        } catch {
            checkOK = false
            checkMessage = "Couldn’t reach the server. Check the URL is correct and publicly reachable."
        }
    }
}

#Preview {
    ServerSettingsView()
}
