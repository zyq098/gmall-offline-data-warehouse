use gmall;

DROP TABLE IF EXISTS dws_trade_user_order_1d;
CREATE EXTERNAL TABLE dws_trade_user_order_1d
(
`user_id`                   STRING COMMENT '用户ID',
`order_count_1d`            BIGINT COMMENT '最近1日下单次数',
`order_num_1d`               BIGINT COMMENT '最近1日下单商品件数',
`order_original_amount_1d`  DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
`activity_reduce_amount_1d` DECIMAL(16, 2) COMMENT '最近1日下单活动优惠金额',
`coupon_reduce_amount_1d`   DECIMAL(16, 2) COMMENT '最近1日下单优惠券优惠金额',
`order_total_amount_1d`     DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
) COMMENT '交易域用户粒度订单最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_user_order_1d'
TBLPROPERTIES ('orc.compress'='snappy');

use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dws_trade_user_order_1d partition(dt)
select
    user_id,
    count(distinct order_id),          -- 下单次数
    sum(sku_num),                       -- 下单商品件数
    sum(split_original_amount),         -- 原始金额
    sum(nvl(split_activity_amount, 0)), -- 活动优惠
    sum(nvl(split_coupon_amount, 0)),  -- 优惠券优惠
    sum(split_total_amount),            -- 最终金额
    dt                                  -- 动态分区
from dwd_trade_order_detail_inc
group by user_id, dt;

insert overwrite table dws_trade_user_order_1d partition(dt='2022-06-09')
select
    user_id,
    count(distinct order_id),
    sum(sku_num),
    sum(split_original_amount),
    sum(nvl(split_activity_amount, 0)),
    sum(nvl(split_coupon_amount, 0)),
    sum(split_total_amount)
from dwd_trade_order_detail_inc
where dt='2022-06-09'
group by user_id;
