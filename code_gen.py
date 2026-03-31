import os

files_to_update = {
    "DevSourceSwitcher/Views/MenuBarView.swift": """
import SwiftUI

struct MenuBarView: View {
    @StateObject private var viewModel = MenuBarViewModel()
    @Environment(\\.openSettings) private var openSettings

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
        
        // 核心方案：在 macOS 原生菜单中，"\\t" (Tab) 后的内容会自动实现右对齐布局
        let menuTitle = "\\(title)\\t(\\(state.activeName))"

        Menu(menuTitle) {
            ForEach(state.allSources) { source in
                Toggle(source.name, isOn: Binding(
                    get: { state.activeSourceId == source.id },
                    set: { _ in viewModel.selectSource(source, for: type) }))
            }
        }
    }
}
"""
}

def apply_updates():
    for path, content in files_to_update.items():
        directory = os.path.dirname(path)
        if directory and not os.path.exists(directory):
            os.makedirs(directory)
        
        # 写入文件，\\t 在 Python 字符串中需正确转义
        final_content = content.strip().replace('\\\\t', '\\t').replace('\\\\', '\\')
        with open(path, "w", encoding="utf-8") as f:
            f.write(final_content + "\n")
        print(f"Successfully implemented right-alignment via Tab: {path}")

if __name__ == "__main__":
    apply_updates()
