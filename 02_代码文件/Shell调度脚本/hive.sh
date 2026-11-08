#!/bin/bash

# Hive 服务管理脚本
# 用法: hive.sh start|stop|status

HIVE_HOME=/opt/module/hive

if [ $# -lt 1 ]; then
    echo "Usage: $0 {start|stop|status}"
    exit 1
fi

case $1 in
"start")
    echo "==================== 启动 Hive 服务 ===================="

    echo "---------- 启动 Metastore ----------"
    nohup $HIVE_HOME/bin/hive --service metastore > /dev/null 2>&1 &
    sleep 3
    echo "Metastore 启动完成"

    echo "---------- 启动 HiveServer2 ----------"
    nohup $HIVE_HOME/bin/hiveserver2 > /dev/null 2>&1 &
    sleep 5
    echo "HiveServer2 启动完成"

    echo "==================== Hive 服务启动完成 ===================="
;;

"stop")
    echo "==================== 停止 Hive 服务 ===================="

    echo "---------- 停止 HiveServer2 ----------"
    jps | grep RunJar | awk '{print $1}' | xargs kill -9 2>/dev/null

    echo "==================== Hive 服务停止完成 ===================="
;;

"status")
    echo "==================== Hive 服务状态 ===================="

    echo "---------- Metastore 状态 ----------"
    metastore_pid=$(netstat -tlnp | grep 9083 | awk '{print $7}' | cut -d'/' -f1)
    if [ -n "$metastore_pid" ]; then
        echo "Metastore 运行中 (PID: $metastore_pid)"
    else
        echo "Metastore 未运行"
    fi

    echo "---------- HiveServer2 状态 ----------"
    hiveserver2_pid=$(netstat -tlnp | grep 10000 | awk '{print $7}' | cut -d'/' -f1)
    if [ -n "$hiveserver2_pid" ]; then
        echo "HiveServer2 运行中 (PID: $hiveserver2_pid)"
    else
        echo "HiveServer2 未运行"
    fi

    echo "---------- RunJar 进程 ----------"
    jps | grep RunJar

    echo "==================== 状态查询完成 ===================="
;;

*)
    echo "Usage: $0 {start|stop|status}"
    exit 1
;;
esac
