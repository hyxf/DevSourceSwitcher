import Combine
import Foundation

@MainActor
final class SourceManager: ObservableObject {
    static let shared = SourceManager()

    @Published var config: AppConfig
    @Published private(set) var activeNpmSourceId: UUID?
    @Published private(set) var activePipSourceId: UUID?
    @Published var lastError: String?

    private let storage = ConfigStorageService.shared
    private let registry = RegistryService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        config = storage.load()
        refreshActiveSources()

        NotificationCenter.default.publisher(for: .configDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshActiveSources()
            }
            .store(in: &cancellables)
    }

    func refreshActiveSources() {
        config = storage.load()
        activeNpmSourceId = resolveActiveId(for: .npm)
        activePipSourceId = resolveActiveId(for: .pip)
    }

    func selectSource(_ source: SourceItem?, for type: SourceType) {
        do {
            lastError = nil
            try registry.switchRegistry(to: source, for: type)
            refreshActiveSources()
        } catch {
            lastError = error.localizedDescription
            print("[SourceManager] 切换失败: \(error.localizedDescription)")
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
