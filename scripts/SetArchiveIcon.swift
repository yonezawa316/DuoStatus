import AppKit
import Foundation

// Finder metadata only: the ZIP data and checksum do not change. Uploading to a
// website may discard this outer icon; the app's embedded icon stays in the ZIP.
guard CommandLine.arguments.count == 3,
      let icon = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    print("Usage: SetArchiveIcon AppIcon.icns archive.zip")
    exit(1)
}
let archive = CommandLine.arguments[2]
guard archive.hasSuffix(".zip"), FileManager.default.fileExists(atPath: archive) else {
    print("Expected an existing ZIP archive.")
    exit(1)
}
guard NSWorkspace.shared.setIcon(icon, forFile: archive, options: []) else {
    print("Could not set the Finder icon. The ZIP contents are unchanged.")
    exit(1)
}
print("已设置分享包的 Finder 图标。")
