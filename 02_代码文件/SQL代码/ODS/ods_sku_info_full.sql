-- ============================================
-- ODS层全量表：商品SKU表
-- 粒度：一行一个SKU
-- 存储格式：TextFile，按dt分区
-- ============================================

use gmall;

DROP TABLE IF EXISTS ods_sku_info_full;
CREATE EXTERNAL TABLE ods_sku_info_full
(
`id` STRING COMMENT 'sku_id',
`spu_id` STRING COMMENT 'spu_id',
`price` DECIMAL(16,2) COMMENT '价格',
`sku_name` STRING COMMENT 'sku名称',
`sku_desc` STRING COMMENT '商品描述',
`weight` DECIMAL(16,2) COMMENT '重量',
`tm_id` STRING COMMENT '品牌id',
`category3_id` STRING COMMENT '三级品类id',
`sku_default_img` STRING COMMENT '默认图片',
`is_sale` STRING COMMENT '是否在售',
`create_time` STRING COMMENT '创建时间',
`operate_time` STRING COMMENT '修改时间'
) COMMENT '商品SKU表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_sku_info_full/';
