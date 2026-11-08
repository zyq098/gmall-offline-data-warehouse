use gmall;

DROP TABLE IF EXISTS ods_spu_info_full;
CREATE EXTERNAL TABLE ods_spu_info_full(
`id` STRING COMMENT 'spu_id',
`spu_name` STRING COMMENT 'spu名称',
`description` STRING COMMENT '描述',
`category3_id` STRING COMMENT '三级品类id',
`tm_id` STRING COMMENT '品牌id'
) COMMENT 'ods_spu_info_full 全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_spu_info_full/';