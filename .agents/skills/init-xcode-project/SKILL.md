---
name: init-xcode-project
description: 用户要求为含有 project.yml 的 XcodeGen 项目生成 Xcode 项目、检查依赖或安装 xcodegen 时，使用脚本完成对应流程。
---

# 初始化 XcodeGen 项目

使用 `python3` 运行本 skill 的 `scripts/init-xcode-project.py`。默认将当前目录视为项目根目录；从其他目录调用时，添加 `--project-root /项目/目录`。项目根目录须包含 `project.yml`。

- 用户要求初始化项目时，运行 `python3 <本 skill 路径>/scripts/init-xcode-project.py`。
- 用户只要求检查环境时，运行该脚本并添加 `--check --json`。
- 用户要求安装缺少的生成工具时，运行该脚本并添加 `--install`。
- 需要机器可读结果时，添加 `--json`。

不要安装 Homebrew 或其他工具。`--install` 仅可调用本机已有的 Homebrew 安装 `xcodegen`。清楚报告脚本结果和可执行的错误提示；只有脚本成功退出后，才能说明初始化完成。
