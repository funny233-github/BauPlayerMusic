# Docker 部署指南（供 AI Agent 执行）

本文件指导 AI Agent 帮助用户在 Linux 服务器上通过 Docker 部署 BauPlayerMusic 听歌服。

---

## 架构

```
┌─────────────────────────────────────────────────────┐
│                       宿主机                         │
│                                                      │
│  ┌──────────────┐         ┌──────────────────────┐  │
│  │   backend     │ HTTP    │      server          │  │
│  │  (Flask API)  │◄────────│  (DDNet-Server)      │  │
│  │  :5000        │  8283   │  :8303/udp           │  │
│  │  :8787 (面板)  │   ───►  │  8081/8082           │  │
│  │  python:3.13  │  state  │  ubuntu:latest        │  │
│  │  + ffmpeg     │  push   │  Release+ASAN -O2    │  │
│  └──────┬───────┘         └──────────┬───────────┘  │
│         │                            │              │
│         └─────────── 数据卷 ──────────┘              │
│         data/musicso/ (歌曲+歌词)                    │
│         data/musico/  (队列+数据库)                   │
└─────────────────────────────────────────────────────┘
```

- **backend**: 音乐 API + 管理面板（Python Flask）
- **server**: DDNet 服务端（Release + ASAN 编译，防止堆内存越界崩溃）
- **数据卷**: `data/` 目录挂载到两个容器，实现歌曲/歌词/队列共享
- **网络**: `network_mode: host`，避免 Docker UDP NAT 导致的注册问题

---

## 部署流程

Agent 必须**严格按顺序**执行以下步骤，每步完成后再进行下一步。

### 第 1 步：询问镜像源（构建加速）

国内直连 Docker Hub、Ubuntu 官方源、pip 官方源速度极慢。向用户确认是否需要镜像加速：

1. **apt 镜像源** — 是否使用阿里云镜像？国内建议 `http://mirrors.aliyun.com`。
2. **pip 镜像源** — 是否使用阿里云镜像？国内建议 `http://mirrors.aliyun.com/pypi/simple/`。

在 `.env` 中添加（留空则走官方源）：
```dotenv
APT_MIRROR=http://mirrors.aliyun.com
PIP_MIRROR=http://mirrors.aliyun.com/pypi/simple/
```

---

### 第 2 步：询问可选功能

向用户确认：

1. **对象存储** — 是否要开启？外网玩家通过 HTTPS 下载地图需要。需要用户提供 S3/OSS 的端点、AK、SK、桶名、公网域名。
2. **QQ 机器人** — **当前不支持 Docker 部署**。NapCat 需要 NTQQ 桌面环境，无法容器化。告知用户此功能暂不可用。

记录用户的选择，后续配置时使用。

---

### 第 3 步：获取网易云 Cookie（可选）

> **注意**：网易云 Cookie 不强制。不配置则无法下载音乐（需要用户手动上传 `.opus` 和 `.lrc` 到 `data/musicso/`）。

有两种方式获取 Cookie：

**方式 A：在现有 Docker 容器内交互登录（推荐）**

```bash
# 先正常启动后端
docker compose up -d backend

# 进入容器交互执行 mds.py 扫码
docker compose exec -it backend bash
# 容器内执行：
BPMUSIC_COOKIE_FILE=/app/netease_cookies.json python3 -c "
import mds
mds.NeteaseCookies()
"
```

扫码登录后按提示操作，Cookie 会自动保存到 `data/netease_cookies.json`。

**方式 B：在宿主机扫码登录（需要宿主机有 Python 环境）**

```bash
sudo apt install python3 python3-pip python3-venv ffmpeg
cd <项目目录>
python3 -m venv /tmp/bpmusic-venv
source /tmp/bpmusic-venv/bin/activate
pip install -r requirements.txt
BPMUSIC_COOKIE_FILE=netease_cookies.json python3 -c "
import mds
mds.NeteaseCookies()
"
```

扫码登录后，`netease_cookies.json` 会在项目根目录生成，Docker 会自动挂载到容器内。

---

### 第 4 步：配置 myServerconfig.cfg

与用户一起填写 `myServerconfig.cfg`。只需要关注服务端本身的配置——**音乐后端地址固定为 `http://127.0.0.1:5000`**：

```cfg
sv_name "你的服务器名"
sv_map "a"
sv_port 8303
sv_max_clients 64

sv_rcon_password "修改为高强度密码"
sv_rcon_max_tries 5
sv_rcon_bantime 60

sv_music_backend_url "http://127.0.0.1:5000"
sv_music_global_cooldown 10
sv_music_player_cooldown 100
sv_music_search_results 10
sv_music_vote_search_results 20
sv_music_playlist_visible 10
sv_music_vote_progress_refresh 1
sv_music_max_song_duration 3600

sv_music_qq_relay 0
sv_music_qq_token ""

sv_maps_base_url ""
sv_register 0

# 新玩家进服后立即可以投票点歌
sv_join_vote_delay 0
```

Agent 注意：
- `sv_rcon_password` 必须让用户改成高强度密码
- `sv_join_vote_delay 0` 必须设置，否则新玩家要等 300 秒
- `sv_register` 先保持 0，测试没问题再改 1
- 音乐后端地址无需修改，`network_mode: host` 让容器间通过 `127.0.0.1:5000` 通信

---

### 第 5 步：配置 .env（精简版）

当前 Docker 部署**不需要**在 `.env` 中配置 `BPMUSIC_*` 环境变量——它们已直接在 `docker-compose.yml` 的 `environment` 和 `docker-entrypoint-backend.sh` 中写好。

`.env` 只用于构建加速：

```dotenv
# 镜像源（请与用户确认后再填）
APT_MIRROR=http://mirrors.aliyun.com
PIP_MIRROR=http://mirrors.aliyun.com/pypi/simple/
```

如果用户要开启对象存储，才需要在 `docker-compose.yml` 的 backend 服务的 `environment` 中添加：
```yaml
BPMUSIC_S3_ENDPOINT_URL=https://cn-nb1.internal.rains3.com
BPMUSIC_S3_ACCESS_KEY=xxxx
BPMUSIC_S3_SECRET_KEY=xxxx
BPMUSIC_S3_BUCKET_NAME=music-maps
BPMUSIC_S3_PUBLIC_DOMAIN=https://maps.example.com
BPMUSIC_S3_OBJECT_ACL=public-read
```

---

### 第 6 步：构建 Docker 镜像

**构建必须分两步执行**——`build-env`（2.2GB 编译环境）必须先构建，`backend` 和 `server` 才能引用它。

```bash
# 第 1 步：构建编译环境（仅首次或改依赖时需要，之后可跳过）
docker build -t bpmusic-build -f Dockerfile.build .

# 第 2 步：构建后端和服务端
docker compose build --no-cache

# 第 3 步：启动
docker compose up -d
```

> **为什么分两步？** Compose 不支持构建时依赖排序（参见 GitHub issues #6093、#13073）。
> BuildKit 会并行构建所有服务，`backend`/`server` 的 `FROM bpmusic-build` 在编译环境没造好之前会从 Docker Hub 拉取，必然失败。
> 两次 build 逐步执行是 Docker Compose 社区公认的做法。

构建耗时约 10-20 分钟（含编译 DDNet 服务端）。

---

### 第 7 步：验证

```bash
# 检查容器状态
docker compose ps

# 查看日志
docker compose logs -f

# 确认管理面板
curl http://127.0.0.1:8787
```

确认日志中出现：
- backend: `监听地址: http://0.0.0.0:5000` 且 `管理面板：http://127.0.0.1:8787/`
- server: `server name is '...'` 且 `http://127.0.0.1:5000/server/state` 正常轮询

---

### 第 8 步：清理（可选）

```bash
# 删除 build-env 镜像（节省 2.2GB 磁盘空间）
docker rmi bpmusic-build

# 之后需要重新构建时，重新执行 docker build -t bpmusic-build -f Dockerfile.build .
```

---

### 第 9 步：告知用户

- 游戏客户端连接 `服务器IP:8303`
- 管理面板 `http://服务器IP:8787`
- 如需公网，放行 UDP 8303 和 TCP 8787
- **不要**暴露 5000 端口到公网（后端 API，无鉴权）
- 如需对象存储 + 外网地图下载，告知用户需配置 S3

---

## 故障排查

### 服务器反复崩溃（free(): double free）

```
free(): double free detected in tcache 2
```

可能原因：内存越界导致堆元数据损坏。当前 server 使用 **Release + ASAN** 编译，ASAN 会在第一处越界时直接报错并打印堆栈——如果出现 ASAN 报错，把堆栈发给开发者。

如果出现纯 Release 的 `double free`，尝试清空 `data/musicso/` 和 `data/musico/` 中的数据重新测试：

```bash
sudo rm -rf data/musicso data/musico
mkdir data/musicso data/musico
docker compose restart server
```

### IPv6 搜索卡死

网易云 API 在某些网络环境下会因 IPv6 DNS 解析卡死。脚本已内置修复（在 `docker-entrypoint-backend.sh` 中注入 `HAS_IPV6 = False`），无需手动干预。

### 注册失败（master server）

```
ERROR: the master server reports that clients can not connect to this server.
ERROR: configure your firewall/nat to let through udp on port XXXXX.
```

- `sv_register 0`：局域网测试时忽略即可
- `sv_register 1`：确认服务器的 UDP 8303 端口已放行并正确 NAT

### QQ Bot 不支持

NapCat + NTQQ 需要完整的桌面环境（X11/Wayland + D-Bus），无法在 Docker 容器内运行。如需 QQ Bot 功能，请在宿主机上以 systemd 服务运行 NapCat，与本 Docker 服务并行。

---

## 镜像说明

| 镜像 | 基础 | 尺寸 | 说明 |
|------|------|------|------|
| `bpmusic-build` | ubuntu:latest | ~2.2 GB | 编译环境：g++、cmake、Rust、开发头文件。用完可删。 |
| `bpmusic-backend` | python:3.13-slim | ~647 MB | Python 后端 + ffmpeg + pydub。包含修改版 `audioop-lts`。 |
| `bpmusic-server` | ubuntu:latest | ~420 MB | DDNet 服务端（Release + ASAN 编译，带调试符号）。 |

