# my_teslamate

个人 TeslaMate 一键部署工具集。

包含两部分：

| 目录 | 用途 |
|---|---|
| [`deploy/`](./deploy) | 4 个 shell 脚本 + compose 文件，把 TeslaMate 装到本地 Docker 或远程 Ubuntu/Debian 主机 |
| [`skill/`](./skill) | WorkBuddy skill，让普通用户用一句「帮我装个 teslamate」就能走完部署 |
| [`teslamate-deploy.zip`](./teslamate-deploy.zip) | 上面 `skill/` 打包好的 zip，给 WorkBuddy「从 zip 安装 skill」用 |

---

## 🚀 三种用法

### ① 直接跑脚本（CLI 玩家）

```bash
cd deploy
chmod +x deploy-setup.sh install-teslamate.sh
./deploy-setup.sh                  # 本机安装
./deploy-setup.sh <remote-ip>      # 远程主机安装（默认 ubuntu@22）
```

### ② WorkBuddy skill（小白玩家，推荐）

把这个 repo clone 到本地，然后让 WorkBuddy 把 `skill/` 装上：

```
workbuddy 安装 skill，路径 /Users/<you>/my_teslamate/skill
```

或者直接用 `teslamate-deploy.zip`：

```
workbuddy 从 zip 安装 skill，文件 teslamate-deploy.zip
```

装完后在任何 workspace 直接说：

> 「帮我装个 teslamate」
> 「在 1.2.3.4 上部署 teslamate」
> 「deploy teslamate to my ubuntu server」

WorkBuddy 会自动跑 5 步流程：参数确认 → pre-flight 检查 → 调 deploy-setup.sh → 健康检查 → 生成使用文档。

### ③ 把 zip 发给别人

`teslamate-deploy.zip` 可以直接发同事 / 传群文件 / 上 GitHub release。对方装上 WorkBuddy 之后：

1. 打开 WorkBuddy → 设置 → Skill
2. 「从本地 zip 安装」→ 选这个 zip
3. 装完说「装 teslamate」就行

---

## 📋 skill 触发词

WorkBuddy 看到下面这些说法都会自动接活：

- 中文：`装 teslamate` / `部署 teslamate` / `在云上跑个 teslamate` / `特斯拉数据记录安装`
- English：`install teslamate` / `deploy teslamate` / `set up teslamate on my server`

---

## 📦 文件清单

```
my_teslamate/
├── README.md                       (本文件)
├── .gitignore                      (排除 .env / logs / IDE 文件)
├── deploy/                         (核心安装脚本)
│   ├── README.md
│   ├── deploy-setup.sh             (主入口: 无参=本地, 1参=远程)
│   ├── install-teslamate.sh        (在已装 Docker 的目标上装 TeslaMate)
│   └── docker-compose.yml
├── skill/                          (WorkBuddy skill 源码)
│   ├── SKILL.md                    (主入口)
│   ├── references/
│   │   └── troubleshooting.md      (8 类故障排查)
│   └── scripts/                    (= deploy/ 的副本, 方便 skill 单独分发)
└── teslamate-deploy.zip            (skill 的打包版本, 14KB)
```

---

## 🔒 关于这个 repo

- **公开 Public**：任何人都能 clone / fork
- **已脱敏**：原 deploy 脚本示例中的服务器 IP（`43.136.44.121`）已替换为 RFC 5737 文档保留地址 `192.0.2.1`
- **默认凭据**：脚本里的弱默认（`TM_DB_PASS=teslamate123` 等）是 TeslaMate 官方文档里的占位值，不是真凭据，部署完**第一件事**就是改密

---

## 📜 License

MIT（沿用 TeslaMate 官方 docker-compose 模板的许可证惯例）
