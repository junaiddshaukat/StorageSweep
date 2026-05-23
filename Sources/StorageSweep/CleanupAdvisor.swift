import Foundation

struct CleanupAssessment {
    let safety: CleanupSafety
    let note: String
}

enum CleanupAdvisor {
    static func assess(url: URL, isDirectory: Bool, category: StorageCategory) -> CleanupAssessment {
        let path = url.path
        let lowerPath = path.lowercased()
        let name = url.lastPathComponent.lowercased()
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path

        if isProtectedRoot(path: path, homePath: homePath) {
            return CleanupAssessment(
                safety: .protected,
                note: "This is a broad system, app, or account data folder. Open it and delete only specific files you understand."
            )
        }

        if lowerPath.contains("/library/application support/")
            || lowerPath.contains("/library/containers/")
            || lowerPath.contains("/library/group containers/") {
            return CleanupAssessment(
                safety: .review,
                note: "This is app data. Deleting it can sign you out, remove local databases, or reset an app."
            )
        }

        if category == .caches || lowerPath.contains("/library/caches/") || lowerPath.contains("/.cache/") {
            return CleanupAssessment(
                safety: .safe,
                note: "Cache data is usually recreated by apps. Quit related apps first, then move to Trash if you want the space back."
            )
        }

        if name == "node_modules" {
            return CleanupAssessment(
                safety: .safe,
                note: "Project dependencies can be reinstalled with npm, pnpm, or yarn. Keep it only if you need the project offline."
            )
        }

        if lowerPath.contains("/.npm")
            || lowerPath.contains("/.pnpm-store")
            || lowerPath.contains("/.yarn/cache")
            || lowerPath.contains("/.cache/yarn") {
            return CleanupAssessment(
                safety: .safe,
                note: "Package manager cache can normally be rebuilt by the package manager."
            )
        }

        if category == .python {
            return CleanupAssessment(
                safety: .safe,
                note: "Python package caches such as pip, PyPI wheels, Poetry, Pipenv, and uv can normally be downloaded again."
            )
        }

        if category == .rust {
            return CleanupAssessment(
                safety: .safe,
                note: "Cargo registry and git caches can be rebuilt by Cargo. Active project build output should be reviewed separately."
            )
        }

        if category == .go {
            return CleanupAssessment(
                safety: .safe,
                note: "Go module and build caches can be rebuilt by the Go toolchain."
            )
        }

        if lowerPath.contains("/deriveddata") {
            return CleanupAssessment(
                safety: .safe,
                note: "Xcode DerivedData is build output. Xcode will recreate it when projects build again."
            )
        }

        if lowerPath.contains("/coresimulator/caches") || lowerPath.contains("/developer/xcode/archives") {
            return CleanupAssessment(
                safety: .review,
                note: "Usually removable, but archives and simulator data may contain builds or local testing state you still need."
            )
        }

        if category == .homebrew && (lowerPath.contains("/caches/") || lowerPath.contains("/.cache/homebrew")) {
            return CleanupAssessment(
                safety: .safe,
                note: "Homebrew cache can be rebuilt. You can also use brew cleanup from Terminal."
            )
        }

        if category == .archives {
            return CleanupAssessment(
                safety: .review,
                note: "Archives and installers are often disposable, but confirm you do not need this exact file again."
            )
        }

        if category == .docker {
            return CleanupAssessment(
                safety: .review,
                note: "Prefer Docker Desktop or docker system prune for Docker storage. Do not delete Docker disk files while Docker is running."
            )
        }

        if category == .kubernetes {
            return CleanupAssessment(
                safety: .review,
                note: "Kubernetes, minikube, and kind data may include clusters and local volumes. Delete only if you can recreate them."
            )
        }

        if category == .media || category == .documents {
            return CleanupAssessment(
                safety: .review,
                note: "Personal files need your judgment. Reveal in Finder and confirm before deleting."
            )
        }

        if category == .apps {
            return CleanupAssessment(
                safety: .review,
                note: "Apps are better removed from Finder or the app's uninstaller so related helper files are handled properly."
            )
        }

        if category == .system {
            return CleanupAssessment(
                safety: .protected,
                note: "System locations should not be deleted from this app."
            )
        }

        return CleanupAssessment(
            safety: .review,
            note: "This does not match a known disposable pattern. Inspect it before deleting."
        )
    }

    static func canAutoClean(url: URL, isDirectory: Bool, category: StorageCategory, safety: CleanupSafety) -> Bool {
        guard safety == .safe else { return false }

        let path = url.path
        let lowerPath = path.lowercased()
        let name = url.lastPathComponent.lowercased()
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path

        let broadRoots = [
            "\(homePath)/Library/Caches",
            "\(homePath)/.cache",
            "\(homePath)/Library/Developer",
            "\(homePath)/Library/Developer/Xcode",
            "\(homePath)/Library/Developer/CoreSimulator"
        ]

        if broadRoots.contains(path) {
            return false
        }

        if lowerPath.contains("/library/application support/")
            || lowerPath.contains("/library/containers/")
            || lowerPath.contains("/library/group containers/")
            || lowerPath.contains("/library/preferences/")
            || lowerPath.contains("/library/keychains/")
            || lowerPath.contains("/library/mail/")
            || lowerPath.contains("/library/messages/") {
            return false
        }

        if name == "node_modules" {
            return true
        }

        if lowerPath.contains("/library/caches/")
            || lowerPath.contains("/.cache/")
            || lowerPath.contains("/.npm")
            || lowerPath.contains("/.pnpm-store")
            || lowerPath.contains("/.yarn/cache")
            || lowerPath.contains("/.cache/yarn")
            || lowerPath.contains("/pip/cache")
            || lowerPath.contains("/.cache/pip")
            || lowerPath.contains("/.cache/uv")
            || lowerPath.contains("/pypoetry/cache")
            || lowerPath.contains("/pipenv")
            || lowerPath.contains("/.cargo/registry")
            || lowerPath.contains("/.cargo/git")
            || lowerPath.contains("/.rustup/downloads")
            || lowerPath.contains("/.rustup/tmp")
            || lowerPath.contains("/go/pkg/mod")
            || lowerPath.contains("/.cache/go-build")
            || lowerPath.contains("/deriveddata")
            || lowerPath.contains("/.cache/homebrew") {
            return true
        }

        return category == .caches
    }


    private static func isProtectedRoot(path: String, homePath: String) -> Bool {
        let protectedExactPaths = [
            "/",
            "/Applications",
            "/Library",
            "/System",
            "/Users",
            "/bin",
            "/etc",
            "/opt",
            "/private",
            "/sbin",
            "/tmp",
            "/usr",
            "/var",
            homePath,
            "\(homePath)/Desktop",
            "\(homePath)/Documents",
            "\(homePath)/Downloads",
            "\(homePath)/Library",
            "\(homePath)/Movies",
            "\(homePath)/Music",
            "\(homePath)/Pictures",
            "\(homePath)/Public",
            "\(homePath)/Library/Application Support",
            "\(homePath)/Library/Containers",
            "\(homePath)/Library/Group Containers",
            "\(homePath)/Library/Preferences",
            "\(homePath)/Library/Keychains",
            "\(homePath)/Library/Mail",
            "\(homePath)/Library/Messages"
        ]

        return protectedExactPaths.contains(path)
    }
}
