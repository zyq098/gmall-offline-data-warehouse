-- ============================================
-- DIM层：商品SKU维度表
-- 粒度：一行一个SKU
-- 存储格式：ORC + Snappy
-- 特点：退化了品牌、品类信息，减少join
-- ============================================

use gmall;

DROP TABLE IF EXISTS dim_sku_full;
CREATE EXTERNAL TABLE dim_sku_full
(
`id` STRING COMMENT 'sku_id',
`spu_id` STRING COMMENT 'spu_id',
`price` DECIMAL(16,2) COMMENT '价格',
`sku_name` STRING COMMENT 'sku名称',
`sku_desc` STRING COMMENT '商品描述',
`weight` DECIMAL(16,2) COMMENT '重量',
`is_sale` STRING COMMENT '是否在售',
`sku_default_img` STRING COMMENT '默认图片',
`category1_id` STRING COMMENT '一级品类id',
`category1_name` STRING COMMENT '一级品类名称',
`category2_id` STRING COMMENT '二级品类id',
`category2_name` STRING COMMENT '二级品类名称',
`category3_id` STRING COMMENT '三级品类id',
`category3_name` STRING COMMENT '三级品类名称',
`tm_id` STRING COMMENT '品牌id',
`tm_name` STRING COMMENT '品牌名称'
) COMMENT '商品SKU维度表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dim/dim_sku_full/';
