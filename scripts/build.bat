@echo off
setlocal enabledelayedexpansion

REM 服务器探针系统构建脚本 (Windows)
REM 支持多平台交叉编译

REM 配置变量
set APP_NAME=server-probe
if "%VERSION%"=="" set VERSION=v1.0.0
for /f "tokens=*" %%i in ('powershell -Command "Get-Date -UFormat '%%Y-%%m-%%dT%%H:%%M:%%SZ'"') do set BUILD_TIME=%%i
if "%GIT_COMMIT%"=="" (
    for /f "tokens=*" %%i in ('git rev-parse --short HEAD 2^>nul') do set GIT_COMMIT=%%i
    if "!GIT_COMMIT!"=="" set GIT_COMMIT=unknown
)
set GITHUB_REPO=WeirdStar0/server-probe

REM 构建目录
set BUILD_DIR=build
set DIST_DIR=dist

REM 颜色定义（Windows 10+）
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

REM LDFLAGS
set LDFLAGS=-X 'github.com/%GITHUB_REPO%/pkg/version.Version=%VERSION%' -X 'github.com/%GITHUB_REPO%/pkg/version.BuildTime=%BUILD_TIME%' -X 'github.com/%GITHUB_REPO%/pkg/version.GitCommit=%GIT_COMMIT%'

REM 支持的平台
set PLATFORMS=linux/amd64 linux/386 linux/arm64 linux/arm windows/amd64 windows/386 darwin/amd64 darwin/arm64 freebsd/amd64

REM 函数定义
:log_info
echo %BLUE%[INFO]%NC% %~1
goto :eof

:log_success
echo %GREEN%[SUCCESS]%NC% %~1
goto :eof

:log_warning
echo %YELLOW%[WARNING]%NC% %~1
goto :eof

:log_error
echo %RED%[ERROR]%NC% %~1
goto :eof

REM 检查依赖
:check_dependencies
call :log_info "检查构建依赖..."

go version >nul 2>&1
if %errorLevel% neq 0 (
    call :log_error "Go 未安装，请先安装 Go 1.20+"
    exit /b 1
)

for /f "tokens=3" %%i in ('go version') do (
    set GO_VERSION=%%i
    set GO_VERSION=!GO_VERSION:go=!
)
call :log_info "Go 版本: !GO_VERSION!"

git --version >nul 2>&1
if %errorLevel% neq 0 (
    call :log_warning "Git 未安装，将使用默认提交信息"
)

call :log_success "依赖检查完成"
goto :eof

REM 清理构建目录
:clean
call :log_info "清理构建目录..."
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
if exist "%DIST_DIR%" rmdir /s /q "%DIST_DIR%"
call :log_success "清理完成"
goto :eof

REM 创建构建目录
:setup_dirs
call :log_info "创建构建目录..."
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"
goto :eof

REM 构建单个平台
:build_platform
set platform=%~1
for /f "tokens=1,2 delims=/" %%a in ("%platform%") do (
    set os=%%a
    set arch=%%b
)

call :log_info "构建 !os!/!arch!..."

REM 设置环境变量
set GOOS=!os!
set GOARCH=!arch!
set CGO_ENABLED=0

REM 构建服务端
set server_binary=%BUILD_DIR%\%APP_NAME%-server-!os!-!arch!
if "!os!"=="windows" set server_binary=!server_binary!.exe

go build -ldflags "%LDFLAGS%" -o "!server_binary!" ./cmd/server
if %errorLevel% neq 0 (
    call :log_error "服务端构建失败: !os!/!arch!"
    goto :eof
)

REM 构建客户端
set agent_binary=%BUILD_DIR%\%APP_NAME%-agent-!os!-!arch!
if "!os!"=="windows" set agent_binary=!agent_binary!.exe

go build -ldflags "%LDFLAGS%" -o "!agent_binary!" ./cmd/agent
if %errorLevel% neq 0 (
    call :log_error "客户端构建失败: !os!/!arch!"
    goto :eof
)

call :log_success "构建完成: !os!/!arch!"
goto :eof

REM 打包发布文件
:package_release
call :log_info "打包发布文件..."

for %%p in (%PLATFORMS%) do (
    for /f "tokens=1,2 delims=/" %%a in ("%%p") do (
        set os=%%a
        set arch=%%b
        
        set package_name=%APP_NAME%-!os!-!arch!
        set package_dir=%BUILD_DIR%\!package_name!
        
        REM 创建包目录
        if not exist "!package_dir!" mkdir "!package_dir!"
        
        REM 复制二进制文件
        if "!os!"=="windows" (
            copy "%BUILD_DIR%\%APP_NAME%-server-!os!-!arch!.exe" "!package_dir!\"
            copy "%BUILD_DIR%\%APP_NAME%-agent-!os!-!arch!.exe" "!package_dir!\"
        ) else (
            copy "%BUILD_DIR%\%APP_NAME%-server-!os!-!arch!" "!package_dir!\"
            copy "%BUILD_DIR%\%APP_NAME%-agent-!os!-!arch!" "!package_dir!\"
        )
        
        REM 复制配置文件和文档
        xcopy /e /i configs "!package_dir!\configs"
        copy README.md "!package_dir!\"
        copy CHANGELOG.md "!package_dir!\"
        
        REM 复制安装脚本
        if "!os!"=="windows" (
            copy install.bat "!package_dir!\"
        ) else (
            copy install.sh "!package_dir!\"
        )
        
        REM 打包
        cd "%BUILD_DIR%"
        if "!os!"=="windows" (
            powershell -Command "Compress-Archive -Path '!package_name!' -DestinationPath '..\%DIST_DIR%\!package_name!.zip' -Force"
        ) else (
            tar -czf "..\%DIST_DIR%\!package_name!.tar.gz" "!package_name!"
        )
        cd ..
        
        REM 清理临时目录
        rmdir /s /q "!package_dir!"
        
        call :log_success "打包完成: !package_name!"
    )
)
goto :eof

REM 显示构建信息
:show_build_info
call :log_success "构建完成！"
echo.
echo === 构建信息 ===
echo 版本: %VERSION%
echo 构建时间: %BUILD_TIME%
echo Git提交: %GIT_COMMIT%
echo.
echo === 发布文件 ===
dir /b "%DIST_DIR%"
echo.
echo === 文件大小 ===
for %%f in ("%DIST_DIR%\*") do (
    echo %%~nxf: %%~zf bytes
)
goto :eof

REM 显示帮助信息
:show_help
echo 服务器探针系统构建脚本 (Windows)
echo.
echo 用法: %~nx0 [选项]
echo.
echo 选项:
echo   build       构建所有平台 (默认)
echo   clean       清理构建目录
echo   package     仅打包现有构建文件
echo   help        显示此帮助信息
echo.
echo 环境变量:
echo   VERSION     版本号 (默认: v1.0.0)
echo   GIT_COMMIT  Git提交哈希 (默认: 自动获取)
echo.
echo 示例:
echo   %~nx0 build
echo   set VERSION=v1.2.0 ^&^& %~nx0 build
echo   %~nx0 clean
goto :eof

REM 主函数
:main
set action=%1
if "%action%"=="" set action=build

if "%action%"=="build" (
    call :check_dependencies
    call :clean
    call :setup_dirs
    
    call :log_info "开始构建 %APP_NAME% %VERSION%..."
    
    REM 构建所有平台
    for %%p in (%PLATFORMS%) do (
        call :build_platform "%%p"
    )
    
    REM 打包发布文件
    call :package_release
    
    REM 显示构建信息
    call :show_build_info
) else if "%action%"=="clean" (
    call :clean
) else if "%action%"=="package" (
    call :setup_dirs
    call :package_release
    call :show_build_info
) else if "%action%"=="help" (
    call :show_help
) else (
    call :log_error "未知操作: %action%"
    call :show_help
    exit /b 1
)

goto :eof

REM 执行主函数
call :main %*