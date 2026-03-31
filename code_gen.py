import os

files = {}

files["DevSourceSwitcher/Views/SourceSectionView.swift"] = '''import SwiftUI

struct SourceSectionView: View {
    let type: SourceType
    @ObservedObject var viewModel: SettingsViewModel

    @Environment(\\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsHeader(
                title: "\\(type.displayName) 环境配置",
                icon: type == .npm ? "network" : type == .yarn ? "screwdriver" : "shippingbox")
                .frame(height: 20)

            configFileButton(for: type)

            VStack(spacing: 0) {
                defaultSourcePicker
                Divider().opacity(0.5)
                SourceListView(sourceType: type, viewModel: viewModel)
                    .frame(height: 280)
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1))
        }
    }

    // MARK: - Subviews

    @ViewBuilder
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
            Spacer()
        }
        .frame(height: 16)
    }

    private var defaultSourcePicker: some View {
        HStack {
            Text("当前生效源").font(.system(size: 13))
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.activeSourceId(for: type) ?? UUID() },
                set: { viewModel.updateDefault(type: type, id: $0) }))
            {
                if viewModel.activeSourceId(for: type) == nil {
                    Text("自定义或未知").tag(UUID())
                }
                ForEach(viewModel.sources(for: type)) { source in
                    Text(source.name).tag(source.id)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }
}
'''

for path, content in files.items():
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"已写入：{path}")
