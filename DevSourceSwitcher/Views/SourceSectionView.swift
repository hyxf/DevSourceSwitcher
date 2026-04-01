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
            configFileRow(for: type).frame(height: 16, alignment: .leading)
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
                    Toggle("支持 SSH", isOn: $viewModel.gitSupportSSH)
                        .toggleStyle(.switch).scaleEffect(0.7).font(.system(size: 13))
                        .offset(x: -10)
                    Spacer()
                }
                .frame(height: 32)
            }
        }
    }

    /// 配置文件行：.gitconfig 始终显示，SSH 配置文件仅在支持 SSH 开启时显示
    private func configFileRow(for configType: SourceType) -> some View {
        HStack(spacing: 12) {
            configFileButton(path: configType.configPath.path) {
                let url = configType.configPath
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? "（读取失败）"
                openWindow(value: ConfigContent(path: url.path, content: text))
            }

            if configType == .git, viewModel.gitSupportSSH {
                let sshConfigURL = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".ssh/config")
                configFileButton(path: sshConfigURL.path) {
                    let text = (try? String(contentsOf: sshConfigURL, encoding: .utf8)) ?? "（读取失败）"
                    openWindow(value: ConfigContent(path: sshConfigURL.path, content: text))
                }
            }

            Spacer()
        }
    }

    private func configFileButton(path: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text("配置文件：").font(.system(size: 11)).foregroundStyle(.secondary)
            Button(path) {
                action()
            }.buttonStyle(.plain).font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.accentColor).lineLimit(1)
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
                    if type == .git {
                        // Git 逻辑：始终支持"未启用"选项
                        if viewModel.activeSourceId(for: type) == nil {
                            let currentVal = RegistryService.shared
                                .currentRegistryURL(for: .git) ?? ""
                            Text(currentVal.isEmpty ? "未启用" : "自定义代理").tag(unselectedID)
                        } else {
                            Text("未启用").tag(unselectedID)
                        }
                    } else {
                        // NPM/Yarn/PIP 逻辑：不支持"未启用"，仅在不匹配列表时显示"自定义源"
                        if viewModel.activeSourceId(for: type) == nil {
                            Text("自定义源").tag(unselectedID)
                        }
                    }

                    ForEach(viewModel.sources(for: type)) { source in
                        Text(source.name).tag(source.id)
                    }
                }
                .pickerStyle(.menu).frame(width: 160)
        }
        .padding(.horizontal, 12).padding(.vertical, 8).background(Color.primary.opacity(0.03))
    }
}
