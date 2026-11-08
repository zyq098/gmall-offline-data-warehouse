-- ============================================
-- 各品类商品下单统计
-- 粒度：三级品类×统计周期
-- 来源：dws_trade_user_sku_order_1d + dws_trade_user_sku_order_nd
-- ============================================

use gmall;

DROP TABLE IF EXISTS ads_order_stats_by_cate;
CREATE EXTERNAL TABLE ads_order_stats_by_cate
(
`dt`                      STRING COMMENT '统计日期',
`recent_days`             BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
`category1_id`            STRING COMMENT '一级品类ID',
`category1_name`          STRING COMMENT '一级品类名称',
`category2_id`            STRING COMMENT '二级品类ID',
`category2_name`          STRING COMMENT '二级品类名称',
`category3_id`            STRING COMMENT '三级品类ID',
`category3_name`          STRING COMMENT '三级品类名称',
`order_count`             BIGINT COMMENT '下单数',
`order_user_count`        BIGINT COMMENT '下单人数'
) COMMENT '各品类商品下单统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_order_stats_by_cate/';

insert overwrite table ads_order_stats_by_cate
select * from ads_order_stats_by_cate
union
select
    '2022-06-08' dt,
    recent_days,
    category1_id, category1_name,
    category2_id, category2_name,
    category3_id, category3_name,
    order_count, order_user_count
from
(
    select
        1 as recent_days,
        category1_id, category1_name,
        category2_id, category2_name,
        category3_id, category3_name,
        sum(order_count_1d) as order_count,
        count(distinct(user_id)) as order_user_count
    from dws_trade_user_sku_order_1d
    where dt='2022-06-08'
    group by category1_id, category1_name, category2_id, category2_name, category3_id, category3_name

    union all

    select
        recent_days,
        category1_id, category1_name,
        category2_id, category2_name,
        category3_id, category3_name,
        sum(order_count) as order_count,
        count(distinct(if(order_count>0, user_id, null))) as order_user_count
    from
    (
        select
            recent_days,
            user_id,
            category1_id, category1_name,
            category2_id, category2_name,
            category3_id, category3_name,
            if(recent_days=7, order_count_7d, order_count_30d) as order_count
        from dws_trade_user_sku_order_nd
        lateral view explode(array(7,30)) tmp as recent_days
        where dt='2022-06-08'
    ) t1
    group by recent_days, category1_id, category1_name, category2_id, category2_name, category3_id, category3_name
) t2;
