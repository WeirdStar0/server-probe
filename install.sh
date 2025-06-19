#!/bin/bash

# 服务器探针系统一键安装脚本 (Linux/macOS)
# 支持自动检测系统架构并下载对应版本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
APP_NAME="server-probe"
VERSION="latest"
INSTALL_DIR="/opt/server-probe"
SERVICE_USER="probe"
GITHUB_REPO="WeirdStar0/server-probe"
DATA_DIR="$INSTALL_DIR/data"
CONFIG_DIR="$INSTALL_DIR/configs"
LOG_DIR="$INSTALL_DIR/logs"

# 函数定义
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

# 检测系统信息
detect_system() {
    log_info "检测系统信息..."
    
    # 检测操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="darwin"
    else
        log_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
    
    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="arm"
            ;;
        *)
            log_error "不支持的架构: $ARCH"
            exit 1
            ;;
    esac
    
    log_success "检测到系统: $OS-$ARCH"
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local deps=("curl" "tar" "systemctl")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_info "请先安装缺少的依赖"
        
        # 提供安装建议
        if command -v apt-get &> /dev/null; then
            log_info "Ubuntu/Debian: sudo apt-get update && sudo apt-get install ${missing_deps[*]}"
        elif command -v yum &> /dev/null; then
            log_info "CentOS/RHEL: sudo yum install ${missing_deps[*]}"
        elif command -v dnf &> /dev/null; then
            log_info "Fedora: sudo dnf install ${missing_deps[*]}"
        fi
        exit 1
    fi
    
    log_success "所有依赖已满足"
}

# 创建用户
create_user() {
    log_info "创建系统用户..."
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd --system --no-create-home --shell /bin/false "$SERVICE_USER"
        log_success "创建用户: $SERVICE_USER"
    else
        log_info "用户 $SERVICE_USER 已存在"
    fi
}

# 创建目录
create_directories() {
    log_info "创建安装目录..."
    
    local dirs=("$INSTALL_DIR" "$DATA_DIR" "$CONFIG_DIR" "$LOG_DIR")
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chown "$SERVICE_USER:$SERVICE_USER" "$dir"
        chmod 755 "$dir"
    done
    
    log_success "目录创建完成"
}

# 下载程序
download_binary() {
    log_info "下载程序文件..."
    
    local download_url
    local filename="${APP_NAME}-${OS}-${ARCH}.tar.gz"
    
    if [[ "$VERSION" == "latest" ]]; then
        # 获取最新版本号
        VERSION=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ -z "$VERSION" ]]; then
            log_error "无法获取最新版本信息"
            exit 1
        fi
    fi
    
    download_url="https://github.com/$GITHUB_REPO/releases/download/$VERSION/$filename"
    
    log_info "下载版本: $VERSION"
    log_info "下载地址: $download_url"
    
    # 下载文件
    local temp_file="/tmp/$filename"
    if curl -L -o "$temp_file" "$download_url"; then
        log_success "下载完成"
    else
        log_error "下载失败"
        exit 1
    fi
    
    # 解压文件
    log_info "解压程序文件..."
    tar -xzf "$temp_file" -C "$INSTALL_DIR" --strip-components=1
    
    # 设置权限
    chmod +x "$INSTALL_DIR/server-probe-server"
    chmod +x "$INSTALL_DIR/server-probe-agent"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    
    # 清理临时文件
    rm -f "$temp_file"
    
    log_success "程序安装完成"
}

# 创建配置文件
create_config() {
    log_info "创建配置文件..."
    
    # 服务端配置
    cat > "$CONFIG_DIR/server.json" << EOF
{
  "server": {
    "host": "0.0.0.0",
    "port": 2110,
    "ws_port": 2111,
    "data_dir": "$DATA_DIR"
  },
  "auth": {
    "jwt_secret": "$JWT_SECRET",
    "token_expiry": 24
  },
  "alert": {
    "enabled": true,
    "check_interval_seconds": 60,
    "email": {
      "enabled": false,
      "host": "smtp.example.com",
      "port": 587,
      "username": "user@example.com",
      "password": "password",
      "from": "alert@example.com",
      "to": ["admin@example.com"]
    }
  },
  "logging": {
    "level": "info",
    "file": "$LOG_DIR/server.log"
  }
}
EOF
    
    chown "$SERVICE_USER:$SERVICE_USER" "$CONFIG_DIR/server.json"
    chmod 600 "$CONFIG_DIR/server.json"
    
    log_success "配置文件创建完成"
}

# 创建systemd服务
create_systemd_service() {
    log_info "创建systemd服务..."
    
    # 服务端服务
    cat > /etc/systemd/system/server-probe-server.service << EOF
[Unit]
Description=Server Probe Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/server-probe-server -config $CONFIG_DIR/server.json
Restart=always
RestartSec=5
LimitNOFILE=65536

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR $LOG_DIR

[Install]
WantedBy=multi-user.target
EOF
    
    # 客户端服务（可选）
    cat > /etc/systemd/system/server-probe-agent.service << EOF
[Unit]
Description=Server Probe Agent
After=network.target
Wants=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/server-probe-agent -server ws://localhost:8080/ws
Restart=always
RestartSec=5
LimitNOFILE=65536

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd
    systemctl daemon-reload
    
    log_success "systemd服务创建完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    # 检查防火墙状态
    if command -v ufw >/dev/null 2>&1; then
        # Ubuntu/Debian UFW
        ufw allow 2110/tcp
        ufw allow 2111/tcp
        log_success "UFW防火墙规则添加成功"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        # CentOS/RHEL firewalld
        firewall-cmd --permanent --add-port=2110/tcp
        firewall-cmd --permanent --add-port=2111/tcp
        firewall-cmd --reload
        log_success "firewalld防火墙规则添加成功"
    elif command -v iptables >/dev/null 2>&1; then
        # 通用iptables
        iptables -A INPUT -p tcp --dport 2110 -j ACCEPT
        iptables -A INPUT -p tcp --dport 2111 -j ACCEPT
        # 尝试保存规则
        if command -v iptables-save >/dev/null 2>&1; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        fi
        log_success "iptables防火墙规则添加成功"
    else
        log_warning "未检测到防火墙，请手动开放2110和2111端口"
    fi
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    # 启用并启动服务端
    systemctl enable server-probe-server
    systemctl start server-probe-server
    
    # 检查服务状态
    if systemctl is-active --quiet server-probe-server; then
        log_success "服务端启动成功"
    else
        log_error "服务端启动失败"
        log_info "查看日志: journalctl -u server-probe-server -f"
        exit 1
    fi
    
    # 询问是否启动客户端
    read -p "是否在本机启动客户端代理? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl enable server-probe-agent
        systemctl start server-probe-agent
        
        if systemctl is-active --quiet server-probe-agent; then
            log_success "客户端启动成功"
        else
            log_warning "客户端启动失败"
            log_info "查看日志: journalctl -u server-probe-agent -f"
        fi
    fi
}

# 显示安装信息
show_install_info() {
    log_success "安装完成！"
    echo
    echo "=== 安装信息 ==="
    echo "安装目录: $INSTALL_DIR"
    echo "配置目录: $CONFIG_DIR"
    echo "数据目录: $DATA_DIR"
    echo "日志目录: $LOG_DIR"
    echo "服务用户: $SERVICE_USER"
    echo
    echo "=== 访问信息 ==="
    echo "Web界面: http://$(hostname -I | awk '{print $1}'):2110"
    echo "默认用户名: admin"
    echo "默认密码: admin"
    echo
    echo "=== 常用命令 ==="
    echo "查看服务状态: systemctl status server-probe-server"
    echo "查看服务日志: journalctl -u server-probe-server -f"
    echo "重启服务: systemctl restart server-probe-server"
    echo "停止服务: systemctl stop server-probe-server"
    echo
    echo "=== 客户端部署 ==="
    echo "在其他服务器上运行客户端:"
    echo "./server-probe-agent -server ws://$(hostname -I | awk '{print $1}'):2111/ws"
    echo
    echo "=== 安全提醒 ==="
    log_warning "请立即登录Web界面修改默认密码！"
    log_warning "建议配置HTTPS和防火墙规则！"
}

# 卸载函数
uninstall() {
    log_info "开始卸载服务器探针系统..."
    
    # 停止服务
    systemctl stop server-probe-server 2>/dev/null || true
    systemctl stop server-probe-agent 2>/dev/null || true
    
    # 禁用服务
    systemctl disable server-probe-server 2>/dev/null || true
    systemctl disable server-probe-agent 2>/dev/null || true
    
    # 删除服务文件
    rm -f /etc/systemd/system/server-probe-server.service
    rm -f /etc/systemd/system/server-probe-agent.service
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 询问是否删除数据
    read -p "是否删除所有数据和配置? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        log_success "数据和配置已删除"
    else
        log_info "数据和配置保留在: $INSTALL_DIR"
    fi
    
    # 询问是否删除用户
    read -p "是否删除系统用户 $SERVICE_USER? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        userdel "$SERVICE_USER" 2>/dev/null || true
        log_success "用户 $SERVICE_USER 已删除"
    fi
    
    log_success "卸载完成"
}

# 显示帮助信息
show_help() {
    echo "服务器探针系统一键安装脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  install     安装服务器探针系统 (默认)"
    echo "  uninstall   卸载服务器探针系统"
    echo "  status      查看服务状态"
    echo "  restart     重启服务"
    echo "  logs        查看服务日志"
    echo "  help        显示此帮助信息"
    echo
    echo "环境变量:"
    echo "  VERSION     指定版本 (默认: latest)"
    echo "  INSTALL_DIR 指定安装目录 (默认: /opt/server-probe)"
    echo
    echo "示例:"
    echo "  $0 install"
    echo "  VERSION=v1.0.0 $0 install"
    echo "  INSTALL_DIR=/usr/local/server-probe $0 install"
}

# 查看状态
show_status() {
    echo "=== 服务状态 ==="
    systemctl status server-probe-server --no-pager
    echo
    systemctl status server-probe-agent --no-pager
}

# 重启服务
restart_services() {
    log_info "重启服务..."
    systemctl restart server-probe-server
    systemctl restart server-probe-agent 2>/dev/null || true
    log_success "服务重启完成"
}

# 查看日志
show_logs() {
    echo "=== 服务端日志 ==="
    journalctl -u server-probe-server -n 50 --no-pager
    echo
    echo "=== 客户端日志 ==="
    journalctl -u server-probe-agent -n 50 --no-pager
}

# 主函数
main() {
    local action="${1:-install}"
    
    case "$action" in
        install)
            check_root
            detect_system
            check_dependencies
            create_user
            create_directories
            download_binary
            create_config
            create_systemd_service
            configure_firewall
            start_services
            show_install_info
            ;;
        uninstall)
            check_root
            uninstall
            ;;
        status)
            show_status
            ;;
        restart)
            check_root
            restart_services
            ;;
        logs)
            show_logs
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知操作: $action"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"