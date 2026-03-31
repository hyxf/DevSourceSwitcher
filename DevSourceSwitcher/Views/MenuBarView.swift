import SwiftUI

struct MenuBarView: View {
    @StateObject private var viewModel = MenuBarViewModel()
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
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
        // 修正：通过补齐空格，确保不同长度的标题在 \t 后能对齐
        let title = switch type {
        case .npm: "NPM Registry"
        case .yarn: "Yarn Registry"
        case .pip: "PIP Index      " // 补齐到 Yarn Registry 的长度
        case .git: "Git Proxy      " // 补齐到 Yarn Registry 的长度
        }

        Menu("\(title)\t - (\(state.activeName))") {
            ForEach(state.allSources) { source in
                Toggle(source.name, isOn: Binding(
                    get: { state.activeSourceId == source.id },
                    set: { _ in viewModel.selectSource(source, for: type) }))
            }
            if type == .git, state.isEnabled {
                Divider()
                Button("关闭代理") { viewModel.selectSource(nil, for: .git) }
            }
        }
    }
}
