import SwiftUI

struct SourceSectionView: View {
    let type: SourceType
    @ObservedObject var viewModel: SettingsViewModel

    @Environment(\.openWindow) private var openWindow

    private let unselectedID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题行
            SettingsHeader(
                title: "\(type.displayName) 环境配置",
                icon: type == .npm ? "network" : type == .yarn ? "screwdriver" : type == .pip ?
                    "shippingbox" : "terminal")
                .frame(height: 24, alignment: .leading)

            Spacer().frame(height: 12)

            // 配置文件路径
            configFileButton(for: type)
                .frame(height: 16, alignment: .leading)

            Spacer().frame(height: 16)

            // 核心配置卡片
            VStack(spacing: 0) {
                defaultSourcePicker

                Divider().opacity(0.5)

                // 列表高度增加：NPM/PIP/Yarn = 210, Git = 166
                SourceListView(sourceType: type, viewModel: viewModel)
                    .frame(height: type == .git ? 166 : 210)
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1))

            // 底部附加区域
            if type == .git {
                Spacer().frame(height: 12)

                HStack {
                    Toggle("仅针对 GitHub 生效", isOn: $viewModel.gitOnlyGithub)
                        .toggleStyle(.switch)
                        .scaleEffect(0.7)
                        .font(.system(size: 13))
                        .offset(x: -10)
                    Spacer()
                }
                .frame(height: 32)
            }
        }
    }

    private func configFileButton(for configType: SourceType) -> some View {
        HStack(spacing: 4) {
            Text("配置文件：")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button(configType.configPath.path) {
                let url = configType.configPath
                let path = url.path
                let text: String = if FileManager.default.fileExists(atPath: path) {
                    if
                        let data = try? Data(contentsOf: url),
                        let str = String(data: data, encoding: .utf8)
                    {
                        str.isEmpty ? "（文件为空）" : str
                    } else if
                        let data = try? Data(contentsOf: url),
                        let str = String(data: data, encoding: .isoLatin1)
                    {
                        str.isEmpty ? "（文件为空）" : str
                    } else {
                        "（文件读取失败）"
                    }
                } else {
                    "（文件不存在）"
                }
                openWindow(value: ConfigContent(path: path, content: text))
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color.accentColor)
            .lineLimit(1)
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
                    if type == .git || viewModel.activeSourceId(for: type) == nil {
                        Text(type == .git ? "关闭代理" : "自定义或未知").tag(unselectedID)
                    }

                    ForEach(viewModel.sources(for: type)) { source in
                        Text(source.name).tag(source.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }
}
