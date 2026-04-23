import Foundation
import SwiftData

@Model
final class ClipboardItem {
    var id: UUID
    var typeRaw: String
    var textContent: String?
    @Attribute(.externalStorage)
    var imageData: Data?
    var plainText: String
    var contentHash: String
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var createdAt: Date
    var isPinned: Bool
    var pinboard: Pinboard?

    var itemType: ClipboardItemType {
        get { ClipboardItemType(rawValue: typeRaw) ?? .unknown }
        set { typeRaw = newValue.rawValue }
    }

    init(
        type: ClipboardItemType,
        textContent: String? = nil,
        imageData: Data? = nil,
        plainText: String,
        contentHash: String,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.textContent = textContent
        self.imageData = imageData
        self.plainText = plainText
        self.contentHash = contentHash
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.createdAt = Date()
        self.isPinned = false
        self.pinboard = nil
    }
}
