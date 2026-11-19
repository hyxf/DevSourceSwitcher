---
name: open-xcode-project
description: Open this repository's generated .xcodeproj in the local Xcode app when asked to open or launch the project in Xcode.
---

# 在本地 Xcode 中打开项目

使用仓库脚本打开 Xcode 项目，不要把仓库目录或单个源文件当作项目打开：

1. 运行 `.agents/skills/open-xcode-project/scripts/open-xcode-project.sh --check --json`，确认根目录下的 `DevSourceSwitcher.xcodeproj/project.pbxproj` 存在，且本机选定的是完整的 Xcode.app。
2. 如果项目文件缺失，先运行 `.agents/skills/init-xcode-project/scripts/init-xcode-project.sh` 生成它。
3. 运行 `.agents/skills/open-xcode-project/scripts/open-xcode-project.sh --json`，由 macOS 使用 `xcode-select` 选定的 Xcode.app 打开 `.xcodeproj`。

脚本成功表示 macOS 已接受打开请求，不代表 Xcode 已完成启动。若检查或打开失败，报告脚本提供的错误并说明需要修复的本机 Xcode 配置。
