import Foundation
import AppKit
import SwiftData
import CryptoKit

@Observable
final class ClipboardManager {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var modelContext: ModelContext

    var searchText: String = ""

    // Cached to avoid rebuilding from UserDefaults on every poll tick
    private var cachedExcludedApps: Set<String> = []
    private var excludedAppsNeedsRefresh = true

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(
            withTimeInterval: Constants.pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           excludedApps.contains(bundleID) {
            return
        }

        processClipboardContents(pasteboard)
    }

    private func processClipboardContents(_ pasteboard: NSPasteboard) {
        let sourceApp = NSWorkspace.shared.frontmostApplication
        let bundleID = sourceApp?.bundleIdentifier
        let appName = sourceApp?.localizedName

        // Priority: image > URL > file > color > text
        if let imageData = extractImage(from: pasteboard) {
            saveItem(type: .image, imageData: imageData,
                     plainText: "[Image]",
                     bundleID: bundleID, appName: appName)
        } else if let urlString = extractURL(from: pasteboard) {
            saveItem(type: .url, textContent: urlString,
                     plainText: urlString,
                     bundleID: bundleID, appName: appName)
        } else if let filePath = extractFileURL(from: pasteboard) {
            let fileName = URL(fileURLWithPath: filePath).lastPathComponent
            saveItem(type: .fileURL, textContent: filePath,
                     plainText: fileName,
                     bundleID: bundleID, appName: appName)
        } else if let colorHex = extractColor(from: pasteboard) {
            saveItem(type: .color, textContent: colorHex,
                     plainText: colorHex,
                     bundleID: bundleID, appName: appName)
        } else if let text = pasteboard.string(forType: .string) {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            saveItem(type: .text, textContent: text,
                     plainText: text,
                     bundleID: bundleID, appName: appName)
        }
    }

    // MARK: - Content Extraction

    private func extractImage(from pasteboard: NSPasteboard) -> Data? {
        if let tiffData = pasteboard.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiffData),
           let pngData = rep.representation(using: .png, properties: [:]) {
            return pngData
        }
        if let pngData = pasteboard.data(forType: .png) {
            return pngData
        }
        return nil
    }

    private func extractURL(from pasteboard: NSPasteboard) -> String? {
        if let urlString = pasteboard.string(forType: .URL) {
            return urlString
        }
        return nil
    }

    private func extractFileURL(from pasteboard: NSPasteboard) -> String? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                              options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = urls.first {
            return first.path
        }
        return nil
    }

    private func extractColor(from pasteboard: NSPasteboard) -> String? {
        if let colorData = pasteboard.data(forType: .color),
           let color = try? NSKeyedUnarchiver.unarchivedObject(
               ofClass: NSColor.self, from: colorData
           ) {
            let rgb = color.usingColorSpace(.sRGB)
            if let r = rgb?.redComponent, let g = rgb?.greenComponent,
               let b = rgb?.blueComponent {
                return String(format: "#%02X%02X%02X",
                              Int(r * 255), Int(g * 255), Int(b * 255))
            }
        }
        return nil
    }

    // MARK: - Persistence

    private func saveItem(
        type: ClipboardItemType,
        textContent: String? = nil,
        imageData: Data? = nil,
        plainText: String,
        bundleID: String?,
        appName: String?
    ) {
        let hashInput: Data
        if let imageData = imageData {
            hashInput = imageData
        } else if let text = textContent {
            hashInput = Data(text.utf8)
        } else {
            return
        }
        let hash = SHA256.hash(data: hashInput)
        let contentHash = hash.map { String(format: "%02x", $0) }.joined()

        // Deduplicate: if same hash exists, move it to now
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.contentHash == contentHash }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.createdAt = Date()
            try? modelContext.save()
            return
        }

        let item = ClipboardItem(
            type: type,
            textContent: textContent,
            imageData: imageData,
            plainText: plainText,
            contentHash: contentHash,
            sourceAppBundleID: bundleID,
            sourceAppName: appName
        )
        modelContext.insert(item)
        try? modelContext.save()

        enforceHistoryLimit()
    }

    private func enforceHistoryLimit() {
        let maxHistory = UserDefaults.standard.integer(forKey: Constants.maxHistoryKey)
        let limit = maxHistory > 0 ? maxHistory : Constants.maxHistoryDefault

        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.isPinned },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchOffset = limit

        if let excess = try? modelContext.fetch(descriptor) {
            for item in excess {
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }

    // MARK: - Public API

    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.itemType {
        case .text, .rtf:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let data = item.imageData {
                pasteboard.setData(data, forType: .png)
            }
        case .url:
            if let urlStr = item.textContent {
                pasteboard.setString(urlStr, forType: .string)
            }
        case .fileURL:
            if let path = item.textContent {
                let url = URL(fileURLWithPath: path)
                pasteboard.writeObjects([url as NSURL])
            }
        case .color:
            if let hex = item.textContent {
                pasteboard.setString(hex, forType: .string)
            }
        case .unknown:
            break
        }

        // Prevent re-capturing our own paste
        lastChangeCount = pasteboard.changeCount

        item.createdAt = Date()
        try? modelContext.save()
    }

    /// Copies the item to clipboard and simulates Cmd+V to paste into the active app.
    func copyAndPaste(_ item: ClipboardItem) {
        copyToClipboard(item)

        // Delay to let the panel close and focus return to the previous app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            Self.simulatePaste()
        }
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: CGEventSourceStateID.combinedSessionState)
        // kVK_ANSI_V = 0x09
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = CGEventFlags.maskCommand
        keyUp?.flags = CGEventFlags.maskCommand
        keyDown?.post(tap: CGEventTapLocation.cghidEventTap)
        keyUp?.post(tap: CGEventTapLocation.cghidEventTap)
    }

    func deleteItem(_ item: ClipboardItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    func clearHistory() {
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.isPinned }
        )
        if let items = try? modelContext.fetch(descriptor) {
            for item in items {
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }

    private var excludedApps: Set<String> {
        if excludedAppsNeedsRefresh {
            cachedExcludedApps = Set(UserDefaults.standard.stringArray(forKey: Constants.excludedAppsKey) ?? [])
            excludedAppsNeedsRefresh = false
        }
        return cachedExcludedApps
    }

    /// Call when the excluded apps list changes in Settings.
    func invalidateExcludedAppsCache() {
        excludedAppsNeedsRefresh = true
    }
}
