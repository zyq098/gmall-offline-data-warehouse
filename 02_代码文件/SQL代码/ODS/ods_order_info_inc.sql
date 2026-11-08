-- ============================================
-- ODS层增量表：订单表
-- 粒度：一行一个订单
-- 存储格式：TextFile，按dt分区
-- 采集方式：Maxwell监听binlog
-- ============================================

use gmall;

DROP TABLE IF EXISTS ods_order_info_inc;
CREATE EXTERNAL TABLE ods_order_info_inc
(
`data` STRING COMMENT '业务数据',
`type` STRING COMMENT '操作类型：insert/update/delete',
`ts` BIGINT COMMENT '时间戳'
) COMMENT '订单表增量数据'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_order_info_inc/';
