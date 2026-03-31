import Foundation

final class RegistryService: SourceConfigServiceProtocol {
    static let shared = RegistryService()
    private let fileManager = FileManager.default

    private init() {}

    func switchRegistry(to source: SourceItem?, for type: SourceType) throws {
        try writeRegistry(to: source, for: type)
    }

    func currentRegistryURL(for type: SourceType) -> String? {
        guard let content = try? String(contentsOf: type.configPath, encoding: .utf8) else { return nil }
        if type == .yarn { return parseYarnRegistry(from: content) }
        if type == .git { return parseGitProxy(from: content) }

        let url = FileParser.parseValue(from: content, key: type.registryKey)
        if type == .pip, let foundURL = url, foundURL.lowercased().hasPrefix("http://") {
            let host = httpHost(from: foundURL)
            let lines = content.components(separatedBy: .newlines)
            let trustedHost = getValueFromSection(lines, section: "[install]", key: "trusted-host")
            if host?.lowercased() != trustedHost?.lowercased() { return nil }
        }
        return url
    }

    private func parseGitProxy(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        let sections = [
            "[http \"https://github.com\"]",
            "[https \"https://github.com\"]",
            "[http]",
            "[https]"
        ]
        let keys = ["proxy", "http.proxy", "https.proxy"]
        for section in sections {
            for key in keys {
                if let val = getValueFromSection(lines, section: section, key: key) { return val }
            }
        }
        return nil
    }

    private func getValueFromSection(_ lines: [String], section: String, key: String) -> String? {
        var inSection = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased() == section.lowercased() { inSection = true; continue }
            if inSection, trimmed.hasPrefix("[") { break }
            if inSection, let eqRange = trimmed.range(of: "=") {
                let k = trimmed[..<eqRange.lowerBound]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if k.lowercased() == key.lowercased() {
                    let rawValue = trimmed[eqRange.upperBound...]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanValue = rawValue
                        .components(separatedBy: CharacterSet(charactersIn: "#;")).first ?? ""
                    return cleanValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
            }
        }
        return nil
    }

    private func parseYarnRegistry(from content: String) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.hasPrefix("#"), !trimmed.isEmpty else { continue }

            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 2 {
                let key = parts[0].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":"))
                if key == "registry" {
                    return parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
            }
        }
        return nil
    }

    private func writeRegistry(to source: SourceItem?, for type: SourceType) throws {
        let targetURL = source?.url ?? type.officialURL
        let fileURL = type.configPath
        BackupService.shared.backup(filePath: fileURL.path)
        if !fileManager.fileExists(atPath: fileURL.deletingLastPathComponent().path) {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
        }
        let existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        var lines = existing.components(separatedBy: .newlines)
        if type == .git {
            lines = updateGitProxy(
                lines,
                proxy: targetURL,
                onlyGithub: ConfigStorageService.shared.load().gitOnlyGithub)
        } else {
            lines = updatedContent(lines, url: targetURL, for: type)
            if type == .pip {
                let host = httpHost(from: targetURL)
                lines = updateTrustedHost(lines, host: host)
            }
        }
        while
            lines.last?.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == true
        {
            lines.removeLast()
        }
        if !lines.isEmpty { lines.append("") }
        try lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func updateGitProxy(_ lines: [String], proxy: String, onlyGithub: Bool) -> [String] {
        var lines = lines
        let global = ["[http]", "[https]"], github = [
            "[http \"https://github.com\"]",
            "[https \"https://github.com\"]"
        ]
        let proxyKeys = ["proxy", "http.proxy", "https.proxy"]
        for s in global + github {
            for key in proxyKeys {
                lines = removeKeyFromSection(lines, section: s, key: key)
            }
        }
        if !proxy.isEmpty {
            for s in onlyGithub ? github : global {
                lines = addOrUpdateKeyInSection(
                    lines,
                    section: s,
                    key: "proxy",
                    value: proxy)
            }
        }
        return lines
    }

    private func removeKeyFromSection(_ lines: [String], section: String, key: String) -> [String] {
        var lines = lines, i = 0, inSection = false
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased() == section.lowercased() { inSection = true; i += 1; continue }
            if inSection, trimmed.hasPrefix("[") { inSection = false }
            if inSection, let eq = trimmed.range(of: "=") {
                if
                    trimmed[..<eq.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased() == key.lowercased()
                {
                    lines.remove(at: i); continue
                }
            }
            i += 1
        }
        if
            let idx = lines
                .firstIndex(where: {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == section
                        .lowercased()
                })
        {
            if isSectionEmpty(lines, afterIndex: idx) {
                lines.remove(at: idx)
                if
                    idx > 0,
                    lines[idx - 1].trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty { lines.remove(at: idx - 1) }
            }
        }
        return lines
    }

    private func isSectionEmpty(_ lines: [String], afterIndex sectionIdx: Int) -> Bool {
        for i in (sectionIdx + 1) ..< lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") { break }
            if !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix(";") { return false }
        }
        return true
    }

    private func addOrUpdateKeyInSection(
        _ lines: [String],
        section: String,
        key: String,
        value: String) -> [String]
    {
        var lines = lines
        if
            let idx = lines
                .firstIndex(where: {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == section
                        .lowercased()
                })
        {
            lines.insert("\t\(key) = \(value)", at: idx + 1)
        } else {
            lines.append(""); lines.append(section); lines.append("\t\(key) = \(value)")
        }
        return lines
    }

    private func updatedContent(_ lines: [String], url: String, for type: SourceType) -> [String] {
        var lines = lines, key = type.registryKey
        if type == .npm {
            lines.removeAll { line in
                let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard
                    !t.hasPrefix("#"), !t.hasPrefix(";"),
                    let eq = t.range(of: "=") else { return false }
                return t[..<eq.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() == key.lowercased()
            }
            lines.insert("\(key)=\(url)", at: 0)
        } else if type == .yarn {
            lines.removeAll { line in
                let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.hasPrefix("#"), !t.isEmpty else { return false }
                let parts = t.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                return parts.count >= 2 && parts[0].lowercased() == "registry"
            }
            lines.insert("\(key) \"\(url)\"", at: 0)
        } else {
            if
                let idx = lines
                    .firstIndex(where: {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "[global]"
                    })
            {
                var found = false
                for i in (idx + 1) ..< lines.count {
                    let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                    if line.hasPrefix("[") { break }
                    if
                        let eq = line.range(of: "="),
                        line[..<eq.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                            .lowercased() == key.lowercased()
                    {
                        lines[i] = "\(key) = \(url)"; found = true; break
                    }
                }
                if !found { lines.insert("\(key) = \(url)", at: idx + 1) }
            } else {
                lines.insert("[global]", at: 0); lines.insert("\(key) = \(url)", at: 1)
            }
        }
        return lines
    }

    private func updateTrustedHost(_ lines: [String], host: String?) -> [String] {
        var lines = lines, key = "trusted-host"
        if
            let idx = lines
                .firstIndex(where: {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "[install]"
                })
        {
            var foundIdx: Int?
            for i in (idx + 1) ..< lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                if t.hasPrefix("[") { break }
                if
                    let eq = t.range(of: "="),
                    t[..<eq.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased() == key { foundIdx = i; break }
            }
            if let host {
                if let f = foundIdx { lines[f] = "\(key) = \(host)" } else { lines.insert(
                    "\(key) = \(host)",
                    at: idx + 1) }
            } else {
                if let f = foundIdx { lines.remove(at: f) }
                if isSectionEmpty(lines, afterIndex: idx) {
                    lines.remove(at: idx)
                    if
                        idx > 0,
                        lines[idx - 1].trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty { lines.remove(at: idx - 1) }
                }
            }
        } else if let host {
            lines.append(""); lines.append("[install]"); lines.append("\(key) = \(host)")
        }
        return lines
    }

    private func httpHost(from url: String) -> String? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("http://") else { return nil }
        guard let comp = URLComponents(string: trimmed), let host = comp.host else { return nil }
        return host
    }
}
