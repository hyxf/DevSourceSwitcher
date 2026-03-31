import os

files = {}

files["DevSourceSwitcher/Views/SettingsView.swift"] = '''import SwiftUI

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

            GeneralSettingsView(viewModel: viewModel)
                .tabItem { Label("通用", systemImage: "gearshape") }
                .tag(3)

            AboutView()
                .tabItem { Label("关于", systemImage: "info.circle") }
                .tag(4)
        }
        .frame(width: 600, height: 440)
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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 15, weight: .bold))
            Text(title).font(.system(size: 15, weight: .bold))
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "shippingbox.fill").font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(spacing: 8) {
                Text("Dev Source Switcher").font(.title2).bold()
                Text("Version 1.6.0").font(.subheadline).foregroundStyle(Color.secondary)
            }
            Divider().frame(width: 150)
            Text("© 2025 DevSource Team").font(.system(size: 11))
                .foregroundStyle(Color.secondary.opacity(0.6))
            Spacer()
        }
    }
}
'''

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
                .font(.system(size: 12))
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
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Color.accentColor)
            Spacer()
        }
    }

    private var defaultSourcePicker: some View {
        HStack {
            Text("当前生效源").font(.system(size: 14))
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
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color.primary.opacity(0.03))
    }
}
'''

files["DevSourceSwitcher/Views/SourceListView.swift"] = '''import SwiftUI

struct SourceListView: View {
    let sourceType: SourceType
    @ObservedObject var viewModel: SettingsViewModel

    @State private var selectedSource: SourceItem?
    @State private var showAddSheet = false
    @State private var editingSource: SourceItem?

    var body: some View {
        VStack(spacing: 0) {
            sourceList
            Divider()
            toolbar
        }
        .sheet(isPresented: $showAddSheet, onDismiss: { viewModel.clearValidationError() }) {
            SourceEditorView(
                mode: .add(sourceType),
                onSave: { name, url in
                    viewModel.addSource(type: sourceType, name: name, url: url)
                },
                validationError: viewModel.validationError,
                onDismiss: { showAddSheet = false })
        }
        .sheet(item: $editingSource, onDismiss: { viewModel.clearValidationError() }) { source in
            SourceEditorView(
                mode: .edit(source, sourceType),
                onSave: { name, url in
                    viewModel.updateSource(type: sourceType, id: source.id, name: name, url: url)
                },
                validationError: viewModel.validationError,
                onDismiss: { editingSource = nil })
        }
    }

    // MARK: - Subviews

    private var sourceList: some View {
        List(viewModel.sources(for: sourceType), selection: $selectedSource) { source in
            SourceRowView(
                source: source,
                isDefault: source.id == viewModel.activeSourceId(for: sourceType))
                .tag(source)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            toolbarButton(icon: "plus") {
                showAddSheet = true
            }
            Divider().frame(height: 16)
            toolbarButton(icon: "minus", disabled: selectedSource?.isBuiltIn != false) {
                if let s = selectedSource { viewModel.deleteSource(type: sourceType, item: s) }
            }
            Divider().frame(height: 16)
            toolbarButton(
                icon: "pencil",
                disabled: selectedSource == nil || selectedSource?.isBuiltIn == true)
            {
                editingSource = selectedSource
            }
            Spacer()
        }
        .background(Color.primary.opacity(0.02))
    }

    private func toolbarButton(
        icon: String,
        disabled: Bool = false,
        action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 36, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - SourceRowView

struct SourceRowView: View {
    let source: SourceItem
    let isDefault: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(source.name).font(.system(size: 13, weight: .medium))

                    if source.isBuiltIn {
                        Text("系统")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().stroke(
                                Color.secondary.opacity(0.3),
                                lineWidth: 0.5))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(source.url)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isDefault {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.green.opacity(0.8))
            }
        }
        .padding(.vertical, 5)
    }
}
'''

files["DevSourceSwitcher/Views/SourceEditorView.swift"] = '''import SwiftUI

struct SourceEditorView: View {
    enum Mode {
        case add(SourceType)
        case edit(SourceItem, SourceType)
    }

    let mode: Mode
    let onSave: (String, String) -> Bool
    let validationError: String?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var url: String = ""

    private var title: String {
        switch mode {
        case let .add(type): "新增 \\(type.displayName) 源"
        case let .edit(item, type): "编辑 \\(type.displayName) 源：\\(item.name)"
        }
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty ||
            url.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.headline)

            Form {
                TextField("名称", text: $name)
                TextField("URL（https://...）", text: $url)
            }
            .formStyle(.grouped)

            Group {
                if let error = validationError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                } else {
                    Text(" ").font(.footnote)
                }
            }

            HStack {
                Spacer()
                Button("取消") { onDismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("保存") {
                    if onSave(name, url) { onDismiss() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaveDisabled)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            if case let .edit(item, _) = mode {
                name = item.name
                url = item.url
            }
        }
    }
}
'''

for path, content in files.items():
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"已写入：{path}")
