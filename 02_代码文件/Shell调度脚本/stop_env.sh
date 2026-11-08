#!/bin/bash
# 伪分布式日常关闭脚本（与 start_env.sh 配套，逆序停止服务）

echo "==================== 停止 HiveServer2 ===================="
# 查找 HiveServer2 进程 PID
HS2_PID=$(ps -ef | grep -w "hiveserver2" | grep -v grep | awk '{print $2}')

if [ -n "$HS2_PID" ]; then
    echo "检测到进程 PID: $HS2_PID，正在优雅停止..."
    kill "$HS2_PID"
    # 等待 3 秒让其正常退出
    sleep 3
    # 二次检查：若仍存活则强制终止
    if ps -p "$HS2_PID" > /dev/null; then
        echo "进程未正常退出，执行强制终止..."
        kill -9 "$HS2_PID"
    fi
    echo "HiveServer2 已停止"
else
    echo "HiveServer2 未在运行，跳过"
fi

echo ""
echo "==================== 停止 YARN ===================="
stop-yarn.sh

echo ""
echo "==================== 停止 HDFS ===================="
stop-dfs.sh

echo ""
echo "==================== 停止完成，当前剩余进程：===================="
jps
