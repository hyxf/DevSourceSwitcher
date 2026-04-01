import Combine
import Foundation

@MainActor
final class SourceManager: ObservableObject {
    static let shared = SourceManager()

    @Published var config: AppConfig
    @Published private(set) var activeNpmSourceId: UUID?
    @Published private(set) var activeYarnSourceId: UUID?
    @Published private(set) var activePipSourceId: UUID?
    @Published private(set) var activeGitSourceId: UUID?
    @Published var lastError: String?

    private let storage = ConfigStorageService.shared
    private let registry = RegistryService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        config = storage.load()
        refreshActiveSources()

        NotificationCenter.default.publisher(for: .configDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshActiveSources() }
            .store(in: &cancellables)
    }

    func refreshActiveSources() {
        config = storage.load()
        activeNpmSourceId = resolveActiveId(for: .npm)
        activeYarnSourceId = resolveActiveId(for: .yarn)
        activePipSourceId = resolveActiveId(for: .pip)
        activeGitSourceId = resolveActiveId(for: .git)
    }

    func selectSource(_ source: SourceItem?, for type: SourceType) {
        do {
            lastError = nil
            try registry.switchRegistry(to: source, for: type)
            // 修复：source 为 nil（未启用）时不触发 SSH 更新，避免意外清除 SSH 配置
            // SSH 的移除只由 toggleGitSupportSSH() 关闭开关时负责
            if type == .git, config.gitSupportSSH, let proxyURL = source?.url {
                registry.updateSSHConfig(proxy: proxyURL, onlyGithub: config.gitOnlyGithub)
            }
            refreshActiveSources()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func toggleGitOnlyGithub() {
        config.gitOnlyGithub.toggle()
        saveConfig()

        let currentURL = registry.currentRegistryURL(for: .git) ?? ""
        if let source = config.gitSources.first(where: { $0.id == activeGitSourceId }) {
            // 如果当前是已知源，重新应用它
            selectSource(source, for: .git)
        } else if !currentURL.isEmpty {
            // 如果当前是自定义代理，以当前 URL 重新应用配置
            let tempSource = SourceItem(name: "Custom", url: currentURL)
            selectSource(tempSource, for: .git)
        } else {
            // 否则维持未启用状态
            selectSource(nil, for: .git)
        }
    }

    func toggleGitSupportSSH() {
        config.gitSupportSSH.toggle()
        saveConfig()

        if config.gitSupportSSH {
            // 开启：将当前代理同步写入 SSH 配置
            let currentURL = registry.currentRegistryURL(for: .git) ?? ""
            let proxyURL = currentURL.isEmpty ? nil : currentURL
            registry.updateSSHConfig(proxy: proxyURL, onlyGithub: config.gitOnlyGithub)
        } else {
            // 关闭：移除 SSH 配置中的代理
            registry.updateSSHConfig(proxy: nil, onlyGithub: config.gitOnlyGithub)
        }
    }

    func saveConfig() {
        try? storage.save(config)
    }

    private func resolveActiveId(for type: SourceType) -> UUID? {
        let currentURL = registry.currentRegistryURL(for: type) ?? ""
        return config.matchedSourceId(for: type, url: currentURL)
    }
}
