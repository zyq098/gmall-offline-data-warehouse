-- ============================================
-- 互动域商品粒度收藏最近1日汇总表
-- 粒度：商品×天
-- 来源：dwd_interaction_favor_add_inc + dim_sku_full
-- ============================================

use gmall;

-- 1. 建表语句
DROP TABLE IF EXISTS dws_interaction_sku_favor_add_1d;
CREATE EXTERNAL TABLE dws_interaction_sku_favor_add_1d
(
`sku_id`             STRING COMMENT 'SKU_ID',
`sku_name`           STRING COMMENT 'SKU名称',
`category1_id`       STRING COMMENT '一级品类ID',
`category1_name`     STRING COMMENT '一级品类名称',
`category2_id`       STRING COMMENT '二级品类ID',
`category2_name`     STRING COMMENT '二级品类名称',
`category3_id`       STRING COMMENT '三级品类ID',
`category3_name`     STRING COMMENT '三级品类名称',
`tm_id`              STRING COMMENT '品牌ID',
`tm_name`            STRING COMMENT '品牌名称',
`favor_add_count_1d` BIGINT COMMENT '商品被收藏次数'
) COMMENT '互动域商品粒度收藏商品最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_interaction_sku_favor_add_1d'
TBLPROPERTIES ('orc.compress'='snappy');

-- 2. 首日装载（动态分区）
set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dws_interaction_sku_favor_add_1d partition(dt)
select
    favor.sku_id,
    sku.sku_name,
    sku.category1_id,
    sku.category1_name,
    sku.category2_id,
    sku.category2_name,
    sku.category3_id,
    sku.category3_name,
    sku.tm_id,
    sku.tm_name,
    favor.favor_add_count,
    favor.dt
from
(
    select
        dt,
        sku_id,
        count(*) favor_add_count
    from dwd_interaction_favor_add_inc
    group by dt, sku_id
) favor
left join
(
    select
        id,
        sku_name,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        tm_id,
        tm_name
    from dim_sku_full
    where dt='2022-06-08'
) sku
on favor.sku_id = sku.id;

-- 3. 每日装载（静态分区）
insert overwrite table dws_interaction_sku_favor_add_1d partition(dt='2022-06-09')
select
    favor.sku_id,
    sku.sku_name,
    sku.category1_id,
    sku.category1_name,
    sku.category2_id,
    sku.category2_name,
    sku.category3_id,
    sku.category3_name,
    sku.tm_id,
    sku.tm_name,
    favor.favor_add_count
from
(
    select
        sku_id,
        count(*) favor_add_count
    from dwd_interaction_favor_add_inc
    where dt='2022-06-09'
    group by sku_id
) favor
left join
(
    select
        id,
        sku_name,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        tm_id,
        tm_name
    from dim_sku_full
    where dt='2022-06-09'
) sku
on favor.sku_id = sku.id;
