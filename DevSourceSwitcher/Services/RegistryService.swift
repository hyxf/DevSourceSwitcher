import Foundation

final class RegistryService: SourceConfigServiceProtocol {
    static let shared = RegistryService()
    private let fileManager = FileManager.default

    private init() {}

    func switchRegistry(to source: SourceItem?, for type: SourceType) throws {
        let targetURL = source?.url ?? type.officialURL
        let fileURL = type.configPath
        let dir = fileURL.deletingLastPathComponent()

        BackupService.shared.backup(filePath: fileURL.path)

        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        var lines = existing.components(separatedBy: .newlines)
        lines = updatedContent(lines, url: targetURL, for: type)

        if type == .pip {
            let host = httpHost(from: targetURL)
            lines = updateTrustedHost(lines, host: host)
        }

        // 移除末尾连续空行，保留最多一个换行结尾
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            lines.removeLast()
        }
        lines.append("")

        try lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func currentRegistryURL(for type: SourceType) -> String? {
        guard let content = try? String(contentsOf: type.configPath, encoding: .utf8) else {
            return nil
        }
        return FileParser.parseValue(from: content, key: type.registryKey)
    }

    // MARK: - Private

    /// 若 url 为 http:// 开头则返回 host，否则返回 nil
    private func httpHost(from url: String) -> String? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            trimmed.lowercased().hasPrefix("http://"),
            let components = URLComponents(string: trimmed),
            let host = components.host, !host.isEmpty else { return nil }
        return host
    }

    /// 检查某个 section 下（从 sectionIdx+1 开始）是否还有实质内容
    private func isSectionEmpty(_ lines: [String], afterIndex sectionIdx: Int) -> Bool {
        for i in (sectionIdx + 1) ..< lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") { break }
            if !trimmed.isEmpty { return false }
        }
        return true
    }

    /// 更新 [install] 节的 trusted-host：host 非 nil 时写入，nil 时移除
    private func updateTrustedHost(_ lines: [String], host: String?) -> [String] {
        var lines = lines
        let key = "trusted-host"

        if
            let installIdx = lines.firstIndex(where: {
                $0.trimmingCharacters(in: .whitespaces).lowercased() == "[install]"
            })
        {
            var foundIdx: Int?
            for i in (installIdx + 1) ..< lines.count {
                let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("[") { break }
                if let eqRange = trimmed.range(of: "=") {
                    let k = trimmed[..<eqRange.lowerBound].trimmingCharacters(in: .whitespaces)
                    if k == key {
                        foundIdx = i
                        break
                    }
                }
            }

            if let host {
                if let idx = foundIdx {
                    lines[idx] = "\(key) = \(host)"
                } else {
                    lines.insert("\(key) = \(host)", at: installIdx + 1)
                }
            } else {
                if let idx = foundIdx {
                    lines.remove(at: idx)
                }
                // 移除后重新检查 [install] 节是否为空，为空则移除节头
                if isSectionEmpty(lines, afterIndex: installIdx) {
                    lines.remove(at: installIdx)
                    // 同时移除节头前的空行
                    if
                        installIdx > 0,
                        lines[installIdx - 1].trimmingCharacters(in: .whitespaces).isEmpty
                    {
                        lines.remove(at: installIdx - 1)
                    }
                }
            }
        } else {
            if let host {
                lines.append("")
                lines.append("[install]")
                lines.append("\(key) = \(host)")
            }
        }

        return lines
    }

    private func updatedContent(_ lines: [String], url: String, for type: SourceType) -> [String] {
        var lines = lines
        let key = type.registryKey

        if type == .npm {
            lines.removeAll { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard
                    !trimmed.hasPrefix("#"), !trimmed.hasPrefix(";"),
                    let eqRange = trimmed.range(of: "=") else { return false }
                return trimmed[..<eqRange.lowerBound].trimmingCharacters(in: .whitespaces) == key
            }
            lines.insert("\(key)=\(url)", at: 0)
        } else {
            if
                let globalIdx = lines.firstIndex(where: {
                    $0.trimmingCharacters(in: .whitespaces).lowercased() == "[global]"
                })
            {
                var foundInGlobal = false
                for i in (globalIdx + 1) ..< lines.count {
                    let line = lines[i].trimmingCharacters(in: .whitespaces)
                    if line.hasPrefix("[") { break }
                    if let eqRange = line.range(of: "=") {
                        let k = line[..<eqRange.lowerBound].trimmingCharacters(in: .whitespaces)
                        if k == key {
                            lines[i] = "\(key) = \(url)"
                            foundInGlobal = true
                            break
                        }
                    }
                }
                if !foundInGlobal {
                    lines.insert("\(key) = \(url)", at: globalIdx + 1)
                }
            } else {
                lines.insert("[global]", at: 0)
                lines.insert("\(key) = \(url)", at: 1)
            }
        }

        return lines
    }
}
