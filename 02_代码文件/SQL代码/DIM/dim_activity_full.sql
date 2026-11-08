use gmall;

DROP TABLE IF EXISTS dim_activity_full;
CREATE EXTERNAL TABLE dim_activity_full(
`activity_id` STRING,
`activity_name` STRING,
`activity_type` STRING,
`start_time` STRING,
`end_time` STRING,
`rule_desc` STRING
) COMMENT '活动维度表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dim/dim_activity_full/';
