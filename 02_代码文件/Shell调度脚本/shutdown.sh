#!/bin/bash

# 集群安全关机脚本
# 用法: shutdown.sh stop
# 在 hadoop102 上执行，自动停止服务并关闭三台机器

if [ $# -lt 1 ]; then
    echo "Usage: $0 stop"
    exit 1
fi

case $1 in
"stop")
    echo "==================== 开始安全关闭集群 ===================="

    echo "---------- 停止 Hive 服务 ----------"
    jps | grep RunJar | awk '{print $1}' | xargs kill -9 2>/dev/null
    echo "Hive 服务已停止"

    echo "---------- 停止 Hadoop 服务 ----------"
    hdp.sh stop
    echo "Hadoop 服务已停止"

    echo "---------- 关闭集群节点 ----------"
    echo "关闭 hadoop104..."
    ssh hadoop104 "sudo shutdown -h now"

    echo "关闭 hadoop103..."
    ssh hadoop103 "sudo shutdown -h now"

    echo "关闭 hadoop102..."
    sudo shutdown -h now

    echo "==================== 集群关闭完成 ===================="
;;

*)
    echo "Usage: $0 stop"
    exit 1
;;
esac
