use gmall;

DROP TABLE IF EXISTS ods_base_province_full;
CREATE EXTERNAL TABLE ods_base_province_full(
`id` STRING COMMENT '省份id',
`name` STRING COMMENT '省份名称',
`region_id` STRING COMMENT '地区id',
`area_code` STRING COMMENT '地区编码',
`iso_code` STRING COMMENT '旧版编码',
`iso_3166_2` STRING COMMENT '新版编码'
) COMMENT 'ods_base_province_full 全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_base_province_full/';