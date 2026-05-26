import Foundation
import SwiftData

@Model
final class ClipboardItem {
    var id: UUID
    var typeRaw: String
    var textContent: String?
    @Attribute(.externalStorage)
    var imageData: Data?
    var thumbnailData: Data?
    var plainText: String
    var contentHash: String
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var createdAt: Date
    var isPinned: Bool
    var categoryRaw: String = "text"
    var pinboard: Pinboard?

    var itemType: ClipboardItemType {
        get { ClipboardItemType(rawValue: typeRaw) ?? .unknown }
        set { typeRaw = newValue.rawValue }
    }

    var category: ContentCategory {
        get { ContentCategory(rawValue: categoryRaw) ?? .text }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        type: ClipboardItemType,
        textContent: String? = nil,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        plainText: String,
        contentHash: String,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        category: ContentCategory = .text
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.textContent = textContent
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.plainText = plainText
        self.contentHash = contentHash
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.createdAt = Date()
        self.isPinned = false
        self.categoryRaw = category.rawValue
        self.pinboard = nil
    }
}
