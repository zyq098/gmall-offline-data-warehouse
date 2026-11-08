-- ============================================
-- 各品牌商品收藏次数Top3
-- 粒度：品牌×SKU
-- 来源：dws_interaction_sku_favor_add_1d
-- 核心：rank() over(partition by 品牌 order by 收藏数 desc) 取前3
-- ============================================

use gmall;

DROP TABLE IF EXISTS ads_sku_favor_count_top3_by_tm;
CREATE EXTERNAL TABLE ads_sku_favor_count_top3_by_tm
(
`dt`          STRING COMMENT '统计日期',
`tm_id`       STRING COMMENT '品牌ID',
`tm_name`     STRING COMMENT '品牌名称',
`sku_id`      STRING COMMENT 'SKU_ID',
`sku_name`    STRING COMMENT 'SKU名称',
`favor_count` BIGINT COMMENT '被收藏次数',
`rk`          BIGINT COMMENT '排名'
) COMMENT '各品牌商品收藏次数Top3'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_sku_favor_count_top3_by_tm/';

insert overwrite table ads_sku_favor_count_top3_by_tm
select * from ads_sku_favor_count_top3_by_tm
union
select
    '2022-06-08' dt,
    tm_id, tm_name,
    sku_id, sku_name,
    favor_add_count_1d as favor_count,
    rk
from
(
    select
        tm_id, tm_name,
        sku_id, sku_name,
        favor_add_count_1d,
        rank() over(partition by tm_id order by favor_add_count_1d desc) as rk
    from dws_interaction_sku_favor_add_1d
    where dt='2022-06-08'
) t1
where rk <= 3;
