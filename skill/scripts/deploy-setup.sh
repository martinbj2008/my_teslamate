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
    
    ssh -o StrictHostKeyChecking=no "$USER@$SERVER_IP" << 'EOF'
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
    
    # 创建目录（使用普通权限，因为是在用户主目录下）
    ssh "$USER@$SERVER_IP" "mkdir -p $REMOTE_DIR && mkdir -p $REMOTE_DIR/import"
    
    # 传输docker-compose.yml文件
    scp docker-compose.yml "$USER@$SERVER_IP:$REMOTE_DIR/" || die "传输docker-compose.yml失败"
    
    # 传输安装脚本到远程服务器
    scp install-teslamate.sh "$USER@$SERVER_IP:$REMOTE_DIR/" || die "传输安装脚本失败"
    
    # 在远程服务器上执行安装脚本
    ssh "$USER@$SERVER_IP" << EOF
        set -e
        cd $REMOTE_DIR
        chmod +x install-teslamate.sh
        ./install-teslamate.sh --install-docker
EOF
    
    if [ $? -eq 0 ]; then
        ok "TeslaMate部署成功"
    else
        die "TeslaMate部署失败"
    fi
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
