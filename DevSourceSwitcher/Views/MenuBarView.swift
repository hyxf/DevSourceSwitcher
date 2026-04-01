import SwiftUI

struct MenuBarView: View {
    @StateObject private var viewModel = MenuBarViewModel()
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
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
    private func sourceSubMenu(
        for type: SourceType,
        state: SourceToggleState,
        icon: String) -> some View
    {
        let title = switch type {
        case .npm: "NPM Registry"
        case .yarn: "Yarn Registry"
        case .pip: "PIP Index      "
        case .git: "Git Proxy      "
        }

        Menu {
            ForEach(state.allSources) { source in
                Toggle(source.name, isOn: Binding(
                    get: { state.activeSourceId == source.id },
                    set: { _ in viewModel.selectSource(source, for: type) }))
            }
            if type == .git, state.isEnabled {
                Divider()
                Button("未启用") { viewModel.selectSource(nil, for: .git) }
            }
        } label: {
            Label("\(title)\t - (\(state.activeName))", systemImage: icon)
        }
    }
}
