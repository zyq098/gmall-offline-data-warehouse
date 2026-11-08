-- ============================================
-- DIM层：地区维度表
-- 粒度：一行一个省份
-- 存储格式：ORC + Snappy
-- ============================================

use gmall;

DROP TABLE IF EXISTS dim_province_full;
CREATE EXTERNAL TABLE dim_province_full
(
`id` STRING COMMENT '省份id',
`province_name` STRING COMMENT '省份名称',
`area_code` STRING COMMENT '地区编码',
`iso_code` STRING COMMENT '旧版国际标准地区编码',
`iso_3166_2` STRING COMMENT '新版国际标准地区编码'
) COMMENT '地区维度表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dim/dim_province_full/';
