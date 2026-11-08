-- ============================================
-- 新增下单用户统计
-- 粒度：统计周期
-- 来源：dws_trade_user_order_td
-- 特点：lateral view explode炸裂，一次算1/7/30天
-- ============================================

use gmall;

DROP TABLE IF EXISTS ads_new_order_user_stats;
CREATE EXTERNAL TABLE ads_new_order_user_stats
(
`dt`                   STRING COMMENT '统计日期',
`recent_days`          BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
`new_order_user_count` BIGINT COMMENT '新增下单人数'
) COMMENT '新增下单用户统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_new_order_user_stats/';

insert overwrite table ads_new_order_user_stats
select * from ads_new_order_user_stats
union
select
    '2022-06-08' dt,
    recent_days,
    count(*) as new_order_user_count
from dws_trade_user_order_td
lateral view explode(array(1,7,30)) tmp as recent_days
where dt='2022-06-08'
  and order_date_first >= date_add('2022-06-08', -recent_days + 1)
group by recent_days;
