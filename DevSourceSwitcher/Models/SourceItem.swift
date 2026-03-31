import Foundation

struct SourceItem: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var url: String
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, url: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.isBuiltIn = isBuiltIn
    }

    var isValidURL: Bool {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(),
            ["https", "http", "socks5", "socks5h", "socks4", "socks"].contains(scheme),
            components.host?.isEmpty == false else { return false }
        return true
    }

    var normalizedURL: String {
        let lowercasedURL = url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = lowercasedURL
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))

        // Git 代理特殊处理：保留所有协议头（包括 http）以确保匹配的唯一性
        // NPM/PIP 保持传统：剔除 http(s) 以实现最大兼容
        if cleaned.contains("://") {
            if cleaned.hasPrefix("socks") || cleaned.contains("proxy") { return cleaned }
        }

        return cleaned
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }
}
