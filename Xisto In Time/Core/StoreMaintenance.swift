//
//  StoreMaintenance.swift
//  Xisto In Time
//
//  Created by Artur Tavares on 19/08/2026.
//

import Foundation
import SQLite3
import SwiftData

extension ModelContext {
    /// Persists pending changes and merges SQLite's WAL into the main store
    /// file immediately, instead of relying on SwiftData's autosave timing.
    /// Without this, sessions/projects/tasks could sit unsaved in memory, or
    /// committed only to the WAL, for as long as the app happened to run —
    /// a crash in that window loses them even though nothing was "wrong".
    func saveAndCheckpoint() {
        do {
            try save()
        } catch {
            print("Xisto: failed to save model context: \(error)")
            return
        }
        StoreMaintenance.checkpoint(container: container)
    }
}

enum StoreMaintenance {
    private static let maxBackups = 10

    private static func backupDirectory() -> URL {
        URL.applicationSupportDirectory.appending(path: "Xisto Backups", directoryHint: .isDirectory)
    }

    /// Snapshots the previous store before this launch opens it. Runs while
    /// nothing has the file open yet, so a plain file copy is consistent.
    /// This is the last line of defense if the store itself ever gets
    /// corrupted rather than just losing unsaved writes.
    static func backupBeforeOpening(storeURL: URL) {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        let directory = backupDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = directory.appending(path: "default-\(stamp).store")
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }

        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: storeURL.path + suffix)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try? FileManager.default.copyItem(
                at: source,
                to: URL(fileURLWithPath: destination.path + suffix)
            )
        }

        pruneOldBackups(in: directory)
    }

    private static func pruneOldBackups(in directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let stores = files.filter { $0.pathExtension == "store" }
        let sorted = stores.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return lhsDate > rhsDate
        }

        for stale in sorted.dropFirst(maxBackups) {
            try? FileManager.default.removeItem(at: stale)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: stale.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: stale.path + "-shm"))
        }
    }

    /// Merges the WAL into the main store file via a second, short-lived
    /// SQLite connection — a standard, safe way to force a checkpoint
    /// without needing access to SwiftData's own connection.
    static func checkpoint(container: ModelContainer) {
        guard let url = container.configurations.first?.url else { return }
        checkpoint(storeURL: url)
    }

    static func checkpoint(storeURL: URL) {
        var db: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return
        }
        sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE);", nil, nil, nil)
        sqlite3_close(db)
    }
}
