# Storage Sweep

Storage Sweep is a small native macOS storage scanner built with SwiftUI. It helps you find large files, developer caches, build artifacts, Docker storage, Xcode data, package manager caches, archives, and other space-heavy folders.

The app is read-first and uses macOS Trash for deletion. It does not permanently delete files.

## Features

- Scan your Home folder, whole Macintosh HD, or any folder you choose.
- Scans start only when you click a scan button.
- Sort large files and folders by allocated disk size.
- Group results by category: Node, Docker, K8s, Xcode, Homebrew, Python, Rust, Go, Caches, Media, Archives, Apps, Documents, System, and Other.
- Label every item as Safe, Review, or Protected.
- Clean Safe moves auto-cleanable cache/build/dependency items to Trash in one action.
- Block deletion for broad protected locations such as `~/Library`, `/System`, `/Library`, app container roots, keychains, messages, and mail.
- Move allowed items to macOS Trash with confirmation.
- Reveal items in Finder and copy their paths.
- Export a plain-text storage report to share or compare before cleanup.

## Safety Labels

**Safe** means the item matches a commonly disposable pattern, such as caches, `node_modules`, package manager caches, or Xcode DerivedData. These can normally be recreated.

**Review** means deletion may be okay, but only after inspecting the item. This includes personal files, archives, app data, Docker storage, Kubernetes clusters, apps, and simulator data.

**Protected** means Storage Sweep blocks deletion because the path is too broad or too risky. Open the item in Finder and delete smaller known files only if you are certain.

## Clean Safe

Clean Safe is intentionally stricter than the Safe label. It targets disposable items such as:

- app and browser cache folders inside cache locations
- `node_modules`
- package-manager caches
- Python/PyPI, Rust/Cargo, and Go module/build caches
- Xcode DerivedData
- Homebrew cache

It does not auto-clean personal documents, media, app profiles, `Application Support`, `Containers`, `Group Containers`, Keychains, Mail, Messages, or protected system/account roots.

Clean Safe moves files to macOS Trash. Empty Trash later after you are satisfied apps and projects still behave normally.

## Good Cleanup Targets

These are usually reasonable to inspect and delete:

- `~/Library/Caches`
- `~/.cache`
- `node_modules`
- npm, pnpm, yarn, uv, pip/PyPI, Poetry, Pipenv, Cargo, Go, Gradle, and Maven caches
- Xcode `DerivedData`
- Old `.dmg`, `.zip`, `.pkg`, `.iso`, and other installers you no longer need
- Old videos or duplicated media you recognize

Use app-specific cleanup tools for these when possible:

- Docker images, volumes, and build cache
- Kubernetes, minikube, or kind clusters
- Xcode simulators and archives
- Homebrew cache

Avoid deleting these broad folders directly:

- `~/Library`
- `~/Library/Application Support`
- `~/Library/Containers`
- `~/Library/Group Containers`
- `/System`
- `/Library`
- `/Applications`

## Full Disk Access

macOS protects some locations. For deeper scans:

1. Open System Settings.
2. Go to Privacy & Security.
3. Open Full Disk Access.
4. Add Storage Sweep.
5. Quit and reopen the app.

The app also has a Full Disk Access button in the sidebar.

## Build

```zsh
swift build
```

## Build The App Bundle

```zsh
./build-app.sh
open ".build/StorageSweep.app"
```

## Create A Zip For Sharing

```zsh
./package-app.sh
```

The zip and DMG will be created at:

```text
.build/StorageSweep.zip
.build/StorageSweep.dmg
```

Because this is not Developer ID signed or notarized, macOS will show an unidentified developer warning after download. This is expected for an indie build without an Apple Developer account.

Users can still open it:

1. Download `StorageSweep.dmg`.
2. Open the DMG and drag Storage Sweep to Applications.
3. Right-click Storage Sweep and choose Open.
4. Click Open in the macOS warning.

If macOS blocks it completely, open System Settings -> Privacy & Security and click Open Anyway for Storage Sweep.

See [DISTRIBUTION.md](DISTRIBUTION.md) for the GitHub release, website page, signing, notarization, and launch-post checklist.
