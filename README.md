# 服务器探针系统

服务器探针系统是一个轻量级的服务器监控工具，用于实时监控服务器的CPU、内存、磁盘、网络等指标，并提供报警功能。

## 功能特性

- **系统指标监控**：实时监控CPU、内存、磁盘、网络等系统指标
- **进程监控**：监控指定进程的资源使用情况
- **服务监控**：监控HTTP、TCP等服务的可用性和响应时间，支持自动配置同步
- **日志监控**：监控系统日志和应用日志，支持关键词匹配
- **报警系统**：支持邮件、Webhook、短信等多种报警通知方式
- **Web界面**：直观的Web界面，展示监控数据和报警信息

## 系统架构

系统由以下组件组成：

- **客户端代理**：部署在被监控服务器上，收集系统指标和日志信息
- **服务端**：接收客户端数据，处理和存储监控数据，提供API接口
- **报警系统**：根据配置的规则，触发报警并发送通知
- **Web界面**：展示监控数据和报警信息的用户界面

## 快速开始

### 一键安装脚本（推荐）

**Linux/macOS:**
```bash
# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/WeirdStar0/server-probe/main/install.sh | sudo bash
```

**Windows:**
1. 下载 `install.bat` 脚本
2. 右键选择「以管理员身份运行」

### 使用 Docker Compose

```bash
# 克隆项目
git clone https://github.com/WeirdStar0/server-probe.git
cd server-probe

# 启动服务
docker-compose up -d
```

访问 http://localhost:2110，使用默认账号 `admin/admin` 登录。

### 服务端

1. 下载并解压服务端程序
2. 修改配置文件 `configs/server.json`
3. 启动服务端程序

```bash
# 使用默认配置启动
./server-probe-server

# 指定配置文件启动
./server-probe-server -config configs/server.json

# 指定端口和数据目录
./server-probe-server -port 8080 -data ./data
```

### 客户端

1. 下载并解压客户端程序
2. 修改配置文件 `configs/client.json`
3. 启动客户端程序

```bash
# 使用默认配置启动
./server-probe-client

# 指定配置文件启动
./server-probe-client -config configs/client.json

# 指定服务端地址
./server-probe-client -server ws://server-ip:2111/ws
```

## 报警系统

### 报警规则

报警规则由以下部分组成：

- **名称**：规则名称
- **目标**：监控目标，可以是特定主机或所有主机
- **指标**：监控的指标，如 `cpu.usage`、`memory.used_percent` 等
- **条件**：触发条件，如 `> 90`、`< 10` 等
- **级别**：报警级别，如 `email,sms`，表示同时通过邮件和短信发送报警
- **描述**：规则描述
- **是否启用**：是否启用该规则
- **静默时间**：两次报警之间的最小间隔时间（秒）

### 配置报警通知

在 `configs/server.json` 中配置报警通知方式：

```json
{
  "alert": {
    "enabled": true,
    "check_interval_seconds": 60,
    "metrics_expiration_seconds": 300,
    "alert_on_expired_metrics": true,
    "email": {
      "enabled": true,
      "host": "smtp.example.com",
      "port": 587,
      "username": "user@example.com",
      "password": "your_password",
      "from": "alert@example.com",
      "to": ["admin@example.com"]
    },
    "webhook": {
      "enabled": false,
      "url": "https://example.com/webhook",
      "headers": {"Content-Type": "application/json"},
      "timeout_seconds": 10
    },
    "sms": {
      "enabled": false,
      "url": "https://api.example.com/sms",
      "api_key": "your_api_key",
      "headers": {"Content-Type": "application/json"},
      "params": {},
      "phone_numbers": ["+1234567890"],
      "timeout_seconds": 10
    }
  }
}
```

### 创建报警规则

通过API创建报警规则：

```bash
curl -X POST http://localhost:8080/api/v1/alerts/rules \
  -H "Content-Type: application/json" \
  -d '{
    "name": "CPU使用率过高",
    "target": "*",
    "metric": "cpu.usage",
    "condition": "> 90",
    "level": "email,sms",
    "description": "CPU使用率超过90%",
    "enabled": true,
    "silence_seconds": 300
  }'
```

## API接口

### 主机相关

- `GET /api/v1/hosts`：获取所有主机
- `GET /api/v1/hosts/:hostname`：获取主机信息
- `DELETE /api/v1/hosts/:hostname`：删除主机

### 指标相关

- `GET /api/v1/metrics/:hostname/latest`：获取最新指标
- `GET /api/v1/metrics/:hostname/range`：获取指标范围

### 进程相关

- `GET /api/v1/hosts/:hostname/processes`：获取进程信息
- `POST /api/v1/hosts/:hostname/process-filter`：更新进程过滤器

### 服务相关

- `GET /api/v1/hosts/:hostname/services`：获取服务信息
- `POST /api/v1/services`：创建服务监控
- `DELETE /api/v1/services/:id`：删除服务监控

### 日志相关

- `GET /api/v1/hosts/:hostname/logs`：获取日志信息
- `GET /api/v1/hosts/:hostname/log-settings`：获取日志设置
- `POST /api/v1/hosts/log-settings`：更新日志设置

### 报警相关

- `GET /api/v1/alerts/rules`：获取所有报警规则
- `POST /api/v1/alerts/rules`：创建报警规则
- `GET /api/v1/alerts/rules/:id`：获取报警规则
- `PUT /api/v1/alerts/rules/:id`：更新报警规则
- `DELETE /api/v1/alerts/rules/:id`：删除报警规则
- `GET /api/v1/alerts/history`：获取报警历史

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。