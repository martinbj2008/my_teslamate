#!/bin/bash
# TeslaMate 本地安装脚本

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[install]${NC} $1"
}

ok() {
    echo -e "${GREEN}[install] ✓${NC} $1"
}

error() {
    echo -e "${RED}[install] ✗${NC} $1" >&2
}

die() {
    error "$1"
    exit 1
}

# 检查Docker环境
check_docker() {
    log "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        log "Docker未安装，开始自动安装..."
        install_docker
        return
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log "Docker Compose未安装，开始自动安装..."
        install_docker
        return
    fi
    
    # 检查Docker服务状态
    if ! sudo docker info &> /dev/null; then
        log "Docker服务未运行，尝试启动服务..."
        sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null
        
        # 再次检查
        if ! sudo docker info &> /dev/null; then
            die "Docker服务启动失败，请手动检查Docker服务状态"
        fi
    fi
    
    ok "Docker环境检查通过"
}

# 安装Docker环境（仅限Ubuntu/Debian）
install_docker() {
    log "安装Docker环境..."
    
    # 修复dpkg问题
    sudo dpkg --configure -a 2>/dev/null || true
    
    # 更新包列表
    sudo apt-get update -y
    
    # 安装Docker和Docker Compose
    sudo apt-get install -y docker.io docker-compose-v2
    
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
    
    ok "Docker环境安装完成"
}

# 安装TeslaMate服务
install_teslamate() {
    log "安装TeslaMate服务..."
    
    # 检查docker-compose.yml文件是否存在
    if [ ! -f "docker-compose.yml" ]; then
        die "缺少docker-compose.yml文件"
    fi
    
    # 固定密码配置
    TM_ENCRYPTION_KEY="default_encryption_key_123456789012"
    TM_DB_PASS="teslamate123"
    
    # 创建import目录
    mkdir -p import
    
    # 创建.env文件
    tee .env > /dev/null << ENV_CONFIG
TM_ENCRYPTION_KEY=${TM_ENCRYPTION_KEY}
TM_DB_PASS=${TM_DB_PASS}
ENV_CONFIG

    # 设置权限
    chmod 600 .env
    
    # 拉取镜像
    sudo docker compose pull
    
    # 启动服务
    sudo docker compose down 2>/dev/null || true
    sudo docker compose up -d
    
    # 等待服务启动
    sleep 15
    
    # 检查服务状态
    sudo docker compose ps
    
    ok "TeslaMate安装完成"
}

# 显示安装结果
show_result() {
    echo ""
    echo "=========================================="
    echo "✅ TeslaMate 安装完成"
    echo "=========================================="
    echo "访问地址:"
    echo "  TeslaMate: http://localhost:4000"
    echo "  Grafana:   http://localhost:3000"
    echo ""
    echo "Grafana 默认账号: admin/admin"
    echo "首次访问可能需要 1-2 分钟数据库初始化"
    echo "=========================================="
}

# 主函数
main() {
    local install_docker_env=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-docker)
                install_docker_env=true
                shift
                ;;
            -h|--help)
                echo "用法: $0 [--install-docker]"
                echo ""
                echo "选项:"
                echo "  --install-docker    强制重新安装Docker环境（仅限Ubuntu/Debian）"
                echo "  -h, --help         显示帮助信息"
                echo ""
                echo "说明:"
                echo "  无参数调用时，如果Docker未安装会自动安装"
                echo "  使用--install-docker会强制重新安装Docker"
                exit 0
                ;;
            *)
                error "未知参数: $1"
                exit 1
                ;;
        esac
    done
    
    log "开始TeslaMate本地安装"
    
    if [ "$install_docker_env" = "true" ]; then
        install_docker
    else
        check_docker
    fi
    
    install_teslamate
    show_result
    
    ok "安装流程全部完成"
}

main "$@"
