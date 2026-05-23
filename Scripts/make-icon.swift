#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let source = resources.appendingPathComponent("AppIconSource.png")
let iconset = resources.appendingPathComponent("StorageSweep.iconset", isDirectory: true)
let preview = resources.appendingPathComponent("StorageSweepIcon.png")
let output = resources.appendingPathComponent("StorageSweep.icns")

guard let sourceImage = NSImage(contentsOf: source) else {
    throw NSError(
        domain: "StorageSweepIcon",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing icon source at \(source.path)"]
    )
}

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func squareCropRect(for image: NSImage) -> CGRect {
    let size = image.size
    let side = min(size.width, size.height)
    return CGRect(
        x: (size.width - side) / 2,
        y: (size.height - side) / 2,
        width: side,
        height: side
    )
}

func resizedIcon(size: Int) -> NSImage {
    let targetSize = NSSize(width: size, height: size)
    let image = NSImage(size: targetSize)
    let sourceRect = squareCropRect(for: sourceImage)

    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high
    sourceImage.draw(
        in: CGRect(origin: .zero, size: targetSize),
        from: sourceRect,
        operation: .copy,
        fraction: 1
    )

    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let data = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(
            domain: "StorageSweepIcon",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Could not render PNG"]
        )
    }

    try data.write(to: url)
}

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in outputs {
    try writePNG(resizedIcon(size: size), to: iconset.appendingPathComponent(name))
}

try writePNG(resizedIcon(size: 1024), to: preview)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c",
    "icns",
    iconset.path,
    "-o",
    output.path
]

try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(
        domain: "StorageSweepIcon",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "iconutil failed"]
    )
}

print(output.path)
