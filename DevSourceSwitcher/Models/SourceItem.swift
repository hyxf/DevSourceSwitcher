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

    /// 验证 URL 是否为合法的 http/https 地址
    var isValidURL: Bool {
        guard
            let components = URLComponents(string: url
                .trimmingCharacters(in: .whitespacesAndNewlines)),
            components.scheme == "https" || components.scheme == "http",
            components.host?.isEmpty == false else { return false }
        return true
    }

    /// 用于比较的规范化 URL：统一小写、去除协议前缀、去除引号、去除末尾斜杠及空白符
    var normalizedURL: String {
        url.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }
}
