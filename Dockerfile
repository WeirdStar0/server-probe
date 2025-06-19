# 用于构建服务器探针系统的Docker镜像

# 构建阶段
FROM golang:1.20-alpine AS builder

# 设置工作目录
WORKDIR /app

# 安装必要的工具
RUN apk add --no-cache git make

# 复制go.mod和go.sum
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 复制源代码
COPY . .

# 获取版本信息
ARG VERSION=v1.0.0
ARG BUILD_TIME
ARG GIT_COMMIT=unknown

# 设置构建参数
ENV LDFLAGS="-X 'github.com/WeirdStar0/server-probe/pkg/version.Version=${VERSION}' \
            -X 'github.com/WeirdStar0/server-probe/pkg/version.BuildTime=${BUILD_TIME}' \
            -X 'github.com/WeirdStar0/server-probe/pkg/version.GitCommit=${GIT_COMMIT}'"

# 构建服务端
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags "${LDFLAGS}" -a -installsuffix cgo -o server-probe-server ./cmd/server

# 构建客户端
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags "${LDFLAGS}" -a -installsuffix cgo -o server-probe-agent ./cmd/agent

# 运行阶段 - 服务端
FROM alpine:latest AS server

# 安装必要的包
RUN apk --no-cache add ca-certificates tzdata

# 设置时区
ENV TZ=Asia/Shanghai

# 创建非root用户
RUN addgroup -g 1000 appgroup && \
    adduser -D -s /bin/sh -u 1000 -G appgroup appuser

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/server-probe-server .

# 创建配置和数据目录
RUN mkdir -p configs data logs && \
    chown -R appuser:appgroup /app

# 复制默认配置文件
COPY configs/server.json configs/

# 切换到非root用户
USER appuser

# 暴露端口
EXPOSE 8080

# 设置健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/health || exit 1

# 启动命令
CMD ["./server-probe-server", "-config", "configs/server.json"]

# 运行阶段 - 客户端
FROM alpine:latest AS agent

# 安装必要的包
RUN apk --no-cache add ca-certificates tzdata

# 设置时区
ENV TZ=Asia/Shanghai

# 创建非root用户
RUN addgroup -g 1000 appgroup && \
    adduser -D -s /bin/sh -u 1000 -G appgroup appuser

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/server-probe-agent .

# 创建日志目录
RUN mkdir -p logs && \
    chown -R appuser:appgroup /app

# 切换到非root用户
USER appuser

# 设置环境变量
ENV SERVER_URL=ws://server:8080/ws
ENV INTERVAL=30
ENV DEBUG=false

# 启动命令
CMD ["sh", "-c", "./server-probe-agent -server ${SERVER_URL} -interval ${INTERVAL} -debug ${DEBUG}"]