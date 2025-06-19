@echo off
setlocal enabledelayedexpansion

REM 服务器探针系统一键安装脚本 (Windows)
REM 支持自动检测系统架构并下载对应版本

REM 配置变量
set APP_NAME=server-probe
set VERSION=latest
set INSTALL_DIR=C:\Program Files\ServerProbe
set GITHUB_REPO=WeirdStar0/server-probe
set DATA_DIR=%INSTALL_DIR%\data
set CONFIG_DIR=%INSTALL_DIR%\configs
set LOG_DIR=%INSTALL_DIR%\logs
set SERVICE_NAME_SERVER=ServerProbeServer
set SERVICE_NAME_AGENT=ServerProbeAgent

REM 颜色定义（Windows 10+）
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

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

REM 检查管理员权限
:check_admin
call :log_info "检查管理员权限..."
net session >nul 2>&1
if %errorLevel% neq 0 (
    call :log_error "此脚本需要管理员权限运行"
    call :log_info "请右键点击脚本，选择'以管理员身份运行'"
    pause
    exit /b 1
)
call :log_success "管理员权限验证通过"
goto :eof

REM 检测系统信息
:detect_system
call :log_info "检测系统信息..."

REM 检测架构
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set ARCH=amd64
) else if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    set ARCH=386
) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    set ARCH=arm64
) else (
    call :log_error "不支持的架构: %PROCESSOR_ARCHITECTURE%"
    pause
    exit /b 1
)

set OS=windows
call :log_success "检测到系统: %OS%-%ARCH%"
goto :eof

REM 检查依赖
:check_dependencies
call :log_info "检查系统依赖..."

REM 检查PowerShell
powershell -Command "Get-Host" >nul 2>&1
if %errorLevel% neq 0 (
    call :log_error "PowerShell 未安装或不可用"
    pause
    exit /b 1
)

REM 检查curl（Windows 10 1803+自带）
curl --version >nul 2>&1
if %errorLevel% neq 0 (
    call :log_error "curl 未安装，请先安装 curl"
    call :log_info "可以从 https://curl.se/windows/ 下载"
    pause
    exit /b 1
)

REM 检查tar（Windows 10 1903+自带）
tar --version >nul 2>&1
if %errorLevel% neq 0 (
    call :log_error "tar 未安装，请升级到 Windows 10 1903+ 或安装 7-Zip"
    pause
    exit /b 1
)

call :log_success "所有依赖已满足"
goto :eof

REM 创建目录
:create_directories
call :log_info "创建安装目录..."

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

call :log_success "目录创建完成"
goto :eof

REM 下载程序
:download_binary
call :log_info "下载程序文件..."

set FILENAME=%APP_NAME%-%OS%-%ARCH%.zip
set TEMP_FILE=%TEMP%\%FILENAME%

REM 获取最新版本号
if "%VERSION%"=="latest" (
    call :log_info "获取最新版本信息..."
    powershell -Command "$response = Invoke-RestMethod -Uri 'https://api.github.com/repos/%GITHUB_REPO%/releases/latest'; $response.tag_name" > temp_version.txt
    set /p VERSION=<temp_version.txt
    del temp_version.txt
    if "!VERSION!"=="" (
        call :log_error "无法获取最新版本信息"
        pause
        exit /b 1
    )
)

set DOWNLOAD_URL=https://github.com/%GITHUB_REPO%/releases/download/!VERSION!/%FILENAME%

call :log_info "下载版本: !VERSION!"
call :log_info "下载地址: !DOWNLOAD_URL!"

REM 下载文件
curl -L -o "%TEMP_FILE%" "!DOWNLOAD_URL!"
if %errorLevel% neq 0 (
    call :log_error "下载失败"
    pause
    exit /b 1
)
call :log_success "下载完成"

REM 解压文件
call :log_info "解压程序文件..."
tar -xf "%TEMP_FILE%" -C "%INSTALL_DIR%"
if %errorLevel% neq 0 (
    call :log_error "解压失败"
    pause
    exit /b 1
)

REM 清理临时文件
del "%TEMP_FILE%"

call :log_success "程序安装完成"
goto :eof

REM 创建配置文件
:create_config
call :log_info "创建配置文件..."

REM 生成随机JWT密钥
powershell -Command "[System.Web.Security.Membership]::GeneratePassword(64, 0)" > temp_secret.txt
set /p JWT_SECRET=<temp_secret.txt
del temp_secret.txt

REM 转换路径分隔符
set DATA_DIR_JSON=%DATA_DIR:\=/%
set LOG_DIR_JSON=%LOG_DIR:\=/%

REM 创建服务端配置文件
(
echo {
echo   "server": {
echo     "host": "0.0.0.0",
echo     "port": 2110,
echo     "ws_port": 2111,
echo     "data_dir": "%DATA_DIR_JSON%"
echo   },
echo   "auth": {
echo     "jwt_secret": "%JWT_SECRET%",
echo     "token_expiry": 24
echo   },
echo   "alert": {
echo     "enabled": true,
echo     "check_interval_seconds": 60,
echo     "email": {
echo       "enabled": false,
echo       "host": "smtp.example.com",
echo       "port": 587,
echo       "username": "user@example.com",
echo       "password": "password",
echo       "from": "alert@example.com",
echo       "to": ["admin@example.com"]
echo     }
echo   },
echo   "logging": {
echo     "level": "info",
echo     "file": "%LOG_DIR_JSON%/server.log"
echo   }
echo }
) > "%CONFIG_DIR%\server.json"

call :log_success "配置文件创建完成"
goto :eof

REM 安装Windows服务
:install_service
call :log_info "安装Windows服务..."

REM 检查是否已安装NSSM
nssm version >nul 2>&1
if %errorLevel% neq 0 (
    call :log_info "下载NSSM服务管理工具..."
    
    REM 下载NSSM
    set NSSM_URL=https://nssm.cc/release/nssm-2.24.zip
    set NSSM_ZIP=%TEMP%\nssm.zip
    
    curl -L -o "%NSSM_ZIP%" "%NSSM_URL%"
    if %errorLevel% neq 0 (
        call :log_error "NSSM下载失败"
        pause
        exit /b 1
    )
    
    REM 解压NSSM
    tar -xf "%NSSM_ZIP%" -C "%TEMP%"
    
    REM 复制NSSM到系统目录
    if "%ARCH%"=="amd64" (
        copy "%TEMP%\nssm-2.24\win64\nssm.exe" "%WINDIR%\System32\nssm.exe"
    ) else (
        copy "%TEMP%\nssm-2.24\win32\nssm.exe" "%WINDIR%\System32\nssm.exe"
    )
    
    REM 清理临时文件
    del "%NSSM_ZIP%"
    rmdir /s /q "%TEMP%\nssm-2.24"
    
    call :log_success "NSSM安装完成"
fi

REM 安装服务端服务
call :log_info "安装服务端服务..."
nssm install %SERVICE_NAME_SERVER% "%INSTALL_DIR%\server-probe-server.exe"
nssm set %SERVICE_NAME_SERVER% Parameters "-config \"%CONFIG_DIR%\server.json\""
nssm set %SERVICE_NAME_SERVER% DisplayName "Server Probe Server"
nssm set %SERVICE_NAME_SERVER% Description "服务器探针系统 - 服务端"
nssm set %SERVICE_NAME_SERVER% Start SERVICE_AUTO_START
nssm set %SERVICE_NAME_SERVER% AppDirectory "%INSTALL_DIR%"
nssm set %SERVICE_NAME_SERVER% AppStdout "%LOG_DIR%\server-stdout.log"
nssm set %SERVICE_NAME_SERVER% AppStderr "%LOG_DIR%\server-stderr.log"

REM 安装客户端服务
call :log_info "安装客户端服务..."
nssm install %SERVICE_NAME_AGENT% "%INSTALL_DIR%\server-probe-agent.exe"
nssm set %SERVICE_NAME_AGENT% Parameters "-server ws://localhost:8080/ws"
nssm set %SERVICE_NAME_AGENT% DisplayName "Server Probe Agent"
nssm set %SERVICE_NAME_AGENT% Description "服务器探针系统 - 客户端代理"
nssm set %SERVICE_NAME_AGENT% Start SERVICE_DEMAND_START
nssm set %SERVICE_NAME_AGENT% AppDirectory "%INSTALL_DIR%"
nssm set %SERVICE_NAME_AGENT% AppStdout "%LOG_DIR%\agent-stdout.log"
nssm set %SERVICE_NAME_AGENT% AppStderr "%LOG_DIR%\agent-stderr.log"

call :log_success "Windows服务安装完成"
goto :eof

REM 配置防火墙
:configure_firewall
call :log_info "配置Windows防火墙..."

REM 添加防火墙规则
netsh advfirewall firewall add rule name="Server Probe Server" dir=in action=allow protocol=TCP localport=2110
netsh advfirewall firewall add rule name="Server Probe WebSocket" dir=in action=allow protocol=TCP localport=2111
if %errorLevel% equ 0 (
    call :log_success "防火墙规则添加成功"
) else (
    call :log_warning "防火墙规则添加失败，请手动开放2110和2111端口"
)
goto :eof

REM 启动服务
:start_services
call :log_info "启动服务..."

REM 启动服务端
net start %SERVICE_NAME_SERVER%
if %errorLevel% equ 0 (
    call :log_success "服务端启动成功"
) else (
    call :log_error "服务端启动失败"
    call :log_info "查看日志: %LOG_DIR%\server-stderr.log"
    pause
    exit /b 1
)

REM 询问是否启动客户端
set /p START_AGENT="是否在本机启动客户端代理? (y/n): "
if /i "%START_AGENT%"=="y" (
    net start %SERVICE_NAME_AGENT%
    if %errorLevel% equ 0 (
        call :log_success "客户端启动成功"
    ) else (
        call :log_warning "客户端启动失败"
        call :log_info "查看日志: %LOG_DIR%\agent-stderr.log"
    )
)
goto :eof

REM 显示安装信息
:show_install_info
call :log_success "安装完成！"
echo.
echo === 安装信息 ===
echo 安装目录: %INSTALL_DIR%
echo 配置目录: %CONFIG_DIR%
echo 数据目录: %DATA_DIR%
echo 日志目录: %LOG_DIR%
echo.
echo === 访问信息 ===
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do set LOCAL_IP=%%a
set LOCAL_IP=%LOCAL_IP: =%
echo Web界面: http://%LOCAL_IP%:2110
echo 默认用户名: admin
echo 默认密码: admin
echo.
echo === 服务管理 ===
echo 查看服务状态: sc query %SERVICE_NAME_SERVER%
echo 启动服务: net start %SERVICE_NAME_SERVER%
echo 停止服务: net stop %SERVICE_NAME_SERVER%
echo 重启服务: net stop %SERVICE_NAME_SERVER% ^&^& net start %SERVICE_NAME_SERVER%
echo.
echo === 客户端部署 ===
echo 在其他服务器上运行客户端:
echo server-probe-agent.exe -server ws://%LOCAL_IP%:2111/ws
echo.
echo === 安全提醒 ===
call :log_warning "请立即登录Web界面修改默认密码！"
call :log_warning "建议配置HTTPS和防火墙规则！"
goto :eof

REM 卸载函数
:uninstall
call :log_info "开始卸载服务器探针系统..."

REM 停止服务
net stop %SERVICE_NAME_SERVER% >nul 2>&1
net stop %SERVICE_NAME_AGENT% >nul 2>&1

REM 删除服务
nssm remove %SERVICE_NAME_SERVER% confirm >nul 2>&1
nssm remove %SERVICE_NAME_AGENT% confirm >nul 2>&1

REM 删除防火墙规则
netsh advfirewall firewall delete rule name="Server Probe Server" >nul 2>&1
netsh advfirewall firewall delete rule name="Server Probe WebSocket" >nul 2>&1

REM 询问是否删除数据
set /p DELETE_DATA="是否删除所有数据和配置? (y/n): "
if /i "%DELETE_DATA%"=="y" (
    rmdir /s /q "%INSTALL_DIR%"
    call :log_success "数据和配置已删除"
) else (
    call :log_info "数据和配置保留在: %INSTALL_DIR%"
)

call :log_success "卸载完成"
goto :eof

REM 显示帮助信息
:show_help
echo 服务器探针系统一键安装脚本 (Windows)
echo.
echo 用法: %~nx0 [选项]
echo.
echo 选项:
echo   install     安装服务器探针系统 (默认)
echo   uninstall   卸载服务器探针系统
echo   status      查看服务状态
echo   restart     重启服务
echo   logs        查看服务日志
echo   help        显示此帮助信息
echo.
echo 环境变量:
echo   VERSION     指定版本 (默认: latest)
echo   INSTALL_DIR 指定安装目录 (默认: C:\Program Files\ServerProbe)
echo.
echo 示例:
echo   %~nx0 install
echo   set VERSION=v1.0.0 ^&^& %~nx0 install
echo   set INSTALL_DIR=D:\ServerProbe ^&^& %~nx0 install
goto :eof

REM 查看状态
:show_status
echo === 服务状态 ===
sc query %SERVICE_NAME_SERVER%
echo.
sc query %SERVICE_NAME_AGENT%
goto :eof

REM 重启服务
:restart_services
call :log_info "重启服务..."
net stop %SERVICE_NAME_SERVER%
net stop %SERVICE_NAME_AGENT% >nul 2>&1
timeout /t 2 /nobreak >nul
net start %SERVICE_NAME_SERVER%
net start %SERVICE_NAME_AGENT% >nul 2>&1
call :log_success "服务重启完成"
goto :eof

REM 查看日志
:show_logs
echo === 服务端日志 ===
if exist "%LOG_DIR%\server-stderr.log" (
    type "%LOG_DIR%\server-stderr.log"
) else (
    echo 日志文件不存在
)
echo.
echo === 客户端日志 ===
if exist "%LOG_DIR%\agent-stderr.log" (
    type "%LOG_DIR%\agent-stderr.log"
) else (
    echo 日志文件不存在
)
goto :eof

REM 主函数
:main
set ACTION=%1
if "%ACTION%"=="" set ACTION=install

if "%ACTION%"=="install" (
    call :check_admin
    call :detect_system
    call :check_dependencies
    call :create_directories
    call :download_binary
    call :create_config
    call :install_service
    call :configure_firewall
    call :start_services
    call :show_install_info
) else if "%ACTION%"=="uninstall" (
    call :check_admin
    call :uninstall
) else if "%ACTION%"=="status" (
    call :show_status
) else if "%ACTION%"=="restart" (
    call :check_admin
    call :restart_services
) else if "%ACTION%"=="logs" (
    call :show_logs
) else if "%ACTION%"=="help" (
    call :show_help
) else (
    call :log_error "未知操作: %ACTION%"
    call :show_help
    exit /b 1
)

pause
goto :eof

REM 执行主函数
call :main %*