#!/bin/bash
# 伪分布式日常启动脚本（只启动写SQL需要的服务）

echo "==================== 启动 HDFS ===================="
start-dfs.sh

echo "==================== 启动 YARN ===================="
start-yarn.sh

echo "==================== 启动 Hive Metastore【必须先启动！】 ===================="
nohup hive --service metastore > /opt/module/hive/logs/metastore.log 2>&1 &
sleep 3   # 等metastore初始化，不然hs2抢着启动连不上

echo "==================== 启动 HiveServer2 (DataGrip连接用) ===================="
nohup hiveserver2 > /opt/module/hive/logs/hiveserver2.log 2>&1 &

echo ""
echo "==================== 启动完成，当前进程：===================="
jps
echo -e "\n提示：hiveserver2、metastore 在jps中显示为 RunJar！"
echo "查看hs2日志：tail -f /opt/module/hive/logs/hiveserver2.log"
echo "查看metastore日志：tail -f /opt/module/hive/logs/metastore.log"
