# 贡献指南

感谢您对服务器探针系统的关注！我们欢迎所有形式的贡献，包括但不限于：

- 🐛 报告错误
- 💡 提出新功能建议
- 📝 改进文档
- 🔧 提交代码修复
- ✨ 开发新功能

## 开始之前

在开始贡献之前，请确保您已经：

1. 阅读了项目的 [README.md](README.md)
2. 查看了现有的 [Issues](https://github.com/WeirdStar0/server-probe/issues)
3. 了解了项目的代码结构和设计理念

## 开发环境设置

### 系统要求

- Go 1.20 或更高版本
- Git
- Make (可选，用于构建脚本)
- Docker (可选，用于容器化测试)

### 克隆项目

```bash
git clone https://github.com/WeirdStar0/server-probe.git
cd server-probe
```

### 安装依赖

```bash
go mod download
```

### 构建项目

```bash
# 使用 Make
make build

# 或者直接使用 Go
go build -o server-probe-server ./cmd/server
go build -o server-probe-agent ./cmd/agent
```

### 运行测试

```bash
# 运行所有测试
go test ./...

# 运行特定包的测试
go test ./internal/server/api

# 运行测试并显示覆盖率
go test -cover ./...
```

## 贡献流程

### 1. 创建 Issue

在开始编码之前，请先创建一个 Issue 来描述您要解决的问题或要添加的功能。这有助于：

- 避免重复工作
- 获得社区反馈
- 确保您的贡献符合项目方向

### 2. Fork 项目

1. 点击项目页面右上角的 "Fork" 按钮
2. 克隆您的 Fork 到本地

```bash
git clone https://github.com/YOUR_USERNAME/server-probe.git
cd server-probe
git remote add upstream https://github.com/WeirdStar0/server-probe.git
```

### 3. 创建分支

为您的贡献创建一个新分支：

```bash
git checkout -b feature/your-feature-name
# 或者
git checkout -b fix/your-bug-fix
```

分支命名规范：
- `feature/` - 新功能
- `fix/` - 错误修复
- `docs/` - 文档更新
- `refactor/` - 代码重构
- `test/` - 测试相关

### 4. 编写代码

#### 代码规范

- 遵循 Go 官方代码规范
- 使用 `gofmt` 格式化代码
- 使用 `golint` 检查代码质量
- 添加必要的注释，特别是公共 API
- 为新功能编写测试

#### 提交规范

使用清晰的提交信息，格式如下：

```
type(scope): description

[optional body]

[optional footer]
```

类型（type）：
- `feat`: 新功能
- `fix`: 错误修复
- `docs`: 文档更新
- `style`: 代码格式化
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建过程或辅助工具的变动

示例：
```
feat(api): add metrics endpoint for CPU usage

Add new REST API endpoint to retrieve CPU usage metrics
with historical data support.

Closes #123
```

### 5. 测试您的更改

在提交 PR 之前，请确保：

```bash
# 运行所有测试
go test ./...

# 检查代码格式
go fmt ./...

# 运行代码检查
go vet ./...

# 构建项目
go build ./cmd/server
go build ./cmd/agent
```

### 6. 提交 Pull Request

1. 推送您的分支到 GitHub

```bash
git push origin feature/your-feature-name
```

2. 在 GitHub 上创建 Pull Request
3. 填写 PR 模板，包括：
   - 变更描述
   - 相关 Issue 编号
   - 测试说明
   - 截图（如果适用）

## 代码结构

```
server-probe/
├── cmd/                    # 应用程序入口
│   ├── server/            # 服务端
│   └── agent/             # 客户端
├── internal/              # 内部包
│   ├── server/            # 服务端逻辑
│   │   ├── api/          # REST API
│   │   ├── websocket/    # WebSocket 处理
│   │   ├── storage/      # 数据存储
│   │   ├── alert/        # 报警系统
│   │   └── auth/         # 认证授权
│   ├── agent/             # 客户端逻辑
│   │   ├── collector/    # 数据采集
│   │   └── reporter/     # 数据上报
│   └── common/            # 共享代码
├── pkg/                   # 公共包
│   ├── logger/           # 日志
│   ├── utils/            # 工具函数
│   └── version/          # 版本信息
├── configs/               # 配置文件
├── docs/                  # 文档
├── scripts/               # 构建脚本
└── web/                   # Web 前端资源
```

## 编码指南

### Go 代码规范

1. **包命名**：使用小写字母，避免下划线
2. **函数命名**：使用驼峰命名法
3. **常量命名**：使用大写字母和下划线
4. **错误处理**：始终检查错误，使用有意义的错误信息
5. **注释**：为公共 API 添加注释，解释复杂逻辑

### 示例代码

```go
// Package collector provides system metrics collection functionality.
package collector

import (
    "context"
    "fmt"
    "time"
)

// Collector represents a system metrics collector.
type Collector struct {
    interval time.Duration
    logger   Logger
}

// NewCollector creates a new metrics collector with the specified interval.
func NewCollector(interval time.Duration, logger Logger) *Collector {
    return &Collector{
        interval: interval,
        logger:   logger,
    }
}

// Collect gathers system metrics and returns them.
func (c *Collector) Collect(ctx context.Context) (*Metrics, error) {
    if c.interval <= 0 {
        return nil, fmt.Errorf("invalid interval: %v", c.interval)
    }
    
    // Implementation here...
    
    return metrics, nil
}
```

## 测试指南

### 单元测试

- 为所有公共函数编写测试
- 使用表驱动测试处理多个测试用例
- 测试文件命名为 `*_test.go`
- 测试函数命名为 `TestXxx`

```go
func TestCollector_Collect(t *testing.T) {
    tests := []struct {
        name     string
        interval time.Duration
        wantErr  bool
    }{
        {
            name:     "valid interval",
            interval: time.Second,
            wantErr:  false,
        },
        {
            name:     "invalid interval",
            interval: 0,
            wantErr:  true,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            c := NewCollector(tt.interval, nil)
            _, err := c.Collect(context.Background())
            if (err != nil) != tt.wantErr {
                t.Errorf("Collect() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

### 集成测试

- 测试组件之间的交互
- 使用真实的依赖或模拟服务
- 放在 `integration_test.go` 文件中

## 文档贡献

### 文档类型

- **README.md**: 项目概述和快速开始
- **API 文档**: REST API 接口说明
- **部署文档**: 部署和配置指南
- **开发文档**: 开发环境和架构说明

### 文档规范

- 使用 Markdown 格式
- 包含代码示例
- 添加适当的图片和图表
- 保持文档与代码同步

## 发布流程

1. 更新版本号
2. 更新 CHANGELOG.md
3. 创建 Git 标签
4. 构建发布包
5. 发布到 GitHub Releases

## 社区

- **GitHub Issues**: 报告问题和功能请求
- **GitHub Discussions**: 社区讨论和问答
- **Pull Requests**: 代码贡献和审查

## 行为准则

我们致力于为每个人提供友好、安全和欢迎的环境。请遵循以下准则：

- 使用友好和包容的语言
- 尊重不同的观点和经验
- 优雅地接受建设性批评
- 关注对社区最有利的事情
- 对其他社区成员表示同理心

## 许可证

通过贡献代码，您同意您的贡献将在与项目相同的 MIT 许可证下授权。

## 问题和支持

如果您有任何问题或需要帮助，请：

1. 查看现有的 [Issues](https://github.com/WeirdStar0/server-probe/issues)
2. 搜索 [Discussions](https://github.com/WeirdStar0/server-probe/discussions)
3. 创建新的 Issue 或 Discussion

感谢您的贡献！🎉