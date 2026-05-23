import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class StorageViewModel: ObservableObject {
    @Published var items: [StorageItem] = []
    @Published var selectedItemID: StorageItem.ID?
    @Published var searchText = ""
    @Published var selectedCategory: StorageCategory = .all
    @Published var selectedSafety: SafetyFilter = .all
    @Published var isScanning = false
    @Published var progress = ScanProgress(scannedCount: 0, skippedCount: 0, currentPath: "")
    @Published var lastError: String?
    @Published var lastScanDate: Date?
    @Published var scannedRoots: [URL] = []
    @Published var minimumSizeMB = 50.0

    private var scanTask: Task<Void, Never>?

    var selectedItem: StorageItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    var filteredItems: [StorageItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return items.filter { item in
            let matchesCategory = selectedCategory == .all || item.category == selectedCategory
            let matchesSafety: Bool
            switch selectedSafety {
            case .all:
                matchesSafety = true
            case .safe:
                matchesSafety = item.safety == .safe
            case .review:
                matchesSafety = item.safety == .review
            case .protected:
                matchesSafety = item.safety == .protected
            }

            let matchesSearch = query.isEmpty
                || item.name.lowercased().contains(query)
                || item.path.lowercased().contains(query)
            return matchesCategory && matchesSafety && matchesSearch
        }
    }

    var totalShownSize: Int64 {
        nonOverlappingTotal(for: filteredItems)
    }

    var categoryTotals: [(StorageCategory, Int64)] {
        var totals: [StorageCategory: Int64] = [:]
        for category in StorageCategory.allCases where category != .all {
            let categoryItems = items.filter { $0.category == category }
            totals[category] = nonOverlappingTotal(for: categoryItems)
        }

        return StorageCategory.allCases
            .filter { $0 != .all }
            .map { ($0, totals[$0, default: 0]) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    var safetyTotals: [(CleanupSafety, Int64)] {
        CleanupSafety.allCases.map { safety in
            let safetyItems = items.filter { $0.safety == safety }
            return (safety, nonOverlappingTotal(for: safetyItems))
        }
        .filter { $0.1 > 0 }
    }

    var selectedItemCanMoveToTrash: Bool {
        guard let selectedItem else { return false }
        return selectedItem.safety != .protected
    }

    var autoCleanCandidates: [StorageItem] {
        let candidates = items.filter {
            CleanupAdvisor.canAutoClean(
                url: $0.url,
                isDirectory: $0.isDirectory,
                category: $0.category,
                safety: $0.safety
            )
        }

        return nonOverlappingItems(for: candidates)
    }

    var autoCleanCandidateTotal: Int64 {
        autoCleanCandidates.reduce(Int64(0)) { $0 + $1.size }
    }

    func scanHome() {
        scan(paths: [FileManager.default.homeDirectoryForCurrentUser])
    }

    func scanMacintoshHD() {
        scan(paths: [URL(fileURLWithPath: "/")])
    }

    func chooseFolderAndScan() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "Scan"

        if panel.runModal() == .OK, !panel.urls.isEmpty {
            scan(paths: panel.urls)
        }
    }

    func rescan() {
        guard !scannedRoots.isEmpty else {
            scanHome()
            return
        }
        scan(paths: scannedRoots)
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    func revealSelected() {
        guard let selectedItem else { return }
        NSWorkspace.shared.activateFileViewerSelecting([selectedItem.url])
    }

    func copySelectedPath() {
        guard let selectedItem else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedItem.path, forType: .string)
    }

    func moveSelectedToTrash() {
        guard let selectedItem else { return }

        guard selectedItem.safety != .protected else {
            lastError = "Storage Sweep blocks deleting protected system, app, and account data roots. Reveal it in Finder and delete a smaller item if you are certain."
            return
        }

        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: selectedItem.url, resultingItemURL: &resultingURL)
            items.removeAll { $0.id == selectedItem.id || $0.path.hasPrefix(selectedItem.path + "/") }
            selectedItemID = nil
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func cleanSafeItems() {
        let candidates = autoCleanCandidates

        guard !candidates.isEmpty else {
            lastError = "No auto-cleanable items were found. Try scanning Home or lowering the minimum size."
            return
        }

        var cleanedCount = 0
        var cleanedBytes: Int64 = 0
        var cleanedPaths: [String] = []
        var failedPaths: [String] = []

        for item in candidates {
            do {
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultingURL)
                cleanedCount += 1
                cleanedBytes += item.size
                cleanedPaths.append(item.path)
            } catch {
                failedPaths.append(item.path)
            }
        }

        let trashedPaths = Set(cleanedPaths)
        items.removeAll { item in
            trashedPaths.contains(item.path) || trashedPaths.contains(where: { item.path.hasPrefix($0 + "/") })
        }

        selectedItemID = nil

        if failedPaths.isEmpty {
            lastError = "Moved \(cleanedCount) safe items to Trash and freed up to \(cleanedBytes.storageString). Empty Trash later when you are happy everything still works."
        } else {
            lastError = "Moved \(cleanedCount) safe items to Trash. \(failedPaths.count) items could not be moved, usually because an app is using them or permission was denied."
        }
    }

    func exportReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "StorageSweep-Report.txt"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try reportText().write(to: url, atomically: true, encoding: .utf8)
            lastError = "Report saved to \(url.path)"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    private func scan(paths: [URL]) {
        scanTask?.cancel()
        selectedItemID = nil
        selectedCategory = .all
        selectedSafety = .all
        lastError = nil
        scannedRoots = paths
        isScanning = true
        progress = ScanProgress(scannedCount: 0, skippedCount: 0, currentPath: "")

        let minimumSize = Int64(minimumSizeMB * 1024 * 1024)

        scanTask = Task {
            let result = await StorageScanner.scan(roots: paths, minimumSize: minimumSize) { [weak self] progress in
                Task { @MainActor in
                    self?.progress = progress
                }
            }

            guard !Task.isCancelled else { return }
            items = result.items
            lastScanDate = result.scannedAt
            progress = ScanProgress(
                scannedCount: result.scannedCount,
                skippedCount: result.skippedCount,
                currentPath: result.roots.map(\.path).joined(separator: ", ")
            )
            isScanning = false
            scanTask = nil
        }
    }

    private func nonOverlappingTotal(for items: [StorageItem]) -> Int64 {
        nonOverlappingItems(for: items).reduce(Int64(0)) { $0 + $1.size }
    }

    private func nonOverlappingItems(for items: [StorageItem]) -> [StorageItem] {
        let sortedItems = items.sorted { lhs, rhs in
            let lhsDepth = lhs.path.split(separator: "/").count
            let rhsDepth = rhs.path.split(separator: "/").count

            if lhsDepth == rhsDepth {
                return lhs.path < rhs.path
            }

            return lhsDepth < rhsDepth
        }

        var includedPaths: [String] = []
        var includedItems: [StorageItem] = []

        for item in sortedItems {
            if includedPaths.contains(where: { item.path.hasPrefix($0 + "/") }) {
                continue
            }

            includedPaths.append(item.path)
            includedItems.append(item)
        }

        return includedItems
    }

    private func reportText() -> String {
        var lines: [String] = []
        lines.append("Storage Sweep Report")
        lines.append("Generated: \(Date().formatted(date: .abbreviated, time: .shortened))")
        lines.append("Roots: \(scannedRoots.map(\.path).joined(separator: ", "))")
        lines.append("Items: \(items.count)")
        lines.append("Shown non-overlapping total: \(totalShownSize.storageString)")
        lines.append("")
        lines.append("Safety Summary")

        for (safety, size) in safetyTotals {
            lines.append("- \(safety.rawValue): \(size.storageString)")
        }

        lines.append("")
        lines.append("Category Summary")

        for (category, size) in categoryTotals {
            lines.append("- \(category.rawValue): \(size.storageString)")
        }

        lines.append("")
        lines.append("Largest Items")

        for item in items.prefix(100) {
            lines.append("- \(item.size.storageString) [\(item.safety.rawValue)] [\(item.category.rawValue)] \(item.path)")
            lines.append("  \(item.cleanupNote)")
        }

        return lines.joined(separator: "\n")
    }
}
