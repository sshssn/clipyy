import Foundation

enum ContentCategory: String, CaseIterable, Codable {
    case text
    case code
    case link
    case image
    case sensitive
    case file

    var label: String {
        switch self {
        case .text:      return "Text"
        case .code:      return "Code"
        case .link:      return "Links"
        case .image:     return "Images"
        case .sensitive: return "Sensitive"
        case .file:      return "Files"
        }
    }

    var iconName: String {
        switch self {
        case .text:      return "doc.text"
        case .code:      return "curlybraces"
        case .link:      return "link"
        case .image:     return "photo"
        case .sensitive: return "lock.fill"
        case .file:      return "doc"
        }
    }

    static func detect(text: String, type: ClipboardItemType) -> ContentCategory {
        switch type {
        case .image: return .image
        case .fileURL: return .file
        case .url: return .link
        default: break
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .text }

        if isSensitive(trimmed) { return .sensitive }
        if isCode(trimmed) { return .code }
        if isURL(trimmed) { return .link }

        return .text
    }

    private static func isSensitive(_ text: String) -> Bool {
        let tokenPrefixes = [
            "sk-", "pk_live_", "pk_test_", "sk_live_", "sk_test_",
            "AKIA", "ghp_", "gho_", "ghs_", "ghu_",
            "xoxb-", "xoxp-", "xoxa-", "xoxr-",
            "shpat_", "shpca_", "shppa_",
        ]
        for prefix in tokenPrefixes {
            if text.contains(prefix) { return true }
        }

        if text.hasPrefix("eyJ") && text.count > 30 { return true }
        if text.contains("-----BEGIN") || text.contains("PRIVATE KEY") { return true }
        if text.contains("Bearer ") && text.count > 20 { return true }

        let lowered = text.lowercased()
        let sensitiveKeys = [
            "password", "passwd", "secret", "token", "api_key", "apikey",
            "api-key", "auth_token", "access_key", "access_token",
            "private_key", "client_secret", "database_url", "db_password",
        ]
        for key in sensitiveKeys {
            if lowered.contains("\(key)=") || lowered.contains("\(key):") ||
               lowered.contains("\(key) =") || lowered.contains("\(key) :") {
                return true
            }
        }

        if lowered.contains("_key=") || lowered.contains("_secret=") ||
           lowered.contains("_token=") || lowered.contains("_password=") {
            return true
        }

        return false
    }

    private static func isCode(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count > 2 else { return false }

        var score = 0
        let keywords = [
            "func ", "class ", "struct ", "enum ", "import ",
            "def ", "return ", "if (", "for (", "while (",
            "const ", "function ", "var ", "let ",
            "public ", "private ", "static ", "override ",
            "try {", "catch {", "catch (", "async ", "await ",
            "#include", "#import", "package ",
        ]
        for keyword in keywords {
            if text.contains(keyword) { score += 1 }
        }

        if text.contains("->") || text.contains("=>") { score += 1 }
        if text.contains("{") && text.contains("}") { score += 1 }
        if text.contains("();") { score += 1 }

        let indentedLines = lines.filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }
        if indentedLines.count > lines.count / 3 { score += 2 }

        return score >= 3
    }

    private static func isURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("\n") else { return false }
        return trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("www.")
    }
}
