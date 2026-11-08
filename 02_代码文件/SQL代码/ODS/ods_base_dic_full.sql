use gmall;

DROP TABLE IF EXISTS ods_base_dic_full;
CREATE EXTERNAL TABLE ods_base_dic_full(
`dic_code` STRING COMMENT '字典编码',
`dic_name` STRING COMMENT '字典名称',
`parent_code` STRING COMMENT '父编码',
`create_time` STRING COMMENT '创建时间',
`operate_time` STRING COMMENT '操作时间'
) COMMENT 'ods_base_dic_full 全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_base_dic_full/';