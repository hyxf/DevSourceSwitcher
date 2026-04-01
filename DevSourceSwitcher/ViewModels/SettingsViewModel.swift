import Combine
import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    private var manager = SourceManager.shared
    @Published private(set) var validationError: String?
    private var cancellables = Set<AnyCancellable>()

    init() {
        manager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var config: AppConfig {
        manager.config
    }

    var lastError: String? {
        manager.lastError
    }

    var gitOnlyGithub: Bool {
        get { config.gitOnlyGithub }
        set { manager.toggleGitOnlyGithub() }
    }

    var gitSupportSSH: Bool {
        get { config.gitSupportSSH }
        set { manager.toggleGitSupportSSH() }
    }

    func sources(for type: SourceType) -> [SourceItem] {
        config.sources(for: type)
    }

    func activeSourceId(for type: SourceType) -> UUID? {
        switch type {
        case .npm: manager.activeNpmSourceId
        case .yarn: manager.activeYarnSourceId
        case .pip: manager.activePipSourceId
        case .git: manager.activeGitSourceId
        }
    }

    /// 修改点：id 改为可选类型，支持传入 nil 以关闭代理/恢复官方源
    func updateDefault(type: SourceType, id: UUID?) {
        let source = id == nil ? nil : config.sources(for: type).first { $0.id == id }
        manager.selectSource(source, for: type)
    }

    func addSource(type: SourceType, name: String, url: String) -> Bool {
        guard validate(name: name, url: url, for: type) else { return false }
        let item = SourceItem(name: name.trimmed, url: url.trimmed)
        switch type {
        case .npm: manager.config.npmSources.append(item)
        case .yarn: manager.config.yarnSources.append(item)
        case .pip: manager.config.pipSources.append(item)
        case .git: manager.config.gitSources.append(item)
        }
        manager.saveConfig()
        return true
    }

    func updateSource(type: SourceType, id: UUID, name: String, url: String) -> Bool {
        guard validate(name: name, url: url, for: type, excludeId: id) else { return false }
        switch type {
        case .npm: if
            let i = manager.config.npmSources
                .firstIndex(where: { $0.id == id })
            {
                manager.config.npmSources[i].name = name.trimmed; manager.config.npmSources[i]
                    .url = url
                    .trimmed
            }
        case .yarn: if
            let i = manager.config.yarnSources
                .firstIndex(where: { $0.id == id })
            {
                manager.config.yarnSources[i].name = name.trimmed; manager.config.yarnSources[i]
                    .url = url.trimmed
            }
        case .pip: if
            let i = manager.config.pipSources
                .firstIndex(where: { $0.id == id })
            {
                manager.config.pipSources[i].name = name.trimmed; manager.config.pipSources[i]
                    .url = url
                    .trimmed
            }
        case .git: if
            let i = manager.config.gitSources
                .firstIndex(where: { $0.id == id })
            {
                manager.config.gitSources[i].name = name.trimmed; manager.config.gitSources[i]
                    .url = url
                    .trimmed
            }
        }
        manager.saveConfig()
        return true
    }

    func deleteSource(type: SourceType, item: SourceItem) {
        guard !item.isBuiltIn else { return }
        switch type {
        case .npm: manager.config.npmSources.removeAll { $0.id == item.id }
        case .yarn: manager.config.yarnSources.removeAll { $0.id == item.id }
        case .pip: manager.config.pipSources.removeAll { $0.id == item.id }
        case .git: manager.config.gitSources.removeAll { $0.id == item.id }
        }
        manager.saveConfig()
    }

    func resetToDefault() {
        let defaults = AppConfig.defaultConfig()
        manager.config = defaults
        manager.saveConfig()
        manager.refreshActiveSources()
    }

    func clearValidationError() {
        validationError = nil
    }

    func clearLastError() {
        manager.lastError = nil
    }

    private func validate(
        name: String,
        url: String,
        for type: SourceType,
        excludeId: UUID? = nil) -> Bool
    {
        if name.trimmed.isEmpty { validationError = "名称不能为空"; return false }
        if
            sources(for: type).filter({ $0.id != excludeId })
                .contains(where: { $0.name == name.trimmed })
        {
            validationError = "已存在同名源"; return false
        }
        if
            !SourceItem(name: name, url: url.trimmed)
                .isValidURL { validationError = "URL 格式无效"; return false }
        validationError = nil
        return true
    }
}

private extension String { var trimmed: String {
    trimmingCharacters(in: .whitespaces)
} }
