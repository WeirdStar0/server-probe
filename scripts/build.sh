#!/bin/bash

# 服务器探针系统构建脚本
# 支持多平台交叉编译

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
APP_NAME="server-probe"
VERSION=${VERSION:-"v1.0.0"}
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=${GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}
GITHUB_REPO="WeirdStar0/server-probe"

# 构建目录
BUILD_DIR="build"
DIST_DIR="dist"

# 支持的平台
PLATFORMS=(
    "linux/amd64"
    "linux/386"
    "linux/arm64"
    "linux/arm"
    "windows/amd64"
    "windows/386"
    "darwin/amd64"
    "darwin/arm64"
    "freebsd/amd64"
)

# LDFLAGS
LDFLAGS="-X 'github.com/${GITHUB_REPO}/pkg/version.Version=${VERSION}' \
         -X 'github.com/${GITHUB_REPO}/pkg/version.BuildTime=${BUILD_TIME}' \
         -X 'github.com/${GITHUB_REPO}/pkg/version.GitCommit=${GIT_COMMIT}'"

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

# 检查依赖
check_dependencies() {
    log_info "检查构建依赖..."
    
    if ! command -v go &> /dev/null; then
        log_error "Go 未安装，请先安装 Go 1.20+"
        exit 1
    fi
    
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    log_info "Go 版本: ${GO_VERSION}"
    
    if ! command -v git &> /dev/null; then
        log_warning "Git 未安装，将使用默认提交信息"
    fi
    
    log_success "依赖检查完成"
}

# 清理构建目录
clean() {
    log_info "清理构建目录..."
    rm -rf "${BUILD_DIR}" "${DIST_DIR}"
    log_success "清理完成"
}

# 创建构建目录
setup_dirs() {
    log_info "创建构建目录..."
    mkdir -p "${BUILD_DIR}" "${DIST_DIR}"
}

# 构建单个平台
build_platform() {
    local platform=$1
    local os=$(echo $platform | cut -d'/' -f1)
    local arch=$(echo $platform | cut -d'/' -f2)
    
    log_info "构建 ${os}/${arch}..."
    
    # 设置环境变量
    export GOOS=$os
    export GOARCH=$arch
    export CGO_ENABLED=0
    
    # 构建服务端
    local server_binary="${BUILD_DIR}/${APP_NAME}-server-${os}-${arch}"
    if [ "$os" = "windows" ]; then
        server_binary="${server_binary}.exe"
    fi
    
    go build -ldflags "${LDFLAGS}" -o "$server_binary" ./cmd/server
    if [ $? -ne 0 ]; then
        log_error "服务端构建失败: ${os}/${arch}"
        return 1
    fi
    
    # 构建客户端
    local agent_binary="${BUILD_DIR}/${APP_NAME}-agent-${os}-${arch}"
    if [ "$os" = "windows" ]; then
        agent_binary="${agent_binary}.exe"
    fi
    
    go build -ldflags "${LDFLAGS}" -o "$agent_binary" ./cmd/agent
    if [ $? -ne 0 ]; then
        log_error "客户端构建失败: ${os}/${arch}"
        return 1
    fi
    
    log_success "构建完成: ${os}/${arch}"
}

# 打包发布文件
package_release() {
    log_info "打包发布文件..."
    
    for platform in "${PLATFORMS[@]}"; do
        local os=$(echo $platform | cut -d'/' -f1)
        local arch=$(echo $platform | cut -d'/' -f2)
        
        local package_name="${APP_NAME}-${os}-${arch}"
        local package_dir="${BUILD_DIR}/${package_name}"
        
        # 创建包目录
        mkdir -p "$package_dir"
        
        # 复制二进制文件
        if [ "$os" = "windows" ]; then
            cp "${BUILD_DIR}/${APP_NAME}-server-${os}-${arch}.exe" "${package_dir}/"
            cp "${BUILD_DIR}/${APP_NAME}-agent-${os}-${arch}.exe" "${package_dir}/"
        else
            cp "${BUILD_DIR}/${APP_NAME}-server-${os}-${arch}" "${package_dir}/"
            cp "${BUILD_DIR}/${APP_NAME}-agent-${os}-${arch}" "${package_dir}/"
        fi
        
        # 复制配置文件和文档
        cp -r configs "${package_dir}/"
        cp README.md "${package_dir}/"
        cp CHANGELOG.md "${package_dir}/"
        
        # 复制安装脚本
        if [ "$os" = "windows" ]; then
            cp install.bat "${package_dir}/"
        else
            cp install.sh "${package_dir}/"
            chmod +x "${package_dir}/install.sh"
        fi
        
        # 打包
        cd "${BUILD_DIR}"
        if [ "$os" = "windows" ]; then
            zip -r "../${DIST_DIR}/${package_name}.zip" "$package_name"
        else
            tar -czf "../${DIST_DIR}/${package_name}.tar.gz" "$package_name"
        fi
        cd ..
        
        # 清理临时目录
        rm -rf "$package_dir"
        
        log_success "打包完成: ${package_name}"
    done
}

# 显示构建信息
show_build_info() {
    log_success "构建完成！"
    echo
    echo "=== 构建信息 ==="
    echo "版本: ${VERSION}"
    echo "构建时间: ${BUILD_TIME}"
    echo "Git提交: ${GIT_COMMIT}"
    echo "构建平台: ${#PLATFORMS[@]} 个"
    echo
    echo "=== 发布文件 ==="
    ls -la "${DIST_DIR}/"
    echo
    echo "=== 文件大小 ==="
    du -sh "${DIST_DIR}"/*
}

# 显示帮助信息
show_help() {
    echo "服务器探针系统构建脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  build       构建所有平台 (默认)"
    echo "  clean       清理构建目录"
    echo "  package     仅打包现有构建文件"
    echo "  help        显示此帮助信息"
    echo
    echo "环境变量:"
    echo "  VERSION     版本号 (默认: v1.0.0)"
    echo "  GIT_COMMIT  Git提交哈希 (默认: 自动获取)"
    echo
    echo "示例:"
    echo "  $0 build"
    echo "  VERSION=v1.2.0 $0 build"
    echo "  $0 clean"
}

# 主函数
main() {
    local action=${1:-build}
    
    case $action in
        build)
            check_dependencies
            clean
            setup_dirs
            
            log_info "开始构建 ${APP_NAME} ${VERSION}..."
            
            # 构建所有平台
            for platform in "${PLATFORMS[@]}"; do
                build_platform "$platform"
            done
            
            # 打包发布文件
            package_release
            
            # 显示构建信息
            show_build_info
            ;;
        clean)
            clean
            ;;
        package)
            setup_dirs
            package_release
            show_build_info
            ;;
        help)
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