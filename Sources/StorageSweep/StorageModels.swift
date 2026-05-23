import Foundation

struct StorageItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    let category: StorageCategory
    let safety: CleanupSafety
    let cleanupNote: String
    let modifiedAt: Date?

    init(url: URL, size: Int64, isDirectory: Bool, category: StorageCategory, modifiedAt: Date?) {
        let assessment = CleanupAdvisor.assess(url: url, isDirectory: isDirectory, category: category)

        self.id = url.path
        self.url = url
        self.name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        self.path = url.path
        self.size = size
        self.isDirectory = isDirectory
        self.category = category
        self.safety = assessment.safety
        self.cleanupNote = assessment.note
        self.modifiedAt = modifiedAt
    }
}

enum StorageCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case node = "Node"
    case docker = "Docker"
    case kubernetes = "K8s"
    case xcode = "Xcode"
    case homebrew = "Homebrew"
    case python = "Python"
    case rust = "Rust"
    case go = "Go"
    case caches = "Caches"
    case media = "Media"
    case archives = "Archives"
    case apps = "Apps"
    case documents = "Documents"
    case system = "System"
    case other = "Other"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .all: return "internaldrive"
        case .node: return "shippingbox"
        case .docker: return "cube.box"
        case .kubernetes: return "hexagon"
        case .xcode: return "hammer"
        case .homebrew: return "mug"
        case .python: return "curlybraces"
        case .rust: return "gearshape"
        case .go: return "chevron.left.forwardslash.chevron.right"
        case .caches: return "tray.full"
        case .media: return "play.rectangle"
        case .archives: return "archivebox"
        case .apps: return "app.dashed"
        case .documents: return "doc.text"
        case .system: return "gearshape.2"
        case .other: return "folder"
        }
    }
}

enum CleanupSafety: String, CaseIterable, Identifiable {
    case safe = "Safe"
    case review = "Review"
    case protected = "Protected"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .safe: return "checkmark.shield"
        case .review: return "exclamationmark.triangle"
        case .protected: return "lock.shield"
        }
    }
}

enum SafetyFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case safe = "Safe"
    case review = "Review"
    case protected = "Protected"

    var id: String { rawValue }
}

struct ScanProgress {
    var scannedCount: Int
    var skippedCount: Int
    var currentPath: String
}

struct ScanResult {
    var roots: [URL]
    var items: [StorageItem]
    var scannedCount: Int
    var skippedCount: Int
    var scannedAt: Date
}

extension Int64 {
    var storageString: String {
        ByteCountFormatter.storageFormatter.string(fromByteCount: self)
    }
}

extension ByteCountFormatter {
    static let storageFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()
}
