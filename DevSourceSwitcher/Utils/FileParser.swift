import Foundation

/// 纯函数工具：解析 key=value 格式的配置文件
enum FileParser {
    /// 从配置文本中提取指定 key 的值。
    /// 支持 `key=value`、`key = value` 两种格式；忽略 # 和 ; 注释行，支持过滤行尾注释。
    static func parseValue(from content: String, key: String) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), !trimmed.hasPrefix(";") else { continue }

            // 寻找第一个等号位置
            guard let eqRange = trimmed.range(of: "=") else { continue }

            // 提取 Key 并校验
            let currentKey = trimmed[..<eqRange.lowerBound].trimmingCharacters(in: .whitespaces)
            guard currentKey == key else { continue }

            // 提取 Value 并移除行尾注释（# 或 ; 之后的内容）
            let rawValue = trimmed[eqRange.upperBound...].trimmingCharacters(in: .whitespaces)
            let valueWithoutComment = rawValue
                .components(separatedBy: CharacterSet(charactersIn: "#;")).first ?? ""

            let value = valueWithoutComment
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            return value.isEmpty ? nil : value
        }
        return nil
    }
}
