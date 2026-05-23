import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = StorageViewModel()
    @State private var confirmingTrash = false
    @State private var confirmingCleanSafe = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            itemList
                .navigationTitle("Storage Sweep")
        } detail: {
            detailPane
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    viewModel.rescan()
                } label: {
                    Label(viewModel.scannedRoots.isEmpty ? "Scan Home" : "Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isScanning)

                Button {
                    viewModel.cancelScan()
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                }
                .disabled(!viewModel.isScanning)

                Button {
                    viewModel.exportReport()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.items.isEmpty)

                Button(role: .destructive) {
                    confirmingCleanSafe = true
                } label: {
                    Label("Clean Safe", systemImage: "sparkles")
                }
                .disabled(viewModel.isScanning || viewModel.autoCleanCandidates.isEmpty)
            }
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: $confirmingTrash,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                viewModel.moveSelectedToTrash()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let item = viewModel.selectedItem {
                Text("\(item.cleanupNote)\n\n\(item.path)")
            }
        }
        .confirmationDialog(
            "Clean Safe Items?",
            isPresented: $confirmingCleanSafe,
            titleVisibility: .visible
        ) {
            Button("Move Safe Items to Trash", role: .destructive) {
                viewModel.cleanSafeItems()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Storage Sweep will move \(viewModel.autoCleanCandidates.count) auto-cleanable items to Trash, up to \(viewModel.autoCleanCandidateTotal.storageString). It will not touch protected roots, documents, media, app profiles, Application Support, Containers, Keychains, Mail, or Messages.")
        }
        .alert("Storage Sweep", isPresented: Binding(get: {
            viewModel.lastError != nil
        }, set: { newValue in
            if !newValue { viewModel.lastError = nil }
        })) {
            Button("OK") { viewModel.lastError = nil }
        } message: {
            Text(viewModel.lastError ?? "")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    viewModel.scanHome()
                } label: {
                    Label("Scan Home", systemImage: "house")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    viewModel.scanMacintoshHD()
                } label: {
                    Label("Scan Macintosh HD", systemImage: "internaldrive")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    viewModel.chooseFolderAndScan()
                } label: {
                    Label("Choose Folder", systemImage: "folder.badge.gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.bordered)

            VStack(alignment: .leading, spacing: 8) {
                Text("Minimum")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Slider(value: $viewModel.minimumSizeMB, in: 5...1000, step: 5)
                    Text("\(Int(viewModel.minimumSizeMB)) MB")
                        .monospacedDigit()
                        .frame(width: 64, alignment: .trailing)
                }
            }

            Picker("Category", selection: $viewModel.selectedCategory) {
                Label(StorageCategory.all.rawValue, systemImage: StorageCategory.all.symbolName)
                    .tag(StorageCategory.all)
                ForEach(viewModel.categoryTotals, id: \.0) { category, size in
                    Label("\(category.rawValue)  \(size.storageString)", systemImage: category.symbolName)
                        .tag(category)
                }
            }
            .pickerStyle(.radioGroup)

            Divider()

            Picker("Safety", selection: $viewModel.selectedSafety) {
                Text("All").tag(SafetyFilter.all)
                ForEach(viewModel.safetyTotals, id: \.0) { safety, size in
                    Label("\(safety.rawValue)  \(size.storageString)", systemImage: safety.symbolName)
                        .tag(SafetyFilter(rawValue: safety.rawValue) ?? .all)
                }
            }
            .pickerStyle(.radioGroup)

            Button {
                viewModel.openFullDiskAccessSettings()
            } label: {
                Label("Full Disk Access", systemImage: "lock.open")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                confirmingCleanSafe = true
            } label: {
                Label("Clean Safe", systemImage: "sparkles")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isScanning || viewModel.autoCleanCandidates.isEmpty)

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.progress.currentPath)
                        .lineLimit(2)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Items", value: "\(viewModel.filteredItems.count)")
                LabeledContent("Shown", value: viewModel.totalShownSize.storageString)
                LabeledContent("Can Clean", value: viewModel.autoCleanCandidateTotal.storageString)
                LabeledContent("Scanned", value: "\(viewModel.progress.scannedCount)")
                LabeledContent("Skipped", value: "\(viewModel.progress.skippedCount)")
            }
            .font(.caption)
        }
        .padding()
        .frame(minWidth: 230)
    }

    private var itemList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(.quaternary.opacity(0.35))

            if viewModel.items.isEmpty && !viewModel.isScanning {
                VStack(spacing: 14) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Choose a scan to begin")
                        .font(.headline)
                    HStack {
                        Button {
                            viewModel.scanHome()
                        } label: {
                            Label("Scan Home", systemImage: "house")
                        }
                        Button {
                            viewModel.chooseFolderAndScan()
                        } label: {
                            Label("Choose Folder", systemImage: "folder")
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.filteredItems, selection: $viewModel.selectedItemID) { item in
                    StorageRow(item: item)
                        .tag(item.id)
                        .contextMenu {
                            Button {
                                viewModel.selectedItemID = item.id
                                viewModel.revealSelected()
                            } label: {
                                Label("Reveal", systemImage: "finder")
                            }

                            Button {
                                viewModel.selectedItemID = item.id
                                viewModel.copySelectedPath()
                            } label: {
                                Label("Copy Path", systemImage: "doc.on.doc")
                            }

                            Divider()

                            Button(role: .destructive) {
                                viewModel.selectedItemID = item.id
                                confirmingTrash = true
                            } label: {
                                Label("Move to Trash", systemImage: "trash")
                            }
                            .disabled(item.safety == .protected)
                        }
                }
                .listStyle(.inset)
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let item = viewModel.selectedItem {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(item.isDirectory ? .blue : .secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.title2.weight(.semibold))
                            .lineLimit(2)
                        Text(item.category.rawValue)
                            .foregroundStyle(.secondary)
                        SafetyBadge(safety: item.safety)
                    }
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                    GridRow {
                        Text("Safety").foregroundStyle(.secondary)
                        HStack {
                            SafetyBadge(safety: item.safety)
                            Text(item.cleanupNote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    GridRow {
                        Text("Auto-clean").foregroundStyle(.secondary)
                        Text(
                            CleanupAdvisor.canAutoClean(
                                url: item.url,
                                isDirectory: item.isDirectory,
                                category: item.category,
                                safety: item.safety
                            ) ? "Eligible" : "Manual review"
                        )
                    }
                    GridRow {
                        Text("Size").foregroundStyle(.secondary)
                        Text(item.size.storageString).font(.headline)
                    }
                    GridRow {
                        Text("Kind").foregroundStyle(.secondary)
                        Text(item.isDirectory ? "Folder" : "File")
                    }
                    if let modifiedAt = item.modifiedAt {
                        GridRow {
                            Text("Modified").foregroundStyle(.secondary)
                            Text(modifiedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    GridRow(alignment: .top) {
                        Text("Path").foregroundStyle(.secondary)
                        Text(item.path)
                            .textSelection(.enabled)
                            .lineLimit(8)
                    }
                }

                HStack {
                    Button {
                        viewModel.revealSelected()
                    } label: {
                        Label("Reveal", systemImage: "finder")
                    }

                    Button {
                        viewModel.copySelectedPath()
                    } label: {
                        Label("Copy Path", systemImage: "doc.on.doc")
                    }

                    Spacer()

                    Button(role: .destructive) {
                        confirmingTrash = true
                    } label: {
                        Label("Move to Trash", systemImage: "trash")
                    }
                    .disabled(!viewModel.selectedItemCanMoveToTrash)
                }

                Spacer()
            }
            .padding(24)
            .frame(minWidth: 340, alignment: .topLeading)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Storage Sweep")
                    .font(.title3.weight(.semibold))
                Text(viewModel.isScanning ? "Scanning" : "Start a scan to find cleanup candidates")
                    .foregroundStyle(.secondary)
                if !viewModel.isScanning {
                    HStack {
                        Button {
                            viewModel.scanHome()
                        } label: {
                            Label("Scan Home", systemImage: "house")
                        }
                        Button {
                            viewModel.scanMacintoshHD()
                        } label: {
                            Label("Scan Macintosh HD", systemImage: "internaldrive")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct StorageRow: View {
    let item: StorageItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(item.isDirectory ? .blue : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Text(item.category.rawValue)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    SafetyBadge(safety: item.safety)
                }

                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Text(item.size.storageString)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 82, alignment: .trailing)
        }
        .padding(.vertical, 5)
    }
}

private struct SafetyBadge: View {
    let safety: CleanupSafety

    var body: some View {
        Label(safety.rawValue, systemImage: safety.symbolName)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(safety.foregroundColor)
            .background(safety.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .help(helpText)
    }

    private var helpText: String {
        switch safety {
        case .safe:
            return "Usually safe to move to Trash because it can be recreated."
        case .review:
            return "Inspect before deleting. It may contain personal files or app state."
        case .protected:
            return "Deletion is blocked in Storage Sweep."
        }
    }
}

private extension CleanupSafety {
    var foregroundColor: Color {
        switch self {
        case .safe: return .green
        case .review: return .orange
        case .protected: return .red
        }
    }

    var backgroundColor: Color {
        switch self {
        case .safe: return Color.green.opacity(0.16)
        case .review: return Color.orange.opacity(0.16)
        case .protected: return Color.red.opacity(0.16)
        }
    }
}
