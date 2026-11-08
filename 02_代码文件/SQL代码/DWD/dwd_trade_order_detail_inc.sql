-- ============================================
-- DWD层：订单明细表
-- 粒度：一行一个订单中的一个SKU
-- 事实表类型：事务事实表
-- 存储格式：ORC + Snappy，按dt分区
-- 特点：维度退化，带上品类、品牌信息
-- ============================================

use gmall;

DROP TABLE IF EXISTS dwd_trade_order_detail_inc;
CREATE EXTERNAL TABLE dwd_trade_order_detail_inc
(
`id` STRING COMMENT '订单明细id',
`order_id` STRING COMMENT '订单id',
`user_id` STRING COMMENT '用户id',
`sku_id` STRING COMMENT '商品id',
`sku_name` STRING COMMENT '商品名称',
`sku_num` BIGINT COMMENT '购买数量',
`order_price` DECIMAL(16,2) COMMENT '下单时单价',
`split_total_amount` DECIMAL(16,2) COMMENT '分摊总金额',
`split_activity_amount` DECIMAL(16,2) COMMENT '分摊活动金额',
`split_coupon_amount` DECIMAL(16,2) COMMENT '分摊优惠券金额',
`create_time` STRING COMMENT '创建时间'
) COMMENT '订单明细表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_trade_order_detail_inc/';
