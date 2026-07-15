//
//  MrForApp.swift
//  MrFor
//
//  Created by Aijaz Ali on 08/07/2026.
//

import SwiftUI
import FirebaseCore

@main
struct MrForApp: App {
    @Environment(\.scenePhase) private var scenePhase

    // Owned once for the entire app lifetime. IMPORTANT: do NOT recreate this
    // per-view (e.g. as `@State private var reader = ReaderEngine()` inside
    // PaymentView). SwiftUI re-evaluates a View struct's initializer very
    // often (scene phase changes, animations, environment updates, etc.), and
    // every one of those re-evaluations would eagerly construct a *new*
    // ReaderEngine() before @State discards it — and MagTekReader's init()
    // immediately calls into the shared MagTek CoreAPI singleton
    // (setDeviceType/startDiscover), which stomps on the real, already-connected
    // session. That's what caused the reader to silently drop and the
    // "MagTek engine ready" / "Auto-reconnect: scanning…" log spam. The App
    // struct itself is only instantiated once per process, so this is the
    // correct, stable home for the single reader instance.
    @State private var reader = ReaderEngine()

    init() {
        FirebaseApp.configure()
        AppLogger.shared.startSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(reader: reader)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                AppLogger.shared.endSession(status: "backgrounded")
            case .active:
                // App (re)entered foreground — give the reader a chance to
                // silently reconnect if it was previously paired.
                reader.reconnectIfNeeded()
            default:
                break
            }
        }
    }
}

