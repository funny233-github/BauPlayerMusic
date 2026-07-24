# Docker 部署指南（供 AI Agent 执行）

本文件指导 AI Agent 帮助用户在 Linux 服务器上通过 Docker 部署 BauPlayerMusic 听歌服。

---

## 部署流程

Agent 必须**严格按顺序**执行以下步骤，每步完成后再进行下一步。

### 第 1 步：询问镜像源（构建加速）

国内直连 Docker Hub、Ubuntu 官方源、Rust 官方源速度极慢。向用户确认是否需要镜像加速：

1. **apt 镜像源** — 是否使用阿里云镜像加速？国内建议 `http://mirrors.aliyun.com`。
2. **Rust 镜像源** — 是否使用中科大镜像加速？国内建议 `https://mirrors.ustc.edu.cn/rust-static`。

在 `.env` 中添加（留空则走官方源）：
```dotenv
APT_MIRROR=http://mirrors.aliyun.com
RUSTUP_MIRROR=https://mirrors.ustc.edu.cn/rust-static
```

---

### 第 2 步：询问可选功能

向用户确认：

1. **对象存储** — 是否要开启？外网玩家通过 HTTPS 下载地图需要。需要用户提供 S3/OSS 的端点、AK、SK、桶名、公网域名。
2. **QQ 机器人** — **当前不支持 Docker 部署**。NapCat 需要 NTQQ 桌面环境，无法容器化。告知用户此功能暂不可用。

记录用户的选择，后续配置时使用。

---

### 第 3 步：安装 Python 环境

在宿主机上安装 Python 3.12+ 和依赖（用于首次获取网易云 Cookie）：

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y python3 python3-pip python3-venv ffmpeg

# 创建虚拟环境
python3 -m venv /tmp/bpmusic-venv
source /tmp/bpmusic-venv/bin/activate
pip install -r requirements-aliyun.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

---

### 第 4 步：获取网易云 Cookie

引导用户运行 mds.py 扫码登录：

```bash
cd <项目目录>
source /tmp/bpmusic-venv/bin/activate
python mds.py
```

Agent 应告知用户：
- 会自动打开浏览器窗口，请在网页上扫码登录网易云音乐
- 登录成功后切换到终端，按 `Enter` 键
- 看到 `[登录] Cookies 已成功保存！` 后按 `Ctrl+C` 退出
- 这会生成 `netease_cookies.json`，Docker 容器会挂载使用

---

### 第 5 步：配置 .env

根据前几步的选择，与用户一起填写 `.env` 文件。

**最小配置**（仅本地播放）：

```dotenv
BPMUSIC_HOST=127.0.0.1
BPMUSIC_PORT=5000
BPMUSIC_NETEASE_BASE_URL=http://music.163.com
BPMUSIC_DOWNLOAD_DIR=data/musicso
BPMUSIC_COVER_DIR=data/musicso/covers
BPMUSIC_COOKIE_FILE=netease_cookies.json
BPMUSIC_ORIGIN_MAPS_DIR=data/originmaps
BPMUSIC_PREPARED_MAPS_DIR=data/musico/prepared_maps
BPMUSIC_WEBMAPS_BASE_PATH=data/webmaps
BPMUSIC_MAP_PATCHER=
BPMUSIC_MAP_PATCHER_TIMEOUT=90
BPMUSIC_UPLOAD_WORKERS=2
BPMUSIC_PLAYLIST_FILE=
BPMUSIC_STATS_DB=data/musico/music_history.sqlite3
BPMUSIC_UNDERCOVER_DB=data/musico/undercover.sqlite3
BPMUSIC_UNDERCOVER_WORDS=data/musico/undercover_words.txt
BPMUSIC_TURTLE_SOUP_DB=data/musico/turtle_soup.sqlite3
BPMUSIC_TURTLE_SOUP_CASES=data/musico/turtle_soup_cases.json
DEEPSEEK_API_KEY=
DEEPSEEK_API_BASE=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-v4-pro
TURTLE_SOUP_PLAYER_COOLDOWN=4
TURTLE_SOUP_GLOBAL_COOLDOWN=0.8
BPMUSIC_QQBOT_ENABLED=0
BPMUSIC_QQBOT_WS_URL=ws://127.0.0.1:3001
BPMUSIC_QQBOT_ACCESS_TOKEN=
BPMUSIC_QQBOT_GROUP_IDS=
BPMUSIC_QQBOT_MAX_SONGS=10
BPMUSIC_QQBOT_RECONNECT_SECONDS=5
BPMUSIC_QQBOT_SERVER_TOKEN=
BPMUSIC_QQBOT_RELAY_GLOBAL_COOLDOWN=5
BPMUSIC_QQBOT_RELAY_USER_COOLDOWN=30
BPMUSIC_QQBOT_RELAY_MAX_LENGTH=160
BPMUSIC_S3_ENDPOINT_URL=
BPMUSIC_S3_ACCESS_KEY=
BPMUSIC_S3_SECRET_KEY=
BPMUSIC_S3_BUCKET_NAME=
BPMUSIC_S3_PUBLIC_DOMAIN=
BPMUSIC_S3_OBJECT_ACL=
BPMUSIC_ALIYUN_OSS_ENDPOINT=
BPMUSIC_PANEL_HOST=127.0.0.1
BPMUSIC_PANEL_PORT=8787
BPMUSIC_PANEL_TOKEN=
```

**如果要开对象存储**，让用户填入这 6 个字段：

```dotenv
BPMUSIC_S3_ENDPOINT_URL=   # S3 API 端点，如 https://cn-nb1.internal.rains3.com
BPMUSIC_S3_ACCESS_KEY=     # Access Key
BPMUSIC_S3_SECRET_KEY=     # Secret Key
BPMUSIC_S3_BUCKET_NAME=    # 桶名
BPMUSIC_S3_PUBLIC_DOMAIN=  # 公网访问域名，如 https://maps.example.com
BPMUSIC_S3_OBJECT_ACL=     # 通常留空，需要时填 public-read
```

Agent 注意：
- `.env` 中的注释行（`#` 开头）可以保留
- 空值字段保留为空即可
- `BPMUSIC_QQBOT_ENABLED` 必须为 `0`
- `BPMUSIC_PANEL_HOST` 保持 `127.0.0.1`

---

### 第 6 步：配置 myServerconfig.cfg

与用户一起填写 `myServerconfig.cfg`：

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

---

### 第 7 步：构建并启动

**构建必须分两步**，因为 Docker Compose 不支持构建时依赖排序——`build-env`（编译环境）必须先完成，`backend` 和 `server` 才能引用它：

```bash
# 1. 先构建编译环境（首次或改依赖时，之后可跳过）
docker compose build build-env

# 2. 构建后端和服务端
docker compose build --no-cache backend server

# 3. 启动
docker compose up -d
```

**为什么分两步？** Compose 的 `depends_on` 只控制运行时启动顺序，不控制构建顺序。BuildKit 会并行构建所有服务，`backend`/`server` 的 `FROM bpmusic-build` 在编译环境没造好之前会尝试从 Docker Hub 拉取，必然失败。分两次 build 用 `&&` 是 Docker Compose 社区公认的标准做法（参见 GitHub issues #6093、#13073）。

构建耗时约 10-20 分钟（含编译 DDNet 服务端）。

---

### 第 8 步：验证

```bash
# 检查容器状态
docker compose ps

# 查看日志
docker compose logs -f

# 确认管理面板
curl http://127.0.0.1:8787
```

确认日志中出现：
- backend: `监听地址: http://0.0.0.0:5000`
- server: `server name is '...'` 且 `http://127.0.0.1:5000/server/state` 正常

---

### 第 9 步：告知用户

- 游戏客户端连接 `服务器IP:8303`
- 管理面板 `http://服务器IP:8787`
- 如需公网，放行 UDP 8303 和 TCP 8787
- 不要暴露 5000 端口到公网
