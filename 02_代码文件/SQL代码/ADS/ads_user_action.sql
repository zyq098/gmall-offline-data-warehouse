-- ============================================
-- 用户行为漏斗分析
-- 粒度：天
-- 来源：dws_traffic_page_visitor_page_view_1d + dws_trade_user_cart_add_1d + dws_trade_user_order_1d + dws_trade_user_payment_1d
-- 指标：首页→详情→加购→下单→支付 各阶段人数
-- ============================================

use gmall;

DROP TABLE IF EXISTS ads_user_action;
CREATE EXTERNAL TABLE ads_user_action
(
`dt`                STRING COMMENT '统计日期',
`home_count`        BIGINT COMMENT '浏览首页人数',
`good_detail_count` BIGINT COMMENT '浏览商品详情页人数',
`cart_count`        BIGINT COMMENT '加购人数',
`order_count`       BIGINT COMMENT '下单人数',
`payment_count`     BIGINT COMMENT '支付人数'
) COMMENT '用户行为漏斗分析'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_user_action/';

insert overwrite table ads_user_action
select * from ads_user_action
union
select
    '2022-06-08' dt,
    home_count,
    good_detail_count,
    cart_count,
    order_count,
    payment_count
from
(
    select
        1 as recent_days,
        sum(if(page_id='home', 1, 0)) as home_count,
        sum(if(page_id='good_detail', 1, 0)) as good_detail_count
    from dws_traffic_page_visitor_page_view_1d
    where dt='2022-06-08'
      and page_id in ('home', 'good_detail')
) page
join
(
    select 1 as recent_days, count(*) as cart_count
    from dws_trade_user_cart_add_1d
    where dt='2022-06-08'
) cart on page.recent_days = cart.recent_days
join
(
    select 1 as recent_days, count(*) as order_count
    from dws_trade_user_order_1d
    where dt='2022-06-08'
) ord on page.recent_days = ord.recent_days
join
(
    select 1 as recent_days, count(*) as payment_count
    from dws_trade_user_payment_1d
    where dt='2022-06-08'
) pay on page.recent_days = pay.recent_days;
