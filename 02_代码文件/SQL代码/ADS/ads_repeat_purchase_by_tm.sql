-- ============================================
-- 各品牌复购率
-- 粒度：品牌
-- 来源：dws_trade_user_sku_order_nd
-- 复购率 = 下单>=2次的用户数 / 下单>=1次的用户数
-- ============================================

use gmall;

DROP TABLE IF EXISTS ads_repeat_purchase_by_tm;
CREATE EXTERNAL TABLE ads_repeat_purchase_by_tm
(
`dt`                  STRING COMMENT '统计日期',
`recent_days`         BIGINT COMMENT '最近天数,30:最近30天',
`tm_id`               STRING COMMENT '品牌ID',
`tm_name`             STRING COMMENT '品牌名称',
`order_repeat_rate`   DECIMAL(16, 2) COMMENT '复购率'
) COMMENT '最近30日各品牌复购率统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_repeat_purchase_by_tm/';

insert overwrite table ads_repeat_purchase_by_tm
select * from ads_repeat_purchase_by_tm
union
select
    '2022-06-08' as dt,
    30 as recent_days,
    tm_id,
    tm_name,
    cast(sum(if(order_count>=2, 1, 0)) / sum(if(order_count>=1, 1, 0)) as decimal(16, 2)) as order_repeat_rate
from
(
    select
        user_id,
        tm_id,
        tm_name,
        sum(order_count_30d) as order_count
    from dws_trade_user_sku_order_nd
    where dt='2022-06-08'
    group by user_id, tm_id, tm_name
) t1
group by tm_id, tm_name;
