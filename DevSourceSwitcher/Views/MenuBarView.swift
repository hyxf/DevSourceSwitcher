import SwiftUI

struct MenuBarView: View {
    @StateObject private var viewModel = MenuBarViewModel()
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            sourceSubMenu(for: .npm, state: viewModel.npmState, icon: "shippingbox.fill")
            sourceSubMenu(for: .pip, state: viewModel.pipState, icon: "pyramid.fill")

            Divider()

            Button("设置...") { openSettings() }
            Button("刷新状态") { viewModel.refreshState() }

            Divider()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .onAppear { viewModel.refreshState() }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func sourceSubMenu(
        for type: SourceType,
        state: SourceToggleState,
        icon: String) -> some View
    {
        let title = type == .npm ? "NPM Registry" : "PIP Index"

        // 核心方案：在 macOS 原生菜单中，"\t" (Tab) 后的内容会自动实现右对齐布局
        let menuTitle = "\(title)\t - (\(state.activeName))"

        Menu(menuTitle) {
            ForEach(state.allSources) { source in
                Toggle(source.name, isOn: Binding(
                    get: { state.activeSourceId == source.id },
                    set: { _ in viewModel.selectSource(source, for: type) }))
            }
        }
    }
}
