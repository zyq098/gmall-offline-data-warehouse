-- ============================================
-- 各品类购物车存量Top3
-- 粒度：品类×SKU
-- 来源：dwd_trade_cart_full + dim_sku_full
-- 核心：rank() over(partition by 品类 order by 加购数 desc) 取前3
-- ============================================

use gmall;

set hive.mapjoin.optimized.hashtable=false;

DROP TABLE IF EXISTS ads_sku_cart_num_top3_by_cate;
CREATE EXTERNAL TABLE ads_sku_cart_num_top3_by_cate
(
`dt`             STRING COMMENT '统计日期',
`category1_id`   STRING COMMENT '一级品类ID',
`category1_name` STRING COMMENT '一级品类名称',
`category2_id`   STRING COMMENT '二级品类ID',
`category2_name` STRING COMMENT '二级品类名称',
`category3_id`   STRING COMMENT '三级品类ID',
`category3_name` STRING COMMENT '三级品类名称',
`sku_id`         STRING COMMENT 'SKU_ID',
`sku_name`       STRING COMMENT 'SKU名称',
`cart_num`       BIGINT COMMENT '购物车中商品数量',
`rk`             BIGINT COMMENT '排名'
) COMMENT '各品类商品购物车存量Top3'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_sku_cart_num_top3_by_cate/';

insert overwrite table ads_sku_cart_num_top3_by_cate
select * from ads_sku_cart_num_top3_by_cate
union
select
    '2022-06-08' dt,
    category1_id, category1_name,
    category2_id, category2_name,
    category3_id, category3_name,
    sku_id, sku_name,
    cart_num, rk
from
(
    select
        sku_id, sku_name,
        category1_id, category1_name,
        category2_id, category2_name,
        category3_id, category3_name,
        cart_num,
        rank() over(partition by category3_id order by cart_num desc) as rk
    from
    (
        select sku_id, sum(sku_num) as cart_num
        from dwd_trade_cart_full
        where dt='2022-06-08'
        group by sku_id
    ) cart
    left join
    (
        select id, sku_name,
            category1_id, category1_name,
            category2_id, category2_name,
            category3_id, category3_name
        from dim_sku_full
        where dt='2022-06-08'
    ) sku on cart.sku_id = sku.id
) t1
where rk <= 3;

set hive.mapjoin.optimized.hashtable=true;
