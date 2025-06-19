package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/WeirdStar0/server-probe/internal/agent/collector"
	"github.com/WeirdStar0/server-probe/internal/agent/reporter"
	"github.com/WeirdStar0/server-probe/pkg/logger"
)

func main() {
	// 解析命令行参数
	serverURL := flag.String("server", "ws://localhost:2111/ws", "服务器WebSocket地址")
	interval := flag.Int("interval", 30, "数据采集间隔（秒）")
	debug := flag.Bool("debug", false, "启用调试模式")
	version := flag.Bool("version", false, "显示版本信息")
	flag.Parse()

	if *version {
		fmt.Println("Server Probe Agent v1.0.0")
		return
	}

	// 初始化日志
	logLevel := "info"
	if *debug {
		logLevel = "debug"
	}
	logger.Init(logLevel, "")

	// 获取主机信息
	hostInfo, err := collector.GetHostInfo()
	if err != nil {
		log.Fatalf("获取主机信息失败: %v", err)
	}

	log.Printf("主机信息: %s (%s)", hostInfo.Hostname, hostInfo.OS)

	// 创建数据采集器
	collector := collector.New()

	// 创建数据上报器
	reporter := reporter.New(*serverURL, hostInfo)

	// 启动数据上报器
	if err := reporter.Start(); err != nil {
		log.Fatalf("启动数据上报器失败: %v", err)
	}
	defer reporter.Stop()

	// 启动数据采集循环
	ticker := time.NewTicker(time.Duration(*interval) * time.Second)
	defer ticker.Stop()

	go func() {
		for {
			select {
			case <-ticker.C:
				// 采集系统数据
				data, err := collector.Collect()
				if err != nil {
					log.Printf("数据采集失败: %v", err)
					continue
				}

				// 上报数据
				if err := reporter.Report(data); err != nil {
					log.Printf("数据上报失败: %v", err)
				}
			}
		}
	}()

	// 等待中断信号
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	<-c

	log.Println("正在关闭客户端...")
	log.Println("客户端已关闭")
}