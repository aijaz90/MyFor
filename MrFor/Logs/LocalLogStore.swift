//
//  LocalLogStore.swift
//  MrFor
//
//  A lightweight on-device mirror of everything sent to Firestore. Firestore
//  already has its own offline persistence/write queue, so this isn't needed
//  for reliability — it exists so logs are inspectable/exportable straight
//  from the device (a "Export Logs" share sheet on the debug screen), useful
//  if a tester is somewhere with no signal or you just want a quick local
//  copy without opening the Firebase console.
//

import Foundation

final class LocalLogStore {
    static let shared = LocalLogStore()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.mrfor.locallogstore")
    private let maxBytes = 2 * 1024 * 1024 // trim if the mirror grows past ~2MB

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("mrfor_logs.jsonl")
    }

    /// Appends one JSON-lines entry. Safe to call from any thread.
    func append(_ line: String) {
        queue.async { [fileURL, maxBytes] in
            guard let data = (line + "\n").data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(data)
            } else {
                try? data.write(to: fileURL)
            }

            if let size = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int,
               size > maxBytes,
               let contents = try? String(contentsOf: fileURL, encoding: .utf8) {
                // Drop the oldest half rather than growing forever.
                let lines = contents.split(separator: "\n")
                let trimmed = lines.suffix(lines.count / 2).joined(separator: "\n") + "\n"
                try? trimmed.data(using: .utf8)?.write(to: fileURL)
            }
        }
    }

    /// Everything currently on disk, newest last — for the debug screen.
    func readAll() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    func clear() {
        queue.async { [fileURL] in try? FileManager.default.removeItem(at: fileURL) }
    }

    /// File URL for a share-sheet export.
    var fileURLForSharing: URL { fileURL }
}
