# Git 代理配置规范（文件编辑版）

## 1. 文档目的

用于通过本地代理访问远程 Git 仓库，适用于：

* GitHub
* GitLab（外网）
* 其他 HTTPS / SSH Git 服务

本文档仅使用**配置文件编辑方式**完成设置。

---

## 2. 适用范围

Git 仓库地址通常分为两类：

### HTTPS 仓库

```text
https://github.com/user/repo.git
```

使用：

```text
~/.gitconfig
```

进行配置。

---

### SSH 仓库

```text
git@github.com:user/repo.git
```

使用：

```text
~/.ssh/config
```

进行配置。

---

> **重要：HTTPS 代理配置不会作用于 SSH 仓库**

---

## 3. HTTPS 代理配置（推荐）

### 配置文件路径

```text
~/.gitconfig
```

若文件不存在，请手动创建。

---

### 推荐配置

```ini
[http]
    proxy = socks5h://127.0.0.1:7891

[https]
    proxy = socks5h://127.0.0.1:7891
```

---

### 配置说明

| 配置项         | 说明                        |
| ----------- | ------------------------- |
| `socks5h`   | 由代理服务器执行 DNS 解析，避免 DNS 污染 |
| `127.0.0.1` | 本地代理地址                    |
| `7891`      | 本地 SOCKS5 默认端口（如 Clash）   |

---

### 推荐场景

适用于：

* GitHub 日常开发
* 最低维护成本
* 稳定性优先

---

## 4. 定向代理（推荐）

仅 GitHub 使用代理：

```ini
[http "https://github.com"]
    proxy = socks5h://127.0.0.1:7891
```

---

### 推荐场景

适用于：

* 公司内网 GitLab 不走代理
* GitHub 外网访问走代理
* 多环境共存

---

## 5. SSH 代理配置

---

### 配置文件路径

```text
~/.ssh/config
```

若文件不存在，请手动创建。

---

### 推荐配置

```ssh
Host github.com
  HostName ssh.github.com
  Port 443
  User git
  IdentityFile ~/.ssh/id_rsa
  ProxyCommand nc -x 127.0.0.1:7891 -X 5 %h %p
```

---

## 6. SSH 配置说明

| 配置项                       | 说明                   |
| ------------------------- | -------------------- |
| `HostName ssh.github.com` | GitHub 官方 SSH 443 入口 |
| `Port 443`                | 避免 22 端口被限制          |
| `IdentityFile`            | SSH 私钥路径             |
| `ProxyCommand`            | 通过本地 SOCKS5 转发       |

---

## 7. 依赖说明

SSH 代理配置依赖：

```text
nc (netcat)
```

不同系统版本参数可能存在差异。

---

## 8. 配置优先级

Git 配置优先级如下：

```text
仓库级：.git/config      （最高）
用户级：~/.gitconfig
系统级：/etc/gitconfig
```

---

> 仓库级配置会覆盖全局配置

---

## 9. 推荐方案

### 优先推荐 HTTPS

优先使用：

```text
https://github.com/user/repo.git
```

原因：

* 配置简单
* 稳定性高
* 维护成本低

---

### SSH 适用场景

仅在以下场景使用：

* 必须使用 SSH Key
* 企业安全规范要求
* 需要免密码认证

---

## 10. 常见端口规范

| 类型             | 默认端口 |
| -------------- | ---: |
| HTTP Proxy     | 7890 |
| SOCKS5 Proxy   | 7891 |
| SSH over HTTPS |  443 |

---

## 11. 最佳实践建议

推荐统一使用：

```text
SOCKS5 + 7891 + HTTPS
```
