-- ============================================
-- 工具域用户优惠券粒度使用最近1日汇总表
-- 粒度：用户×优惠券×天
-- 来源：dwd_tool_coupon_used_inc + dim_coupon_full
-- ============================================

use gmall;

-- 1. 建表语句
DROP TABLE IF EXISTS dws_tool_user_coupon_coupon_used_1d;
CREATE EXTERNAL TABLE dws_tool_user_coupon_coupon_used_1d
(
`user_id`          STRING COMMENT '用户ID',
`coupon_id`        STRING COMMENT '优惠券ID',
`coupon_name`      STRING COMMENT '优惠券名称',
`coupon_type_code` STRING COMMENT '优惠券类型编码',
`coupon_type_name` STRING COMMENT '优惠券类型名称',
`benefit_rule`     STRING COMMENT '优惠规则',
`used_count_1d`    STRING COMMENT '使用(支付)次数'
) COMMENT '工具域用户优惠券粒度优惠券使用(支付)最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_tool_user_coupon_coupon_used_1d'
TBLPROPERTIES ('orc.compress'='snappy');

-- 2. 首日装载（动态分区）
set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dws_tool_user_coupon_coupon_used_1d partition(dt)
select
    t1.user_id,
    t1.coupon_id,
    t2.coupon_name,
    t2.coupon_type_code,
    t2.coupon_type_name,
    t2.benefit_rule,
    t1.used_count,
    t1.dt
from
(
    select
        dt,
        user_id,
        coupon_id,
        count(*) used_count
    from dwd_tool_coupon_used_inc
    group by dt, user_id, coupon_id
) t1
left join
(
    select
        id,
        coupon_name,
        coupon_type_code,
        coupon_type_name,
        benefit_rule
    from dim_coupon_full
    where dt='2022-06-08'
) t2
on t1.coupon_id = t2.id;

-- 3. 每日装载（静态分区）
insert overwrite table dws_tool_user_coupon_coupon_used_1d partition(dt='2022-06-09')
select
    t1.user_id,
    t1.coupon_id,
    t2.coupon_name,
    t2.coupon_type_code,
    t2.coupon_type_name,
    t2.benefit_rule,
    t1.used_count
from
(
    select
        user_id,
        coupon_id,
        count(*) used_count
    from dwd_tool_coupon_used_inc
    where dt='2022-06-09'
    group by user_id, coupon_id
) t1
left join
(
    select
        id,
        coupon_name,
        coupon_type_code,
        coupon_type_name,
        benefit_rule
    from dim_coupon_full
    where dt='2022-06-09'
) t2
on t1.coupon_id = t2.id;
