use gmall;

DROP TABLE IF EXISTS ods_comment_info_inc;
CREATE EXTERNAL TABLE ods_comment_info_inc(
`data` STRING COMMENT '业务数据JSON',
`type` STRING COMMENT '操作类型: insert/update/delete/bootstrap-insert',
`ts` BIGINT COMMENT 'binlog时间戳'
) COMMENT 'ods_comment_info_inc 增量数据'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_comment_info_inc/';