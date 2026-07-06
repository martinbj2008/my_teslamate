#!/bin/bash
# TeslaMate 远程部署脚本

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[deploy]${NC} $1"
}

ok() {
    echo -e "${GREEN}[deploy] ✓${NC} $1"
}

error() {
    echo -e "${RED}[deploy] ✗${NC} $1" >&2
}

die() {
    error "$1"
    exit 1
}

# ---- 单连接复用 (OpenSSH ControlMaster) ----
# 解决 "Connection closed by ... port 22" 错误：脚本原本会打开 6+ 个独立 SSH/scp
# 会话，命中服务端 MaxSessions=10 限制。ControlMaster 让所有 ssh/scp 调用复用
# 同一个 master socket，对服务端只算 1 个 session。
SSH_OPTS=(
    -o StrictHostKeyChecking=no
    -o ControlMaster=auto
    -o ControlPath="${TMPDIR:-/tmp}/teslamate-deploy-ssh-%r@%h:%p"
    -o ControlPersist=600
)
SSH_TARGET=""  # 由 _ssh_remote / _scp_local 设置
SSH_MASTER_PID=""

_ssh_remote() {
    # 第一次调用时建立 master（会占 1 个 session），之后所有调用复用它
    local target="$1"; shift
    SSH_TARGET="$target"
    # 确保 master 存在
    if ! ssh -O check "$target" 2>/dev/null; then
        # 用 -N -f 在后台建 master（不实际开 shell）
        ssh -fN "${SSH_OPTS[@]}" "$target" || die "无法建立到 $target 的 SSH 连接"
    fi
    # 执行实际命令（自动走 multiplex）
    ssh "${SSH_OPTS[@]}" "$target" "$@"
}

_scp_local() {
    # scp 也支持 ControlMaster（-o 透传）
    local src="$1" dst="$2"
    scp "${SSH_OPTS[@]}" "$src" "$dst"
}

_cleanup_ssh_master() {
    if [ -n "$SSH_TARGET" ]; then
        ssh -O exit "${SSH_OPTS[@]}" "$SSH_TARGET" 2>/dev/null || true
    fi
}
trap _cleanup_ssh_master EXIT

# 检查参数
if [ $# -eq 0 ]; then
    # 无参数，执行本地安装
    log "检测到无参数，执行本地安装..."
    
    # 检查本地安装脚本是否存在
    if [ ! -f "install-teslamate.sh" ]; then
        die "缺少本地安装脚本 install-teslamate.sh"
    fi
    
    # 执行本地安装脚本
    chmod +x install-teslamate.sh
    ./install-teslamate.sh
    exit $?
fi

if [ $# -ne 1 ]; then
    echo "用法: $0 [服务器IP]"
    echo ""
    echo "选项:"
    echo "  无参数      执行本地安装"
    echo "  <服务器IP>  执行远程部署"
    echo ""
    echo "示例:"
    echo "  $0                    # 本地安装"
    echo "  $0 192.0.2.1     # 远程部署"
    exit 1
fi

SERVER_IP="$1"
USER="ubuntu"
REMOTE_DIR="/home/$USER/teslamate"

log "开始 TeslaMate 远程部署到服务器: $SERVER_IP"

# 固定密码配置
TM_ENCRYPTION_KEY="default_encryption_key_123456789012"
TM_DB_PASS="teslamate123"

setup_server() {
    log "设置服务器环境..."

    # 用 ControlMaster 复用同一条连接，避免触发 MaxSessions
    _ssh_remote "$USER@$SERVER_IP" << 'EOF'
        set -e

        # 修复dpkg问题
        sudo dpkg --configure -a 2>/dev/null || true

        # 更新包列表
        sudo apt-get update -y

        echo "安装Docker环境..."

        # 直接安装Docker和Docker Compose
        sudo apt-get install -y docker.io docker-compose-v2

        echo "Docker环境安装完成"

        # 验证Docker Compose是否可用
        if ! docker compose version >/dev/null 2>&1; then
            echo "错误：Docker Compose安装失败，请检查系统环境"
            exit 1
        fi

        # 配置镜像加速器
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json > /dev/null << 'DOCKER_CONFIG'
{
  "registry-mirrors": ["https://mirror.ccs.tencentyun.com"]
}
DOCKER_CONFIG

        sudo systemctl daemon-reload
        sudo systemctl enable docker
        sudo systemctl restart docker

        echo "服务器环境设置完成"
EOF

    ok "服务器环境设置完成"
}

deploy_teslamate() {
    log "部署TeslaMate服务..."

    # 检查本地docker-compose.yml文件是否存在
    if [ ! -f "docker-compose.yml" ]; then
        die "缺少docker-compose.yml文件，请先创建固定配置文件"
    fi

    # 一次SSH连接里完成：建目录 + scp + chmod
    # 关键：把 docker-compose.yml 通过 base64 走 stdin 传过去，
    # 彻底避免多次 scp 打开新 SSH 会话。
    log "创建远程目录并传输文件（单连接）..."

    COMPOSE_B64="$(base64 < docker-compose.yml | tr -d '\n')"
    INSTALL_B64="$(base64 < install-teslamate.sh | tr -d '\n')"

    _ssh_remote "$USER@$SERVER_IP" <<EOF
        set -e
        mkdir -p $REMOTE_DIR $REMOTE_DIR/import
        # base64 解码写入
        echo '${COMPOSE_B64}' | base64 -d > $REMOTE_DIR/docker-compose.yml
        echo '${INSTALL_B64}'  | base64 -d > $REMOTE_DIR/install-teslamate.sh
        chmod +x $REMOTE_DIR/install-teslamate.sh
        # 校验文件存在且非空
        test -s $REMOTE_DIR/docker-compose.yml
        test -s $REMOTE_DIR/install-teslamate.sh
        echo "files staged: \$(wc -c < $REMOTE_DIR/docker-compose.yml) bytes compose, \$(wc -c < $REMOTE_DIR/install-teslamate.sh) bytes install"
EOF

    # 在远程服务器上执行安装脚本（复用同一条 ControlMaster 连接）
    log "远程执行安装脚本..."
    _ssh_remote "$USER@$SERVER_IP" << EOF
        set -e
        cd $REMOTE_DIR
        sudo ./install-teslamate.sh --install-docker
EOF

    ok "TeslaMate部署成功"
}

show_result() {
    echo ""
    echo "=========================================="
    echo "✅ TeslaMate 远程部署完成"
    echo "=========================================="
    echo "访问地址:"
    echo "  TeslaMate: http://$SERVER_IP:4000"
    echo "  Grafana:   http://$SERVER_IP:3000"
    echo ""
    echo "Grafana 默认账号: admin/admin"
    echo "首次访问可能需要 1-2 分钟数据库初始化"
    echo "=========================================="
}

main() {
    log "开始TeslaMate一键部署"
    
    setup_server
    deploy_teslamate
    show_result
    
    ok "部署流程全部完成"
}

main "$@"
