-- ============================================
-- ODS层增量表：订单明细表
-- 粒度：一行一个订单中的一个SKU
-- 存储格式：TextFile，按dt分区
-- ============================================

use gmall;

DROP TABLE IF EXISTS ods_order_detail_inc;
CREATE EXTERNAL TABLE ods_order_detail_inc
(
`data` STRING COMMENT '业务数据',
`type` STRING COMMENT '操作类型：insert/update/delete',
`ts` BIGINT COMMENT '时间戳'
) COMMENT '订单明细表增量数据'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_order_detail_inc/';
