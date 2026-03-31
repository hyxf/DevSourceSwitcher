import os

def apply_final_comprehensive_fixes():
    files = {
        # 1. 增强 SourceItem：匹配逻辑增加对大小写和非标准格式的兼容
        r"DevSourceSwitcher/Models/SourceItem.swift": r"""import Foundation

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
""",

        # 2. 增强 RegistryService：Key 匹配不区分大小写，增强解析鲁棒性
        r"DevSourceSwitcher/Services/RegistryService.swift": r"""import Foundation

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
        let sections = ["[http \"https://github.com\"]", "[https \"https://github.com\"]", "[http]", "[https]"]
        for section in sections {
            if let val = getValueFromSection(lines, section: section, key: "proxy") { return val }
        }
        return nil
    }

    private func getValueFromSection(_ lines: [String], section: String, key: String) -> String? {
        var inSection = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased() == section.lowercased() { inSection = true; continue }
            if inSection, trimmed.hasPrefix("[") { break }
            if inSection, let eqRange = trimmed.range(of: "=") {
                // 审计修正：Key 匹配不区分大小写
                let k = trimmed[..<eqRange.lowerBound].trimmingCharacters(in: .whitespaces)
                if k.lowercased() == key.lowercased() {
                    return trimmed[eqRange.upperBound...].trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
            }
        }
        return nil
    }

    private func parseYarnRegistry(from content: String) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), trimmed.lowercased().hasPrefix("registry ") else { continue }
            return trimmed.dropFirst("registry ".count).trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        return nil
    }

    private func writeRegistry(to source: SourceItem?, for type: SourceType) throws {
        let targetURL = source?.url ?? type.officialURL
        let fileURL = type.configPath
        BackupService.shared.backup(filePath: fileURL.path)
        if !fileManager.fileExists(atPath: fileURL.deletingLastPathComponent().path) {
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        let existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        var lines = existing.components(separatedBy: .newlines)
        if type == .git {
            lines = updateGitProxy(lines, proxy: targetURL, onlyGithub: ConfigStorageService.shared.load().gitOnlyGithub)
        } else {
            lines = updatedContent(lines, url: targetURL, for: type)
            if type == .pip { lines = updateTrustedHost(lines, host: httpHost(from: targetURL)) }
        }
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
        lines.append("")
        try lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func updateGitProxy(_ lines: [String], proxy: String, onlyGithub: Bool) -> [String] {
        var lines = lines
        let global = ["[http]", "[https]"], github = ["[http \"https://github.com\"]", "[https \"https://github.com\"]"]
        for s in global + github { lines = removeKeyFromSection(lines, section: s, key: "proxy") }
        if !proxy.isEmpty {
            for s in onlyGithub ? github : global { lines = addOrUpdateKeyInSection(lines, section: s, key: "proxy", value: proxy) }
        }
        return lines
    }

    private func removeKeyFromSection(_ lines: [String], section: String, key: String) -> [String] {
        var lines = lines, i = 0, inSection = false
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased() == section.lowercased() { inSection = true; i += 1; continue }
            if inSection, trimmed.hasPrefix("[") { inSection = false }
            if inSection, let eqRange = trimmed.range(of: "=") {
                if trimmed[..<eqRange.lowerBound].trimmingCharacters(in: .whitespaces).lowercased() == key.lowercased() {
                    lines.remove(at: i); continue
                }
            }
            i += 1
        }
        if let idx = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).lowercased() == section.lowercased() }) {
            if isSectionEmpty(lines, afterIndex: idx) {
                lines.remove(at: idx)
                if idx > 0, lines[idx - 1].trimmingCharacters(in: .whitespaces).isEmpty { lines.remove(at: idx - 1) }
            }
        }
        return lines
    }

    private func isSectionEmpty(_ lines: [String], afterIndex sectionIdx: Int) -> Bool {
        for i in (sectionIdx + 1) ..< lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") { break }
            if !trimmed.isEmpty { return false }
        }
        return true
    }

    private func addOrUpdateKeyInSection(_ lines: [String], section: String, key: String, value: String) -> [String] {
        var lines = lines
        if let idx = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).lowercased() == section.lowercased() }) {
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
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.hasPrefix("#"), !t.hasPrefix(";"), let eq = t.range(of: "=") else { return false }
                return t[..<eq.lowerBound].trimmingCharacters(in: .whitespaces).lowercased() == key.lowercased()
            }
            lines.insert("\(key)=\(url)", at: 0)
        } else if type == .yarn {
            lines.removeAll { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                return !t.hasPrefix("#") && t.lowercased().hasPrefix("\(key.lowercased()) ")
            }
            lines.insert("\(key) \"\(url)\"", at: 0)
        } else {
            if let idx = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).lowercased() == "[global]" }) {
                var found = false
                for i in (idx + 1) ..< lines.count {
                    let line = lines[i].trimmingCharacters(in: .whitespaces)
                    if line.hasPrefix("[") { break }
                    if let eq = line.range(of: "="), line[..<eq.lowerBound].trimmingCharacters(in: .whitespaces).lowercased() == key.lowercased() {
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
        if let idx = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).lowercased() == "[install]" }) {
            var foundIdx: Int?
            for i in (idx + 1) ..< lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("[") { break }
                if let eq = t.range(of: "="), t[..<eq.lowerBound].trimmingCharacters(in: .whitespaces).lowercased() == key { foundIdx = i; break }
            }
            if let host {
                if let f = foundIdx { lines[f] = "\(key) = \(host)" } else { lines.insert("\(key) = \(host)", at: idx + 1) }
            } else {
                if let f = foundIdx { lines.remove(at: f) }
                if isSectionEmpty(lines, afterIndex: idx) {
                    lines.remove(at: idx)
                    if idx > 0, lines[idx - 1].trimmingCharacters(in: .whitespaces).isEmpty { lines.remove(at: idx - 1) }
                }
            }
        } else if let host {
            lines.append(""); lines.append("[install]"); lines.append("\(key) = \(host)")
        }
        return lines
    }

    private func httpHost(from url: String) -> String? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comp = URLComponents(string: trimmed), let host = comp.host else { return nil }
        return host
    }
}
""",

        # 3. 增强 SourceEditorView：大小写不敏感的前缀剔除
        r"DevSourceSwitcher/Views/SourceEditorView.swift": r"""import SwiftUI

struct SourceEditorView: View {
    enum Mode { case add(SourceType); case edit(SourceItem, SourceType) }
    let mode: Mode; let onSave: (String, String) -> Bool; let validationError: String?; let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var protocolType: String = "socks5h://"
    @State private var host: String = ""

    private var sourceType: SourceType {
        switch mode { case .add(let t): return t; case .edit(_, let t): return t }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(sourceType == .git ? "配置代理地址" : "配置源地址").font(.headline)
            Form {
                TextField("名称", text: $name)
                if sourceType == .git {
                    HStack(spacing: 8) {
                        Picker("", selection: $protocolType) {
                            ForEach(["http://", "https://", "socks5://", "socks5h://"], id: \.self) { Text($0) }
                        }.labelsHidden().frame(width: 100)
                        TextField("127.0.0.1:7891", text: $host)
                    }
                } else {
                    TextField("URL", text: $host)
                }
            }.formStyle(.grouped)

            if let error = validationError { Text(error).font(.caption).foregroundStyle(.red) }

            HStack {
                Spacer()
                Button("取消") { onDismiss() }
                Button("保存") {
                    let cleanedHost = sanitizeHost(host)
                    let finalURL = sourceType == .git ? "\(protocolType)\(cleanedHost)" : cleanedHost
                    if onSave(name, finalURL) { onDismiss() }
                }.disabled(name.isEmpty || host.isEmpty).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 380)
        .onAppear {
            if case .edit(let item, let type) = mode {
                name = item.name
                if type == .git {
                    let protocols = ["socks5h://", "socks5://", "https://", "http://", "socks4://", "socks://"]
                    // 审计修正：使用 range(of:options:) 实现大小写不敏感匹配
                    if let foundProto = protocols.first(where: { item.url.range(of: $0, options: [.anchored, .caseInsensitive]) != nil }) {
                        protocolType = foundProto.lowercased()
                        host = String(item.url.dropFirst(foundProto.count))
                    } else { host = item.url }
                } else { host = item.url }
            }
        }
    }

    private func sanitizeHost(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let protocols = ["socks5h://", "socks5://", "socks4://", "socks://", "https://", "http://"]
        for proto in protocols {
            if trimmed.range(of: proto, options: [.anchored, .caseInsensitive]) != nil {
                return String(trimmed.dropFirst(proto.count))
            }
        }
        return trimmed
    }
}
""",

        # 4. 增强 MenuBarView：增加错误提示，防止静默失败
        r"DevSourceSwitcher/Views/MenuBarView.swift": r"""import SwiftUI

struct MenuBarView: View {
    @StateObject private var viewModel = MenuBarViewModel()
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            // 审计修复：如果发生错误，在菜单顶部显示明显的错误提示
            if let error = viewModel.lastError {
                Text("⚠️ 切换失败").font(.headline).foregroundStyle(.red)
                Text(error).font(.caption).foregroundStyle(.secondary)
                Divider()
            }

            sourceSubMenu(for: .npm, state: viewModel.npmState, icon: "shippingbox.fill")
            sourceSubMenu(for: .yarn, state: viewModel.yarnState, icon: "screwdriver")
            sourceSubMenu(for: .pip, state: viewModel.pipState, icon: "pyramid.fill")
            sourceSubMenu(for: .git, state: viewModel.gitState, icon: "terminal.fill")

            Divider()
            Button("设置...") { openSettings() }
            Divider()
            Button("退出") { NSApplication.shared.terminate(nil) }
        }
        .onAppear { viewModel.refreshState() }
    }

    @ViewBuilder
    private func sourceSubMenu(for type: SourceType, state: SourceToggleState, icon: String) -> some View {
        let title: String = {
            switch type {
            case .npm: return "NPM Registry"
            case .yarn: return "Yarn Registry"
            case .pip: return "PIP Index      "
            case .git: return "Git Proxy      "
            }
        }()
        
        Menu("\(title)\t - (\(state.activeName))") {
            ForEach(state.allSources) { source in
                Toggle(source.name, isOn: Binding(
                    get: { state.activeSourceId == source.id },
                    set: { _ in viewModel.selectSource(source, for: type) }))
            }
            if type == .git && state.isEnabled {
                Divider()
                Button("关闭代理") { viewModel.selectSource(nil, for: .git) }
            }
        }
    }
}
""",

        # 5. 增强 MenuBarViewModel：暴露错误状态给视图
        r"DevSourceSwitcher/ViewModels/MenuBarViewModel.swift": r"""import Combine
import Foundation

struct SourceToggleState: Equatable {
    var isEnabled: Bool = false
    var activeName: String = "未启用"
    var allSources: [SourceItem] = []
    var activeSourceId: UUID?
}

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var npmState: SourceToggleState = .init()
    @Published private(set) var yarnState: SourceToggleState = .init()
    @Published private(set) var pipState: SourceToggleState = .init()
    @Published private(set) var gitState: SourceToggleState = .init()
    
    // 审计修复：暴露 lastError 给 MenuBarView
    var lastError: String? { manager.lastError }

    private let manager = SourceManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        manager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStates() }
            .store(in: &cancellables)
        updateStates()
    }

    func selectSource(_ source: SourceItem?, for type: SourceType) {
        if type == .git && source != nil && gitState.activeSourceId == source?.id {
            manager.selectSource(nil, for: .git)
        } else {
            manager.selectSource(source, for: type)
        }
    }

    private func updateStates() {
        npmState = makeState(for: .npm)
        yarnState = makeState(for: .yarn)
        pipState = makeState(for: .pip)
        gitState = makeState(for: .git)
    }

    func refreshState() { manager.refreshActiveSources() }

    private func makeState(for type: SourceType) -> SourceToggleState {
        let config = manager.config
        let sources = config.sources(for: type)
        let activeId: UUID? = {
            switch type {
            case .npm: return manager.activeNpmSourceId
            case .yarn: return manager.activeYarnSourceId
            case .pip: return manager.activePipSourceId
            case .git: return manager.activeGitSourceId
            }
        }()

        let activeName: String = {
            if let id = activeId, let name = sources.first(where: { $0.id == id })?.name { return name }
            return type == .git ? "未启用" : "自定义源"
        }()

        return SourceToggleState(
            isEnabled: activeId != nil,
            activeName: activeName,
            allSources: sources,
            activeSourceId: activeId)
    }
}
"""
    }

    for path, content in files.items():
        dir_name = os.path.dirname(path)
        if dir_name and not os.path.exists(dir_name): os.makedirs(dir_name)
        with open(path, "w", encoding="utf-8") as f: f.write(content)
        print(f"Final Fix Applied: {path}")

if __name__ == "__main__":
    apply_final_comprehensive_fixes()
