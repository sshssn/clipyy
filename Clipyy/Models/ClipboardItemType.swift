import Foundation

enum ClipboardItemType: String, Codable, CaseIterable {
    case text
    case image
    case url
    case fileURL
    case color
    case rtf
    case unknown

    var iconName: String {
        switch self {
        case .text:    return "doc.text"
        case .image:   return "photo"
        case .url:     return "link"
        case .fileURL: return "doc"
        case .color:   return "paintpalette"
        case .rtf:     return "doc.richtext"
        case .unknown: return "questionmark.square"
        }
    }

    var label: String {
        switch self {
        case .text:    return "Text"
        case .image:   return "Image"
        case .url:     return "URL"
        case .fileURL: return "File"
        case .color:   return "Color"
        case .rtf:     return "Rich Text"
        case .unknown: return "Unknown"
        }
    }
}
