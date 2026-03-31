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
        if trimmed.isEmpty { return false }

        // 增强校验：允许用户输入不带协议头的域名
        var testURL = trimmed
        if !testURL.contains("://") {
            testURL = "https://" + testURL
        }

        guard
            let components = URLComponents(string: testURL),
            let scheme = components.scheme?.lowercased(),
            ["https", "http", "socks5", "socks5h", "socks4", "socks"].contains(scheme),
            components.host?.isEmpty == false else { return false }
        return true
    }

    var normalizedURL: String {
        let lowercasedURL = url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var cleaned = lowercasedURL
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")

        if cleaned.contains("://") {
            // 对于非 Git 代理协议，剔除 http(s) 协议头
            if !cleaned.hasPrefix("socks"), !cleaned.contains("proxy") {
                cleaned = cleaned.replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
            }
        }

        return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }
}
