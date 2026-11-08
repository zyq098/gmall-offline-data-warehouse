use gmall;

DROP TABLE IF EXISTS ods_base_category2_full;
CREATE EXTERNAL TABLE ods_base_category2_full(
`id` STRING COMMENT '二级品类id',
`name` STRING COMMENT '二级品类名称',
`category1_id` STRING COMMENT '一级品类id'
) COMMENT 'ods_base_category2_full 全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_base_category2_full/';