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
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var config: AppConfig {
        manager.config
    }

    var activeNpmSourceId: UUID? {
        manager.activeNpmSourceId
    }

    var activePipSourceId: UUID? {
        manager.activePipSourceId
    }

    var lastError: String? {
        manager.lastError
    }

    func sources(for type: SourceType) -> [SourceItem] {
        config.sources(for: type)
    }

    func activeSourceId(for type: SourceType) -> UUID? {
        type == .npm ? activeNpmSourceId : activePipSourceId
    }

    func updateDefault(type: SourceType, id: UUID) {
        let source = config.sources(for: type).first { $0.id == id }
        manager.selectSource(source, for: type)
    }

    func addSource(type: SourceType, name: String, url: String) -> Bool {
        guard validate(name: name, url: url, for: type) else { return false }
        let item = SourceItem(name: name.trimmed, url: url.trimmed)
        if type == .npm { manager.config.npmSources.append(item) }
        else { manager.config.pipSources.append(item) }
        manager.saveConfig()
        return true
    }

    func updateSource(type: SourceType, id: UUID, name: String, url: String) -> Bool {
        guard validate(name: name, url: url, for: type, excludeId: id) else { return false }
        if type == .npm, let idx = manager.config.npmSources.firstIndex(where: { $0.id == id }) {
            manager.config.npmSources[idx].name = name.trimmed
            manager.config.npmSources[idx].url = url.trimmed
        } else if
            type == .pip,
            let idx = manager.config.pipSources.firstIndex(where: { $0.id == id })
        {
            manager.config.pipSources[idx].name = name.trimmed
            manager.config.pipSources[idx].url = url.trimmed
        }
        manager.saveConfig()
        return true
    }

    func deleteSource(type: SourceType, item: SourceItem) {
        guard !item.isBuiltIn else { return }
        if type == .npm {
            manager.config.npmSources.removeAll { $0.id == item.id }
        } else {
            manager.config.pipSources.removeAll { $0.id == item.id }
        }
        manager.saveConfig()
    }

    func resetToDefault() {
        let defaults = AppConfig.defaultConfig()
        manager.config = defaults
        manager.saveConfig()
        manager.selectSource(defaults.defaultNpmSource, for: .npm)
        manager.selectSource(defaults.defaultPipSource, for: .pip)
    }

    func refresh() {
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
        let trimmedName = name.trimmed
        if trimmedName.isEmpty { validationError = "名称不能为空"; return false }
        let existing = sources(for: type).filter { $0.id != excludeId }
        if existing.contains(where: { $0.name == trimmedName }) {
            validationError = "已存在同名源"; return false
        }
        let candidate = SourceItem(name: trimmedName, url: url.trimmed)
        if !candidate.isValidURL { validationError = "URL 格式无效"; return false }
        validationError = nil
        return true
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }
}
