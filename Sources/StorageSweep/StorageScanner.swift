import Foundation

enum StorageScanner {
    private final class SkipCounter {
        var count = 0
    }

    private struct DirectoryFrame {
        let url: URL
        let depth: Int
        var size: Int64
        var modifiedAt: Date?
    }

    static let defaultMinimumSize: Int64 = 50 * 1024 * 1024

    static func scan(
        roots: [URL],
        minimumSize: Int64 = defaultMinimumSize,
        progress: @escaping (ScanProgress) -> Void
    ) async -> ScanResult {
        await Task.detached(priority: .userInitiated) {
            scanSynchronously(roots: roots, minimumSize: minimumSize, progress: progress)
        }.value
    }

    private static func scanSynchronously(
        roots: [URL],
        minimumSize: Int64,
        progress: @escaping (ScanProgress) -> Void
    ) -> ScanResult {
        var items: [StorageItem] = []
        var scannedCount = 0
        var skippedCount = 0

        for root in roots {
            guard !Task.isCancelled else { break }
            scanRoot(
                root,
                minimumSize: minimumSize,
                items: &items,
                scannedCount: &scannedCount,
                skippedCount: &skippedCount,
                progress: progress
            )
        }

        let sorted = items
            .sorted { lhs, rhs in
                if lhs.size == rhs.size { return lhs.path < rhs.path }
                return lhs.size > rhs.size
            }
            .prefix(5000)

        return ScanResult(
            roots: roots,
            items: Array(sorted),
            scannedCount: scannedCount,
            skippedCount: skippedCount,
            scannedAt: Date()
        )
    }

    private static func scanRoot(
        _ root: URL,
        minimumSize: Int64,
        items: inout [StorageItem],
        scannedCount: inout Int,
        skippedCount: inout Int,
        progress: @escaping (ScanProgress) -> Void
    ) {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]

        guard let rootValues = try? root.resourceValues(forKeys: keys) else {
            skippedCount += 1
            return
        }

        let skipCounter = SkipCounter()
        var stack = [
            DirectoryFrame(
                url: root,
                depth: 0,
                size: allocatedSize(from: rootValues),
                modifiedAt: rootValues.contentModificationDate
            )
        ]

        let deepEnumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { url, _ in
                if shouldSkip(url: url) {
                    return false
                }
                skipCounter.count += 1
                return true
            }
        )

        while let url = deepEnumerator?.nextObject() as? URL {
            guard !Task.isCancelled else { break }

            if shouldSkip(url: url) {
                deepEnumerator?.skipDescendants()
                continue
            }

            scannedCount += 1
            let level = (deepEnumerator?.level ?? 0) + 1

            while stack.count > 1, let last = stack.last, last.depth >= level {
                finalizeDirectory(&stack, items: &items, minimumSize: minimumSize)
            }

            guard let values = try? url.resourceValues(forKeys: keys) else {
                skippedCount += 1
                continue
            }

            if values.isSymbolicLink == true {
                continue
            }

            let size = allocatedSize(from: values)

            if values.isDirectory == true {
                stack.append(
                    DirectoryFrame(
                        url: url,
                        depth: level,
                        size: size,
                        modifiedAt: values.contentModificationDate
                    )
                )
            } else {
                if !stack.isEmpty {
                    stack[stack.count - 1].size += size
                }

                if size >= minimumSize {
                    items.append(
                        StorageItem(
                            url: url,
                            size: size,
                            isDirectory: false,
                            category: classify(url: url, isDirectory: false),
                            modifiedAt: values.contentModificationDate
                        )
                    )
                }
            }

            if scannedCount % 350 == 0 {
                progress(
                    ScanProgress(
                        scannedCount: scannedCount,
                        skippedCount: skippedCount + skipCounter.count,
                        currentPath: url.path
                    )
                )
            }
        }

        while stack.count > 1 {
            finalizeDirectory(&stack, items: &items, minimumSize: minimumSize)
        }

        skippedCount += skipCounter.count

        progress(
            ScanProgress(
                scannedCount: scannedCount,
                skippedCount: skippedCount,
                currentPath: root.path
            )
        )
    }

    private static func finalizeDirectory(
        _ stack: inout [DirectoryFrame],
        items: inout [StorageItem],
        minimumSize: Int64
    ) {
        guard let frame = stack.popLast() else { return }

        if !stack.isEmpty {
            stack[stack.count - 1].size += frame.size
        }

        if frame.size >= minimumSize || isImportantDeveloperPath(frame.url) {
            items.append(
                StorageItem(
                    url: frame.url,
                    size: frame.size,
                    isDirectory: true,
                    category: classify(url: frame.url, isDirectory: true),
                    modifiedAt: frame.modifiedAt
                )
            )
        }
    }

    private static func allocatedSize(from values: URLResourceValues) -> Int64 {
        let size = values.totalFileAllocatedSize
            ?? values.fileAllocatedSize
            ?? values.fileSize
            ?? 0
        return Int64(size)
    }

    private static func shouldSkip(url: URL) -> Bool {
        let path = url.path
        let skippedRoots = [
            "/dev",
            "/net",
            "/Network",
            "/System/Volumes/Preboot",
            "/System/Volumes/Update",
            "/System/Volumes/VM",
            "/System/Volumes/iSCPreboot",
            "/System/Volumes/xarts",
            "/private/var/run",
            "/private/var/vm"
        ]

        return skippedRoots.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    private static func isImportantDeveloperPath(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        let name = url.lastPathComponent.lowercased()

        return name == "node_modules"
            || path.contains("/.npm")
            || path.contains("/.pnpm-store")
            || path.contains("/.yarn")
            || path.contains("/com.docker")
            || path.contains("/.docker")
            || path.contains("/.minikube")
            || path.contains("/.kube")
            || path.contains("/deriveddata")
            || path.contains("/coresimulator")
            || path.contains("/homebrew")
            || path.contains("/pip/cache")
            || path.contains("/pypoetry/cache")
            || path.contains("/pipenv")
            || path.contains("/.cache/uv")
            || path.contains("/.cache/pip")
            || path.contains("/.cargo/registry")
            || path.contains("/.cargo/git")
            || path.contains("/go/pkg/mod")
            || path.contains("/.cache/go-build")
            || path.contains("/.gradle")
            || path.contains("/.m2")
    }

    static func classify(url: URL, isDirectory: Bool) -> StorageCategory {
        let path = url.path
        let lowerPath = path.lowercased()
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()

        if name == "node_modules" || lowerPath.contains("/.npm") || lowerPath.contains("/.pnpm-store") || lowerPath.contains("/.yarn") {
            return .node
        }

        if lowerPath.contains("com.docker") || lowerPath.contains("/.docker") || lowerPath.contains("docker.raw") {
            return .docker
        }

        if lowerPath.contains("/.kube") || lowerPath.contains("/.minikube") || lowerPath.contains("/.kind") {
            return .kubernetes
        }

        if lowerPath.contains("/developer/xcode") || lowerPath.contains("/deriveddata") || lowerPath.contains("/coresimulator") {
            return .xcode
        }

        if lowerPath.contains("/homebrew") || lowerPath.contains("/.cache/homebrew") {
            return .homebrew
        }

        if lowerPath.contains("/pip/cache")
            || lowerPath.contains("/.cache/pip")
            || lowerPath.contains("/.cache/uv")
            || lowerPath.contains("/pypoetry/cache")
            || lowerPath.contains("/pipenv")
            || lowerPath.contains("/python/") && lowerPath.contains("/cache") {
            return .python
        }

        if lowerPath.contains("/.cargo/registry")
            || lowerPath.contains("/.cargo/git")
            || lowerPath.contains("/.rustup/downloads")
            || lowerPath.contains("/.rustup/tmp") {
            return .rust
        }

        if lowerPath.contains("/go/pkg/mod")
            || lowerPath.contains("/.cache/go-build")
            || lowerPath.contains("/library/caches/go-build") {
            return .go
        }

        if lowerPath.contains("/library/caches") || lowerPath.contains("/.cache/") {
            return .caches
        }

        if lowerPath.contains("/applications") || ext == "app" {
            return .apps
        }

        if lowerPath.hasPrefix("/system") || lowerPath.hasPrefix("/library") || lowerPath.hasPrefix("/usr") {
            return .system
        }

        if ["mp4", "mov", "m4v", "mkv", "avi", "webm", "mp3", "wav", "aiff", "flac", "jpg", "jpeg", "png", "heic", "tiff", "raw"].contains(ext) {
            return .media
        }

        if ["zip", "dmg", "pkg", "tar", "gz", "bz2", "xz", "7z", "rar", "iso"].contains(ext) {
            return .archives
        }

        if lowerPath.contains("/documents") || lowerPath.contains("/desktop") || lowerPath.contains("/downloads") {
            return .documents
        }

        return .other
    }
}
