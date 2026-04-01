# DevSourceSwitcher

一个 macOS 菜单栏工具，用于快速切换开发环境的镜像源与代理配置，支持 NPM、Yarn、PIP、Git。

---

## 功能

- 🚀 菜单栏一键切换 NPM / Yarn / PIP 镜像源
- 🔀 Git 代理快速切换，支持 SOCKS5 / HTTP 协议
- 🔒 支持仅对 GitHub 生效的定向代理配置
- 🛡️ 支持 SSH 代理同步写入 `~/.ssh/config`
- 📁 自定义源管理，支持增删改
- 💾 配置变更自动备份原始文件

---

## 环境要求

- macOS 13.0+
- Xcode 15.0+

---

## 安装

### 方式一：从源码构建

```bash
git clone https://github.com/hyxf/DevSourceSwitcher.git

cd DevSourceSwitcher

brew install xcodegen

xcodegen generate

open DevSourceSwitcher.xcodeproj
```

在 Xcode 中选择目标设备为 **My Mac**，点击 Run 或按 `⌘R` 构建运行。

### 方式二：下载 Release

前往 [Releases](https://github.com/hyxf/DevSourceSwitcher/releases) 页面下载最新的 `.dmg` 文件，拖入 Applications 文件夹即可。

---

## 使用

### 切换镜像源

点击菜单栏图标，在对应的 NPM / Yarn / PIP / Git 子菜单中选择目标源即可立即生效。

### 添加自定义源

打开 **设置 → 对应 Tab**，点击底部 `+` 按钮填写名称和地址后保存。

### Git 代理

在 **设置 → Git 代理** 中：

- **仅针对 GitHub 生效**：开启后代理只写入 `[http "https://github.com"]` 区块，不影响其他 Git 服务
- **支持 SSH**：开启后同步将代理配置写入 `~/.ssh/config`，适用于 SSH 方式克隆的仓库

> SSH 代理依赖系统自带的 `nc`（netcat），请确认可用。

### 配置文件

设置页面中点击配置文件路径可直接查看当前文件内容。所有写入操作前会自动备份为同路径 `.backup` 文件。

### 配置校验

npm

```
npm config get registry
```

yarn

```
yarn config get registry
```

pip

```
pip config list
```

git

```
git config --global --list | grep proxy
```

---

## License

[MIT](LICENSE)
