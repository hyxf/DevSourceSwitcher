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

    // MARK: - SSH Config

    private let sshBlockMarker = "# Added by DevSourceSwitcher"

    /// 更新 ~/.ssh/config 中的 GitHub SSH 代理配置
    func updateSSHConfig(proxy: String?, onlyGithub: Bool) {
        let sshConfigURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh/config")
        let sshDir = sshConfigURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: sshDir.path) {
            try? fileManager.createDirectory(at: sshDir, withIntermediateDirectories: true)
        }

        let existing = (try? String(contentsOf: sshConfigURL, encoding: .utf8)) ?? ""
        var lines = existing.components(separatedBy: "\n")

        if
            let proxy, !proxy.isEmpty,
            let proxyCommand = buildProxyCommand(from: proxy)
        {
            lines = upsertSSHBlock(lines, proxyCommand: proxyCommand)
        } else {
            lines = removeSSHBlock(lines)
        }

        while lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            lines.removeLast()
        }
        lines.append("")

        try? lines.joined(separator: "\n").write(
            to: sshConfigURL,
            atomically: true,
            encoding: .utf8)
    }

    /// 开启：
    /// 1. 先 removeSSHBlock 清理（幂等）
    /// 2. 若存在原有 Host github.com 块 → 将其每行加 `# ` 注释
    /// 3. 新块始终追加到文件末尾，前置两个空行
    private func upsertSSHBlock(_ lines: [String], proxyCommand: String) -> [String] {
        // 先清理（幂等），同时恢复之前注释的原始块
        var result = removeSSHBlock(lines)

        // 若存在原有 Host github.com 块，将其注释掉
        if let blockRange = findGithubHostBlock(result) {
            let commented = result[blockRange].map { line -> String in
                line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? line : "# \(line)"
            }
            result.replaceSubrange(blockRange, with: commented)
        }

        // 新块始终追加到文件末尾，前置两个空行
        let newBlock: [String] = [
            "",
            "",
            sshBlockMarker,
            "Host github.com",
            "  HostName ssh.github.com",
            "  Port 443",
            "  User git",
            "  IdentityFile ~/.ssh/id_rsa",
            "  ProxyCommand \(proxyCommand)"
        ]
        result.append(contentsOf: newBlock)

        return result
    }

    /// 关闭：
    /// 1. 通过标记行精确定位并移除本工具写入的块
    /// 2. 将紧邻上方被注释的原始块恢复
    private func removeSSHBlock(_ lines: [String]) -> [String] {
        var result = lines

        guard
            let markerIdx = result.firstIndex(where: {
                $0.trimmingCharacters(in: .whitespacesAndNewlines) == sshBlockMarker
            }) else
        {
            return result
        }

        let blockStart = markerIdx + 1
        guard
            blockStart < result.count,
            result[blockStart].trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == "host github.com" else
        {
            result.remove(at: markerIdx)
            return result
        }

        // 确定本工具块结束位置
        var blockEnd = blockStart + 1
        while blockEnd < result.count {
            let trimmed = result[blockEnd].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix("host ") { break }
            blockEnd += 1
        }

        // 移除：前置空行 + 标记行 + 本工具块
        var removeStart = markerIdx
        // 往上最多移除两个空行
        var blankCount = 0
        while removeStart > 0, blankCount < 2 {
            if result[removeStart - 1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                removeStart -= 1
                blankCount += 1
            } else {
                break
            }
        }
        result.removeSubrange(removeStart ..< blockEnd)

        // 恢复紧接在 removeStart 之前的被注释原始块
        var restoreEnd = removeStart
        var restoreStart = removeStart - 1
        while restoreStart >= 0 {
            let trimmed = result[restoreStart].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("#") || trimmed.isEmpty {
                restoreStart -= 1
            } else {
                break
            }
        }
        restoreStart += 1

        let candidateLines = Array(result[restoreStart ..< restoreEnd])
        let hasCommentedHost = candidateLines.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased().hasPrefix("# host github.com")
        }
        if hasCommentedHost {
            let restored = candidateLines.map { line -> String in
                var t = line
                if t.hasPrefix("# ") { t = String(t.dropFirst(2)) }
                else if t == "#" { t = "" }
                return t
            }
            result.replaceSubrange(restoreStart ..< restoreEnd, with: restored)
        }

        return result
    }

    /// 返回未被注释的 Host github.com 块的行范围
    private func findGithubHostBlock(_ lines: [String]) -> Range<Int>? {
        guard
            let startIdx = lines.firstIndex(where: {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "host github.com"
            }) else { return nil }

        var endIdx = startIdx + 1
        while endIdx < lines.count {
            let trimmed = lines[endIdx].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix("host ") { break }
            endIdx += 1
        }
        return startIdx ..< endIdx
    }

    /// 根据代理协议生成对应的 ProxyCommand
    private func buildProxyCommand(from proxy: String) -> String? {
        guard let (host, port) = parseProxyHostPort(proxy) else { return nil }
        let lower = proxy.lowercased()
        if lower.hasPrefix("socks5") {
            return "nc -x \(host):\(port) -X 5 %h %p"
        } else if lower.hasPrefix("http") {
            return "nc -x \(host):\(port) -X connect %h %p"
        }
        return "nc -x \(host):\(port) -X 5 %h %p"
    }

    /// 从代理 URL 中解析 host 和 port
    private func parseProxyHostPort(_ proxy: String) -> (String, String)? {
        let schemes = ["socks5h://", "socks5://", "socks4://", "http://", "https://"]
        var rest = proxy
        for scheme in schemes {
            if proxy.lowercased().hasPrefix(scheme) {
                rest = String(proxy.dropFirst(scheme.count))
                break
            }
        }
        let parts = rest.components(separatedBy: ":")
        if parts.count >= 2 {
            let host = parts[0]
            let port = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return (host, port)
        }
        return nil
    }

    // MARK: - Private (原有方法不变)

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
                let key = parts[0].lowercased()
                    .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
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
