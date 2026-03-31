import Combine
import Foundation

struct SourceToggleState: Equatable {
    var isEnabled: Bool = false
    var activeName: String = "官方源"
    var allSources: [SourceItem] = []
    var activeSourceId: UUID?
}

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var npmState: SourceToggleState = .init()
    @Published private(set) var yarnState: SourceToggleState = .init()
    @Published private(set) var pipState: SourceToggleState = .init()

    private let manager = SourceManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        manager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStates()
            }
            .store(in: &cancellables)

        updateStates()
    }

    func selectSource(_ source: SourceItem, for type: SourceType) {
        manager.selectSource(source, for: type)
    }

    func refreshState() {
        manager.refreshActiveSources()
    }

    private func updateStates() {
        npmState = makeState(for: .npm)
        yarnState = makeState(for: .yarn)
        pipState = makeState(for: .pip)
    }

    private func makeState(for type: SourceType) -> SourceToggleState {
        let config = manager.config
        let sources = config.sources(for: type)
        let activeId: UUID? = switch type {
        case .npm: manager.activeNpmSourceId
        case .yarn: manager.activeYarnSourceId
        case .pip: manager.activePipSourceId
        }

        let activeName: String = {
            if let id = activeId, let name = sources.first(where: { $0.id == id })?.name {
                return name
            }
            return "自定义源"
        }()

        return SourceToggleState(
            isEnabled: activeId != nil,
            activeName: activeName,
            allSources: sources,
            activeSourceId: activeId)
    }
}
