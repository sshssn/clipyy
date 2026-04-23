import Foundation
import SwiftData

@Model
final class Pinboard {
    var id: UUID
    var name: String
    var icon: String
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ClipboardItem.pinboard)
    var items: [ClipboardItem]

    init(name: String, icon: String = "pin", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.items = []
    }
}
