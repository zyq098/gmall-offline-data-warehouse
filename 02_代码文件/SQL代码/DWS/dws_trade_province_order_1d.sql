-- ============================================
-- 交易域省份粒度订单最近1日汇总表
-- 粒度：省份×天
-- 来源：dwd_trade_order_detail_inc + dim_province_full
-- ============================================

use gmall;

-- 1. 建表语句
DROP TABLE IF EXISTS dws_trade_province_order_1d;
CREATE EXTERNAL TABLE dws_trade_province_order_1d
(
`province_id`               STRING COMMENT '省份ID',
`province_name`             STRING COMMENT '省份名称',
`area_code`                 STRING COMMENT '地区编码',
`iso_code`                  STRING COMMENT '旧版国际标准地区编码',
`iso_3166_2`                STRING COMMENT '新版国际标准地区编码',
`order_count_1d`            BIGINT COMMENT '最近1日下单次数',
`order_original_amount_1d`  DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
`activity_reduce_amount_1d` DECIMAL(16, 2) COMMENT '最近1日下单活动优惠金额',
`coupon_reduce_amount_1d`   DECIMAL(16, 2) COMMENT '最近1日下单优惠券优惠金额',
`order_total_amount_1d`     DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
) COMMENT '交易域省份粒度订单最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_province_order_1d'
TBLPROPERTIES ('orc.compress'='snappy');

-- 2. 首日装载（动态分区）
set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dws_trade_province_order_1d partition(dt)
select
    o.province_id,
    p.province_name,
    p.area_code,
    p.iso_code,
    p.iso_3166_2,
    o.order_count_1d,
    o.order_original_amount_1d,
    o.activity_reduce_amount_1d,
    o.coupon_reduce_amount_1d,
    o.order_total_amount_1d,
    o.dt
from
(
    select
        province_id,
        count(distinct order_id) order_count_1d,
        sum(split_original_amount) order_original_amount_1d,
        sum(nvl(split_activity_amount, 0)) activity_reduce_amount_1d,
        sum(nvl(split_coupon_amount, 0)) coupon_reduce_amount_1d,
        sum(split_total_amount) order_total_amount_1d,
        dt
    from dwd_trade_order_detail_inc
    group by province_id, dt
) o
left join
(
    select
        id,
        province_name,
        area_code,
        iso_code,
        iso_3166_2
    from dim_province_full
    where dt='2022-06-08'
) p
on o.province_id = p.id;

-- 3. 每日装载（静态分区）
insert overwrite table dws_trade_province_order_1d partition(dt='2022-06-09')
select
    o.province_id,
    p.province_name,
    p.area_code,
    p.iso_code,
    p.iso_3166_2,
    o.order_count_1d,
    o.order_original_amount_1d,
    o.activity_reduce_amount_1d,
    o.coupon_reduce_amount_1d,
    o.order_total_amount_1d
from
(
    select
        province_id,
        count(distinct order_id) order_count_1d,
        sum(split_original_amount) order_original_amount_1d,
        sum(nvl(split_activity_amount, 0)) activity_reduce_amount_1d,
        sum(nvl(split_coupon_amount, 0)) coupon_reduce_amount_1d,
        sum(split_total_amount) order_total_amount_1d
    from dwd_trade_order_detail_inc
    where dt='2022-06-09'
    group by province_id
) o
left join
(
    select
        id,
        province_name,
        area_code,
        iso_code,
        iso_3166_2
    from dim_province_full
    where dt='2022-06-09'
) p
on o.province_id = p.id;
