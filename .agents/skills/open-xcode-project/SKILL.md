---
name: open-xcode-project
description: Open a generated .xcodeproj from an XcodeGen project in the locally selected Xcode app when asked to open or launch it.
---

# 在本地 Xcode 中打开项目

使用 `python3` 运行本 skill 的 `scripts/open-xcode-project.py` 打开 Xcode 项目。默认将当前目录视为项目根目录；从其他目录调用时，添加 `--project-root /项目/目录`。根目录中有多个 `.xcodeproj` 时，添加 `--project 路径` 指定目标。

1. 运行该脚本并添加 `--check --json`，确认项目根目录下有目标 `.xcodeproj/project.pbxproj`，且本机选定的是完整的 Xcode.app。
2. 如果项目文件缺失，先运行 `init-xcode-project` skill 的生成脚本。
3. 运行该脚本并添加 `--json`，由 macOS 使用 `xcode-select` 选定的 Xcode.app 打开项目。

脚本成功表示 macOS 已接受打开请求，不代表 Xcode 已完成启动。若检查或打开失败，报告脚本提供的错误并说明需要修复的本机 Xcode 配置。
