//
//  DebugLogsView.swift
//  MrFor
//
//  Small debug screen: shows the current session id/device info and lets you
//  export the on-device log mirror (share sheet) — handy when a tester needs
//  to send over what happened without you needing Firebase console access,
//  or when there's no signal to reach Firestore at all.
//

import SwiftUI
import FirebaseCrashlytics

struct DebugLogsView: View {
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var showClearConfirm = false

    var body: some View {
        List {
            Section("Session") {
                LabeledContent("Session ID", value: AppLogger.shared.sessionId)
                LabeledContent("App Version", value: "\(DeviceContext.appVersion) (\(DeviceContext.buildNumber))")
                LabeledContent("iOS", value: DeviceContext.osVersion)
                LabeledContent("Device", value: DeviceContext.deviceModel)
                LabeledContent("Device Name", value: DeviceContext.deviceName)
            }

            Section("Firestore") {
                Text("Logs for this run are written under RealReaderLogs/\(AppLogger.shared.sessionId)/logs in Firebase Firestore.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("On-device log mirror") {
                Button {
                    shareURL = LocalLogStore.shared.fileURLForSharing
                    showShareSheet = true
                } label: {
                    Label("Export Logs", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear Local Log Mirror", systemImage: "trash")
                }
            }

            #if DEBUG
            Section {
                Button {
                    AppLogger.shared.error("Test non-fatal error (debug button)")
                } label: {
                    Label("Send Test Non-Fatal to Crashlytics", systemImage: "exclamationmark.triangle")
                }
                Button(role: .destructive) {
                    fatalError("Test crash triggered from Debug Logs screen")
                } label: {
                    Label("Force Test Crash", systemImage: "bolt.trianglebadge.exclamationmark")
                }
            } header: {
                Text("Crashlytics (Debug builds only)")
            } footer: {
                Text("Verifies the Crashlytics pipeline end-to-end. Relaunch the app after a forced crash and check the Firebase console — reports can take a few minutes to appear.")
            }
            #endif
        }
        .navigationTitle("Debug Logs")
        .onAppear { AppLogger.shared.screen("DebugLogsView") }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .confirmationDialog("Clear the local log mirror?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { LocalLogStore.shared.clear() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack { DebugLogsView() }
}
