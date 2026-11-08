use gmall;

DROP TABLE IF EXISTS dim_category_full;
CREATE EXTERNAL TABLE dim_category_full(
`category1_id` STRING,
`category1_name` STRING,
`category2_id` STRING,
`category2_name` STRING,
`category3_id` STRING,
`category3_name` STRING
) COMMENT '品类维度表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dim/dim_category_full/';
