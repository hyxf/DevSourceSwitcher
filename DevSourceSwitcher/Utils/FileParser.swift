import Foundation

enum FileParser {
    static func parseValue(from content: String, key: String) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), !trimmed.hasPrefix(";") else { continue }

            guard let eqRange = trimmed.range(of: "=") else { continue }

            let currentKey = trimmed[..<eqRange.lowerBound].trimmingCharacters(in: .whitespaces)
            guard currentKey.lowercased() == key.lowercased() else { continue }

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
