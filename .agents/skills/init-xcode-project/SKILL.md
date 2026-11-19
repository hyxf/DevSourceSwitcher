---
name: init-xcode-project
description: 用户要求生成或初始化本仓库 Xcode 项目、检查生成依赖，或安装 xcodegen 时，使用仓库脚本完成对应流程。
---

# 初始化 DevSourceSwitcher

以仓库脚本作为初始化流程的唯一执行入口，并从仓库根目录调用：

- 用户要求初始化项目时，运行 `scripts/init-xcode-project.sh`。
- 用户只要求检查环境时，运行 `scripts/init-xcode-project.sh --check --json`。
- 用户要求安装缺少的生成工具时，运行 `scripts/init-xcode-project.sh --install`。
- 需要机器可读结果时，添加 `--json`。

不要安装 Homebrew 或其他工具。`--install` 仅可调用本机已有的 Homebrew 安装 `xcodegen`。清楚报告脚本结果和可执行的错误提示；只有脚本成功退出后，才能说明初始化完成。
