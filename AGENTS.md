# 仓库指南

## 项目结构

这是一个使用 Swift 编写、通过 XcodeGen 配置的原生 macOS 菜单栏应用。应用代码位于 `DevSourceSwitcher/`，按职责分组：`App/` 存放应用入口；`Models/`、`ViewModels/`、`Views/`、`Services/` 和 `Utils/` 分别存放对应层的代码。`Assets.xcassets/` 存放图标和颜色资源。`project.yml` 定义 Xcode target，`.github/workflows/release-mac.yml` 用于构建通用版发布 DMG。`Docs/` 存放辅助文档。目前尚未配置测试 target 或测试目录。

## 初始化项目

- 如尚未安装项目生成工具，可运行 `brew install xcodegen`。
- `xcodegen generate` 根据 `project.yml` 生成被 Git 忽略的 `DevSourceSwitcher.xcodeproj`。

修改 `project.yml` 后，重新运行 `xcodegen generate`，再使用 Xcode 打开项目。

## 构建与开发

- `open DevSourceSwitcher.xcodeproj` 在 Xcode 中打开项目；选择 **My Mac**，然后按 `⌘R` 运行。
- `xcodebuild -scheme DevSourceSwitcher -configuration Debug build` 在命令行构建项目。
- `swiftformat DevSourceSwitcher` 根据 `.swiftformat` 格式化 Swift 文件；安装相应工具后，可运行 `swiftlint lint` 检查已配置的 lint 规则。

`project.yml` 中应用的最低系统版本为 macOS 14.0。调整部署要求时，请同步更新文档中声明的支持范围。

## 代码风格

使用 4 个空格缩进，并尽量将行宽控制在配置的 100 个字符以内。遵循 Swift 命名惯例：类型使用 `UpperCamelCase`，属性和函数使用 `lowerCamelCase`。界面代码放在 `Views/`，状态与展示逻辑放在 `ViewModels/`，文件系统和配置相关操作放在 `Services/`。尽量在现有功能分层内进行小范围修改，并遵循 SwiftFormat/SwiftLint 配置，避免引入局部风格例外。

## 测试

本仓库尚未配置自动化测试。修改后请构建应用，并手动检查受影响的菜单或设置流程。涉及源配置或备份的修改，请检查生成的配置与备份文件；涉及界面的修改，请在 macOS 应用中检查对应视图。如需加入自动化覆盖，请同时新增测试 target。

## 提交与拉取请求

现有提交历史使用简短、非正式的主题，例如 `fix`、`modify readme` 和 `release v1.0.9`。提交说明建议使用简洁的祈使表达；发布提交应包含版本号。拉取请求应描述用户可见的变化、列出已完成的验证、酌情关联相关 issue，并为界面变更附上截图。涉及 `project.yml`、支持的 macOS 版本或配置文件行为时，请在说明中明确指出。

## 配置与数据安全

此应用会修改用户级别的包管理器、Git 和 SSH 配置文件。更新配置时应保留原有内容，并维持现有备份行为。不要提交生成的 Xcode 项目、构建产物、本地用户数据或机密信息。
