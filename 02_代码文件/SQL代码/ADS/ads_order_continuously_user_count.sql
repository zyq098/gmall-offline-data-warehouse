-- ============================================
-- 最近7日内连续3日下单用户数
-- 粒度：天
-- 来源：dws_trade_user_order_1d
-- 核心：lead窗口函数取后两行日期，差=2就是连续3天
-- ============================================

use gmall;

DROP TABLE IF EXISTS ads_order_continuously_user_count;
CREATE EXTERNAL TABLE ads_order_continuously_user_count
(
`dt`                            STRING COMMENT '统计日期',
`recent_days`                   BIGINT COMMENT '最近天数,7:最近7天',
`order_continuously_user_count` BIGINT COMMENT '连续3日下单用户数'
) COMMENT '最近7日内连续3日下单用户数统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_order_continuously_user_count/';

insert overwrite table ads_order_continuously_user_count
select * from ads_order_continuously_user_count
union
select
    '2022-06-08' as dt,
    7 as recent_days,
    count(distinct(user_id)) as order_continuously_user_count
from
(
    select
        user_id,
        datediff(lead(dt, 2, '9999-12-31') over(partition by user_id order by dt), dt) as diff
    from dws_trade_user_order_1d
    where dt >= date_add('2022-06-08', -6)
) t1
where diff = 2;
