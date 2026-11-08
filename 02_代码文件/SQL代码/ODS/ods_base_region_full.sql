use gmall;

DROP TABLE IF EXISTS ods_base_region_full;
CREATE EXTERNAL TABLE ods_base_region_full(
`id` STRING COMMENT '地区id',
`region_name` STRING COMMENT '地区名称'
) COMMENT 'ods_base_region_full 全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_base_region_full/';