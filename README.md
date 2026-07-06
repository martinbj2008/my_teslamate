# teslamate-deploy

> WorkBuddy skill that deploys [TeslaMate](https://github.com/teslamate/teslamate) (Tesla vehicle data logger + Grafana dashboards) to a local machine or a remote Linux server, end-to-end.

[🇨🇳 中文说明](#中文说明) · [🇬🇧 English](#english)

---

<a name="english"></a>

## 🇬🇧 English

A WorkBuddy skill — once installed, just say one of these in any WorkBuddy chat and it takes over:

- *"Install TeslaMate"*
- *"Deploy teslamate to 1.2.3.4"*
- *"Set up a Tesla data logger"*
- *"装个 teslamate"* / *"部署 teslamate"* / *"在云上跑个 teslamate"*

The skill runs a 5-step workflow: **target confirm → pre-flight checks → run deploy → health check → generate usage doc**.

### What you need

- A Linux host (Ubuntu 22.04 / 24.04, x86_64 or aarch64) that you can SSH to as `ubuntu` (sudo NOPASSWD, key-based auth)
- WorkBuddy installed on your local Mac/Linux

### Install the skill

**Option A — one-liner from the zip (easiest):**

```bash
mkdir -p ~/.workbuddy/skills && \
  curl -L -o /tmp/td.zip https://github.com/martinbj2008/my_teslamate/releases/latest/download/teslamate-deploy.zip && \
  unzip -q -o /tmp/td.zip -d ~/.workbuddy/skills/ && \
  rm /tmp/td.zip
```

**Option B — clone and copy:**

```bash
git clone https://github.com/martinbj2008/my_teslamate.git /tmp/my_teslamate && \
  cp -R /tmp/my_teslamate ~/.workbuddy/skills/teslamate-deploy
```

Then restart WorkBuddy.

### Use it

> *"Deploy TeslaMate to my server at 192.0.2.1"*

WorkBuddy will:
1. Ask you to confirm the target IP / SSH user
2. Run pre-flight checks (OS version, sudo, ports 3000/4000/1883 free)
3. Install Docker + pull 4 images + start the stack (~1.5 min)
4. Verify TeslaMate `:4000`, Grafana `:3000`, Mosquitto `:1883`
5. Generate a usage doc with your public URLs, Tesla-account setup steps, and ops commands

### Repo layout

```
.
├── SKILL.md                          ← WorkBuddy skill entry point
├── scripts/
│   ├── deploy-setup.sh               ← entry: no arg = local, 1 IP arg = remote
│   ├── install-teslamate.sh          ← local install (pulls images, starts stack)
│   ├── docker-compose.yml            ← 4 services: teslamate, postgres, grafana, mosquitto
│   └── README.md                     ← plain-Shell usage (no WorkBuddy needed)
├── references/
│   └── troubleshooting.md            ← 8 categories of common failures + fixes
├── .github/
│   └── workflows/release.yml         ← auto-build zip + create release on tag push
├── teslamate-deploy.zip              ← packaged skill for one-liner install
├── README.md                         ← this file
├── LICENSE                           ← MIT
└── .gitignore
```

### Security

- **No real IPs or credentials in this repo.** Any example IPs use RFC 5737 reserved range (`192.0.2.1`).
- The bundled `docker-compose.yml` uses TeslaMate's published default credentials (`admin/admin`, `teslamate/teslamate123`) — **change them immediately** after first login. The skill's Step 5 doc walks you through this.

### Compatibility

| Target | Status |
|---|---|
| Ubuntu 22.04 / 24.04 (x86_64) | ✅ Tested |
| Ubuntu 22.04 (aarch64 / ARM) | ✅ Tested |
| Debian 12 (x86_64) | 🟡 Should work (uses `apt-get`) — not yet tested |
| macOS / Windows | ❌ Out of scope — use the local install path on a Linux host |

### Releasing a new version

The release is fully automated via GitHub Actions — no manual upload. The workflow
in `.github/workflows/release.yml` watches for tag pushes matching `v*`, builds
the zip with the correct `teslamate-deploy/` top-level directory wrapper, and
attaches it to a fresh GitHub release.

```bash
# 1. Commit your changes
git add -A
git commit -m "..."

# 2. Push to main
git push origin main

# 3. Tag and push — workflow does the rest
git tag -a v1.0.1 -m "..."
git push origin v1.0.1

# 4. Watch the build
open https://github.com/martinbj2008/my_teslamate/actions

# 5. Release + zip ready at
#    https://github.com/martinbj2008/my_teslamate/releases/latest
```

### License

MIT — see [LICENSE](./LICENSE).

---

<a name="中文说明"></a>

## 🇨🇳 中文说明

WorkBuddy skill。装上之后在任何 WorkBuddy 对话里说一句就能自动开干：

- *"装个 teslamate"*
- *"把 teslamate 部署到 1.2.3.4"*
- *"在云上跑个 teslamate"*
- *"install TeslaMate"*

完整流程 5 步：**目标确认 → 预检 → 跑部署 → 健康检查 → 生成使用文档**。

### 前置条件

- 一台 Linux 主机（Ubuntu 22.04 / 24.04，x86_64 或 aarch64）
- 你能用 `ubuntu` 用户 SSH 上去（key 鉴权，sudo NOPASSWD）
- 本地装了 WorkBuddy

### 安装 skill

**方式 A：一行命令（推荐）**

```bash
mkdir -p ~/.workbuddy/skills && \
  curl -L -o /tmp/td.zip https://github.com/martinbj2008/my_teslamate/releases/latest/download/teslamate-deploy.zip && \
  unzip -q -o /tmp/td.zip -d ~/.workbuddy/skills/ && \
  rm /tmp/td.zip
```

**方式 B：clone 仓库再复制**

```bash
git clone https://github.com/martinbj2008/my_teslamate.git /tmp/my_teslamate && \
  cp -R /tmp/my_teslamate ~/.workbuddy/skills/teslamate-deploy
```

装完重启 WorkBuddy。

### 使用

> *"把 TeslaMate 部署到 192.0.2.1"*

WorkBuddy 会自动：
1. 跟你确认目标 IP 和 SSH 用户
2. 跑预检（系统版本、sudo、端口 3000/4000/1883 是否空闲）
3. 装 Docker + 拉 4 个镜像 + 启动 stack（约 1.5 分钟）
4. 验证 TeslaMate `:4000`、Grafana `:3000`、Mosquitto `:1883`
5. 生成一份使用文档（含公网 URL、Tesla 账号绑定步骤、运维命令）

### 仓库结构

```
.
├── SKILL.md                          ← WorkBuddy skill 入口
├── scripts/
│   ├── deploy-setup.sh               ← 主入口：无参=本地，1 个 IP=远程
│   ├── install-teslamate.sh          ← 本机安装（拉镜像、起 stack）
│   ├── docker-compose.yml            ← 4 个服务：teslamate, postgres, grafana, mosquitto
│   └── README.md                     ← 纯 shell 用法（不依赖 WorkBuddy）
├── references/
│   └── troubleshooting.md            ← 8 类常见故障 + 修复
├── .github/
│   └── workflows/release.yml         ← push tag 后自动 build zip + 发 release
├── teslamate-deploy.zip              ← 打包好的 skill，给一行命令安装用
├── README.md                         ← 本文件
├── LICENSE                           ← MIT
└── .gitignore
```

### 安全

- **仓库里没有任何真实 IP 或凭据**。示例 IP 全部用 RFC 5737 保留地址 `192.0.2.1`。
- `docker-compose.yml` 里的默认密码（`admin/admin`、`teslamate/teslamate123`）来自 TeslaMate 官方文档 —— **首次登录后立刻改密**，使用文档第 7 节有步骤。

### 兼容性

| 目标 | 状态 |
|---|---|
| Ubuntu 22.04 / 24.04 (x86_64) | ✅ 已测试 |
| Ubuntu 22.04 (aarch64 / ARM) | ✅ 已测试 |
| Debian 12 (x86_64) | 🟡 应该能跑（用的是 `apt-get`），未实测 |
| macOS / Windows | ❌ 不支持 —— 请在 Linux 主机上装 |

### 发新版本

发布完全自动化 —— 不需要手动上传。`.github/workflows/release.yml` 监听
`v*` tag 的 push，自动 build zip（包好 `teslamate-deploy/` 顶层目录）并 attach 到 release。

```bash
# 1. 改完代码
git add -A
git commit -m "..."

# 2. push 到 main
git push origin main

# 3. 打 tag 并 push —— 剩下 workflow 干
git tag -a v1.0.1 -m "..."
git push origin v1.0.1

# 4. 看构建进度
open https://github.com/martinbj2008/my_teslamate/actions

# 5. 完成后 release + zip 在
#    https://github.com/martinbj2008/my_teslamate/releases/latest
```

### 许可证

MIT —— 见 [LICENSE](./LICENSE)。
