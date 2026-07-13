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

    init() {
        FirebaseApp.configure()
        AppLogger.shared.startSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                AppLogger.shared.endSession(status: "backgrounded")
            case .active:
                break
            default:
                break
            }
        }
    }
}

