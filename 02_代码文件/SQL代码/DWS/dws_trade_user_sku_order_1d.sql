-- ============================================
-- 交易域用户+商品粒度订单最近1日汇总表
-- 粒度：用户×商品×天
-- 来源：dwd_trade_order_detail_inc + dim_sku_full
-- ============================================

use gmall;

-- 1. 建表语句
DROP TABLE IF EXISTS dws_trade_user_sku_order_1d;
CREATE EXTERNAL TABLE dws_trade_user_sku_order_1d
(
`user_id`                   STRING COMMENT '用户ID',
`sku_id`                    STRING COMMENT 'SKU_ID',
`sku_name`                  STRING COMMENT 'SKU名称',
`category1_id`              STRING COMMENT '一级品类ID',
`category1_name`            STRING COMMENT '一级品类名称',
`category2_id`              STRING COMMENT '二级品类ID',
`category2_name`            STRING COMMENT '二级品类名称',
`category3_id`              STRING COMMENT '三级品类ID',
`category3_name`            STRING COMMENT '三级品类名称',
`tm_id`                      STRING COMMENT '品牌ID',
`tm_name`                    STRING COMMENT '品牌名称',
`order_count_1d`            BIGINT COMMENT '最近1日下单次数',
`order_num_1d`              BIGINT COMMENT '最近1日下单件数',
`order_original_amount_1d`  DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
`activity_reduce_amount_1d` DECIMAL(16, 2) COMMENT '最近1日活动优惠金额',
`coupon_reduce_amount_1d`   DECIMAL(16, 2) COMMENT '最近1日优惠券优惠金额',
`order_total_amount_1d`     DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
) COMMENT '交易域用户商品粒度订单最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_user_sku_order_1d'
TBLPROPERTIES ('orc.compress'='snappy');

-- 2. 首日装载（动态分区）
set hive.exec.dynamic.partition.mode=nonstrict;
-- Hive bug：关矢量化查询避免报错
set hive.vectorized.execution.enabled = false;

insert overwrite table dws_trade_user_sku_order_1d partition(dt)
select
    od.user_id,
    sku.id,
    sku.sku_name,
    sku.category1_id,
    sku.category1_name,
    sku.category2_id,
    sku.category2_name,
    sku.category3_id,
    sku.category3_name,
    sku.tm_id,
    sku.tm_name,
    od.order_count_1d,
    od.order_num_1d,
    od.order_original_amount_1d,
    od.activity_reduce_amount_1d,
    od.coupon_reduce_amount_1d,
    od.order_total_amount_1d,
    od.dt
from
(
    select
        dt,
        user_id,
        sku_id,
        count(*) order_count_1d,
        sum(sku_num) order_num_1d,
        sum(split_original_amount) order_original_amount_1d,
        sum(nvl(split_activity_amount, 0.0)) activity_reduce_amount_1d,
        sum(nvl(split_coupon_amount, 0.0)) coupon_reduce_amount_1d,
        sum(split_total_amount) order_total_amount_1d
    from dwd_trade_order_detail_inc
    group by dt, user_id, sku_id
) od
left join
(
    select
        id,
        sku_name,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        tm_id,
        tm_name
    from dim_sku_full
    where dt='2022-06-08'
) sku
on od.sku_id = sku.id;

set hive.vectorized.execution.enabled = true;

-- 3. 每日装载（静态分区）
set hive.vectorized.execution.enabled = false;

insert overwrite table dws_trade_user_sku_order_1d partition(dt='2022-06-09')
select
    od.user_id,
    sku.id,
    sku.sku_name,
    sku.category1_id,
    sku.category1_name,
    sku.category2_id,
    sku.category2_name,
    sku.category3_id,
    sku.category3_name,
    sku.tm_id,
    sku.tm_name,
    od.order_count,
    od.order_num,
    od.order_original_amount,
    od.activity_reduce_amount,
    od.coupon_reduce_amount,
    od.order_total_amount
from
(
    select
        user_id,
        sku_id,
        count(*) order_count,
        sum(sku_num) order_num,
        sum(split_original_amount) order_original_amount,
        sum(nvl(split_activity_amount, 0)) activity_reduce_amount,
        sum(nvl(split_coupon_amount, 0)) coupon_reduce_amount,
        sum(split_total_amount) order_total_amount
    from dwd_trade_order_detail_inc
    where dt='2022-06-09'
    group by user_id, sku_id
) od
left join
(
    select
        id,
        sku_name,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        tm_id,
        tm_name
    from dim_sku_full
    where dt='2022-06-09'
) sku
on od.sku_id = sku.id;

set hive.vectorized.execution.enabled = true;
