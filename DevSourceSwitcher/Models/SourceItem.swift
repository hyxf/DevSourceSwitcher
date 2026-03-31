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

    /// 验证 URL 是否为合法的 http/https 或代理地址
    var isValidURL: Bool {
        guard
            let components = URLComponents(string: url
                .trimmingCharacters(in: .whitespacesAndNewlines)),
            let scheme = components.scheme?.lowercased(),
            ["https", "http", "socks5", "socks5h", "socks4", "socks"].contains(scheme),
            components.host?.isEmpty == false else { return false }
        return true
    }

    /// 100% 对齐原始逻辑：针对 Git 代理做防碰撞优化
    var normalizedURL: String {
        let lowercasedURL = url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 针对 Git 代理常见的 socks 协议，保留协议头以防在匹配 ID 时与同端口的 http 代理产生碰撞
        if lowercasedURL.hasPrefix("socks") {
            return lowercasedURL
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        }

        // 原始逻辑：统一小写、去除协议前缀、去除引号、去除末尾斜杠
        var result = lowercasedURL
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")

        return result.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }
}
