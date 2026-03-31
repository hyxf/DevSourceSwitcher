import os

def increase_content_height():
    files = {
        # 1. 窗口高度增加至 380
        r"DevSourceSwitcher/Views/SettingsView.swift": r"""import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SourceDetailView(viewModel: viewModel, type: .npm)
                .tabItem { Label("NPM 源", systemImage: "network") }
                .tag(0)

            SourceDetailView(viewModel: viewModel, type: .yarn)
                .tabItem { Label("Yarn 源", systemImage: "screwdriver") }
                .tag(1)

            SourceDetailView(viewModel: viewModel, type: .pip)
                .tabItem { Label("PIP 源", systemImage: "shippingbox") }
                .tag(2)
            
            SourceDetailView(viewModel: viewModel, type: .git)
                .tabItem { Label("Git 代理", systemImage: "terminal") }
                .tag(3)

            GeneralSettingsView(viewModel: viewModel)
                .tabItem { Label("通用", systemImage: "gearshape") }
                .tag(4)
        }
        .frame(width: 600, height: 380) // 窗口高度增加至 380
        .alert("切换失败", isPresented: Binding(
            get: { viewModel.lastError != nil },
            set: { if !$0 { viewModel.clearLastError() } }))
        {
            Button("确定") {}
        } message: {
            Text(viewModel.lastError ?? "未知错误")
        }
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showResetAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsHeader(title: "启动行为", icon: "power.circle")

                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text("开机自动启动").font(.system(size: 14))
                            Spacer()
                            LaunchAtLogin.Toggle("")
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 11)
                        .background(Color.primary.opacity(0.03))

                        Text("开启后，应用将在系统登录时自动运行，无需手动打开。")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                    }
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                        Color.primary.opacity(0.05),
                        lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 16) {
                    SettingsHeader(title: "数据管理", icon: "arrow.counterclockwise.circle")

                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("重置为默认配置").font(.system(size: 14))
                                Text("清除所有自定义源，恢复内置默认源列表。")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Button("重置") {
                                showResetAlert = true
                            }
                            .foregroundStyle(.red)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 11)
                        .background(Color.primary.opacity(0.03))
                    }
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                        Color.primary.opacity(0.05),
                        lineWidth: 1))
                }
            }
            .padding(.horizontal, 40).padding(.vertical, 24)
        }
        .alert("重置为默认配置", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("确认重置", role: .destructive) {
                viewModel.resetToDefault()
            }
        } message: {
            Text("此操作将清除所有自定义源，恢复内置默认源列表，无法撤销。")
        }
    }
}

struct SettingsHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 20, alignment: .center)
            Text(title).font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(Color.accentColor)
    }
}
""",

        # 2. 列表高度增加 30 像素
        r"DevSourceSwitcher/Views/SourceSectionView.swift": r"""import SwiftUI

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
                icon: type == .npm ? "network" : type == .yarn ? "screwdriver" : type == .pip ? "shippingbox" : "terminal")
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
                }))
            {
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
"""
    }

    for path, content in files.items():
        dir_name = os.path.dirname(path)
        if dir_name and not os.path.exists(dir_name):
            os.makedirs(dir_name)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Height Increased: {path}")

if __name__ == "__main__":
    increase_content_height()
