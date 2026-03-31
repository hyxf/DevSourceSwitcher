import SwiftUI

struct SourceSectionView: View {
    let type: SourceType
    @ObservedObject var viewModel: SettingsViewModel

    @Environment(\.openWindow) private var openWindow

    private let unselectedID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsHeader(
                title: "\(type.displayName) 环境配置",
                icon: type == .npm ? "network" : type == .yarn ? "screwdriver" : type == .pip ?
                    "shippingbox" : "terminal")
                .frame(height: 24, alignment: .leading)

            Spacer().frame(height: 12)
            configFileButton(for: type).frame(height: 16, alignment: .leading)
            Spacer().frame(height: 16)

            VStack(spacing: 0) {
                defaultSourcePicker
                Divider().opacity(0.5)
                SourceListView(sourceType: type, viewModel: viewModel)
                    .frame(height: type == .git ? 166 : 210)
            }
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                Color.primary.opacity(0.05),
                lineWidth: 1))

            if type == .git {
                Spacer().frame(height: 12)
                HStack {
                    Toggle("仅针对 GitHub 生效", isOn: $viewModel.gitOnlyGithub)
                        .toggleStyle(.switch).scaleEffect(0.7).font(.system(size: 13))
                        .offset(x: -10)
                    Spacer()
                }
                .frame(height: 32)
            }
        }
    }

    private func configFileButton(for configType: SourceType) -> some View {
        HStack(spacing: 4) {
            Text("配置文件：").font(.system(size: 11)).foregroundStyle(.secondary)
            Button(configType.configPath.path) {
                let url = configType.configPath
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? "（读取失败）"
                openWindow(value: ConfigContent(path: url.path, content: text))
            }.buttonStyle(.plain).font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.accentColor).lineLimit(1)
            Spacer()
        }
    }

    private var defaultSourcePicker: some View {
        HStack {
            Text(type == .git ? "当前生效代理" : "当前生效源").font(.system(size: 13))
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.activeSourceId(for: type) ?? unselectedID },
                set: { id in
                    viewModel.updateDefault(type: type, id: id == unselectedID ? nil : id)
                })) {
                    // 统一改为“未启用”
                    if type == .git || viewModel.activeSourceId(for: type) == nil {
                        Text("未启用").tag(unselectedID)
                    }
                    ForEach(viewModel.sources(for: type)) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.menu).frame(width: 160)
        }
        .padding(.horizontal, 12).padding(.vertical, 8).background(Color.primary.opacity(0.03))
    }
}
