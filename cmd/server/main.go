package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/WeirdStar0/server-probe/internal/server/api"
	"github.com/WeirdStar0/server-probe/internal/server/config"
	"github.com/WeirdStar0/server-probe/internal/server/storage"
	"github.com/WeirdStar0/server-probe/internal/server/websocket"
	"github.com/WeirdStar0/server-probe/internal/server/alert"
	"github.com/WeirdStar0/server-probe/internal/server/auth"
	"github.com/WeirdStar0/server-probe/pkg/logger"
)

func main() {
	// 解析命令行参数
	configFile := flag.String("config", "configs/server.json", "配置文件路径")
	version := flag.Bool("version", false, "显示版本信息")
	flag.Parse()

	if *version {
		fmt.Println("Server Probe v1.0.0")
		return
	}

	// 初始化日志
	logger.Init("info", "")

	// 加载配置
	cfg, err := config.Load(*configFile)
	if err != nil {
		log.Fatalf("加载配置失败: %v", err)
	}

	// 初始化存储
	store, err := storage.NewBoltStorage(cfg.Server.DataDir + "/data.db")
	if err != nil {
		log.Fatalf("初始化存储失败: %v", err)
	}
	defer store.Close()

	// 创建WebSocket管理器
	wsManager := websocket.NewManager()

	// 创建报警管理器
	alertManager := alert.NewManager(cfg.Alert, store)
	alertManager.Start()
	defer alertManager.Stop()

	// 初始化API服务
	apiServer := api.NewServer(cfg, store, wsManager, alertManager)

	// 初始化认证
	auth.Init(cfg.Auth.JWTSecret)

	// 启动服务
	go func() {
		if err := apiServer.Start(); err != nil {
			log.Fatalf("启动API服务失败: %v", err)
		}
	}()

	// 等待中断信号
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	<-c

	log.Println("正在关闭服务...")
	apiServer.Stop()
	log.Println("服务已关闭")
}