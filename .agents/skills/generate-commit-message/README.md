# 从命令行填入 VS Code 提交消息

## 方案

通过 VS Code 官方支持的 `vscode://` URI handler，把命令行中的完整提交消息传给扩展。扩展收到 URI 后，调用已有的 `project-atlas.setGitCommitMessage` 命令填入 Source Control 输入框。

仅注册 `project-atlas.setGitCommitMessage` 命令还不够：VS Code 的 `code` CLI 没有直接执行任意扩展命令并传递参数的通用接口。扩展需要额外注册 URI handler。

## 扩展侧

在扩展激活时注册 URI handler。以下示例约定 URI 路径为 `/set-commit-message`，消息通过 `message` 查询参数传递：

```ts
vscode.window.registerUriHandler({
    async handleUri(uri: vscode.Uri) {
        if (uri.path !== '/set-commit-message') {
            return;
        }

        const message = new URLSearchParams(uri.query).get('message');
        if (message === null || message.length === 0) {
            vscode.window.showErrorMessage('提交消息不能为空');
            return;
        }

        await vscode.commands.executeCommand(
            'project-atlas.setGitCommitMessage',
            message,
        );
    },
});
```

把 `publisher.extensionName` 替换为扩展 `package.json` 中的发布者和扩展名称。URI 格式为：

```text
vscode://publisher.extensionName/set-commit-message?message=<URL编码后的完整消息>
```

## 命令行

下面的 Bash 示例通过 Python 标准库编码参数，支持空格和多行消息：

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage: %s MESSAGE\n' "$0" >&2
    exit 2
fi

message="$1"
encoded_message="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$message")"
code --open-url "vscode://publisher.extensionName/set-commit-message?message=${encoded_message}"
```

调用示例：

```bash
./scripts/set-vscode-commit-message.sh $'feat(ui): 调整菜单布局\n\n补充提交说明'
```

`code --open-url` 会把 URI 交给 VS Code；扩展 handler 再调用已有命令填入提交框。整个流程不会执行 Git commit。使用前需要安装并激活该扩展，并在终端中安装 VS Code 的 `code` 命令。

## 参考

- [VS Code 命令行：打开项目和 URL](https://code.visualstudio.com/docs/configure/command-line#_opening-projects-from-the-command-line)
- [VS Code 扩展 URI handler](https://code.visualstudio.com/api/references/vscode-api#UriHandler)
- [VS Code 扩展命令](https://code.visualstudio.com/api/extension-guides/command)
