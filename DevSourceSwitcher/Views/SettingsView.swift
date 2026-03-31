import SwiftUI

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
