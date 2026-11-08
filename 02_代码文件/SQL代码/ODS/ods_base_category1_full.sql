use gmall;

DROP TABLE IF EXISTS ods_base_category1_full;
CREATE EXTERNAL TABLE ods_base_category1_full(
`id` STRING COMMENT '一级品类id',
`name` STRING COMMENT '一级品类名称'
) COMMENT 'ods_base_category1_full 全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_base_category1_full/';