-- ============================================
-- DWD层：订单主表
-- 粒度：一行一个订单
-- 事实表类型：事务事实表（只增不改）
-- 存储格式：ORC + Snappy，按dt分区
-- ============================================

use gmall;

DROP TABLE IF EXISTS dwd_trade_order_inc;
CREATE EXTERNAL TABLE dwd_trade_order_inc
(
`order_id` STRING COMMENT '订单id',
`user_id` STRING COMMENT '用户id',
`province_id` STRING COMMENT '省份id',
`order_status` STRING COMMENT '订单状态',
`total_amount` DECIMAL(16,2) COMMENT '订单总金额',
`activity_reduce_amount` DECIMAL(16,2) COMMENT '活动优惠金额',
`coupon_reduce_amount` DECIMAL(16,2) COMMENT '优惠券优惠金额',
`original_total_amount` DECIMAL(16,2) COMMENT '原始总金额',
`freight_fee` DECIMAL(16,2) COMMENT '运费',
`create_time` STRING COMMENT '创建时间',
`operate_time` STRING COMMENT '操作时间'
) COMMENT '订单主表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_trade_order_inc/';
