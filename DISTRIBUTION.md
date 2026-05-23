# Distribution Guide

This is the recommended path for sharing Storage Sweep publicly from GitHub and `junaidshaukat.com`.

## Best Release Path

1. Push the source to a public GitHub repository.
2. Build a release zip and DMG with:

   ```zsh
   ./package-app.sh
   ```

3. Create a GitHub Release, for example `v1.0.0`.
4. Upload `.build/StorageSweep.dmg` and `.build/StorageSweep.zip` to the release.
5. Create a download page on `junaidshaukat.com` that links to the latest GitHub Release asset.
6. Post the page link on X and LinkedIn.

GitHub Releases are useful because people can verify versions, see changelogs, and download a stable asset. Your website should be the friendly landing page, not the only file host.

## Signing And Notarization

For early friends/testers, the unsigned DMG works, but macOS will show Gatekeeper warnings because it is not Developer ID signed or notarized.

Use this download link format on your website after creating a GitHub Release:

```text
https://github.com/junaiddshaukat/StorageSweep/releases/latest/download/StorageSweep.dmg
```

Unsigned install instructions:

1. Download `StorageSweep.dmg`.
2. Open the DMG.
3. Drag Storage Sweep to Applications.
4. Right-click Storage Sweep and choose Open.
5. Click Open in the warning.
6. If blocked, go to System Settings -> Privacy & Security -> Open Anyway.

For a public launch, sign and notarize the app with an Apple Developer account:

```zsh
codesign --force --deep --options runtime \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" \
  ".build/StorageSweep.app"

ditto -c -k --sequesterRsrc --keepParent \
  ".build/StorageSweep.app" ".build/StorageSweep.zip"

xcrun notarytool submit ".build/StorageSweep.zip" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password" \
  --wait

xcrun stapler staple ".build/StorageSweep.app"
```

After stapling, rebuild the zip from the stapled app:

```zsh
ditto -c -k --sequesterRsrc --keepParent \
  ".build/StorageSweep.app" ".build/StorageSweep.zip"
```

## Website Page Structure

Recommended page URL:

```text
https://junaidshaukat.com/storage-sweep
```

Recommended sections:

- Hero: Storage Sweep, a native Mac cleaner that shows what is using your disk.
- Primary button: Download for macOS. Link it to `https://github.com/junaiddshaukat/StorageSweep/releases/latest/download/StorageSweep.dmg`.
- Secondary button: View source on GitHub.
- Safety promise: moves files to Trash, blocks dangerous folders, labels Safe/Review/Protected.
- Screenshots: scanner list, safety labels, Clean Safe confirmation.
- How it works: Scan, review, clean safe items, empty Trash later.
- Full Disk Access note: optional, needed only for deeper scans.
- Changelog: link to GitHub Releases.

## Short Launch Copy

X:

```text
I built Storage Sweep, a tiny native Mac app that shows what is eating disk space and safely moves disposable caches/build files to Trash.

It labels items Safe / Review / Protected so you do not accidentally delete app data.

Download: https://junaidshaukat.com/storage-sweep
GitHub: <repo-url>
```

LinkedIn:

```text
I kept running out of storage on my Mac and wanted something simple, native, and transparent, so I built Storage Sweep.

It scans large files and developer-heavy folders like Node, Docker, Xcode, Homebrew, caches, and archives. The important part: it labels cleanup candidates as Safe, Review, or Protected, and the one-click cleanup only moves conservative cache/build/dependency items to Trash.

I am sharing it publicly for other Mac users and developers who want to understand where their storage went.

Download: https://junaidshaukat.com/storage-sweep
Source: <repo-url>
```

## AI Icon Prompt

Use this if you want to generate an alternate icon:

```text
Create a premium macOS app icon for an app named "Storage Sweep".

Concept: a clean turquoise-blue hard drive with a golden sweeping brush stroke crossing it, tiny white/mint sparkles, suggesting cleaning disk storage safely.

Style: modern Apple macOS Big Sur/Sonoma style app icon, rounded squircle shape, subtle depth, glossy but tasteful, high contrast, polished 3D/vector hybrid, no text, no letters, no watermark.

Composition: centered hard drive symbol, brush/sweep motion from lower-left to upper-right, dark navy background with soft teal glow, clear silhouette at small sizes.

Palette: deep navy background, cyan/turquoise drive, warm gold brush stroke, white/mint sparkles.

Output: 1024x1024 PNG app icon, transparent outside the rounded squircle if possible, clean edges, suitable for macOS Dock.
```
