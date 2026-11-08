use gmall;

DROP TABLE IF EXISTS dwd_interaction_favor_add_inc;
CREATE EXTERNAL TABLE dwd_interaction_favor_add_inc
(
`id`          STRING COMMENT '编号',
`user_id`     STRING COMMENT '用户ID',
`sku_id`      STRING COMMENT 'SKU_ID',
`date_id`     STRING COMMENT '日期ID',
`create_time` STRING COMMENT '收藏时间'
) COMMENT '互动域收藏商品事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_interaction_favor_add_inc/'
TBLPROPERTIES ('orc.compress'='snappy');

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_interaction_favor_add_inc partition(dt)
select
    data.id,
    data.user_id,
    data.sku_id,
    date_format(data.create_time, 'yyyy-MM-dd') date_id,
    data.create_time,
    date_format(data.create_time, 'yyyy-MM-dd')   -- 动态分区
from ods_favor_info_inc
where dt = '2022-06-08'
and type = 'bootstrap-insert';

insert overwrite table dwd_interaction_favor_add_inc partition(dt='2022-06-09')
select
    data.id,
    data.user_id,
    data.sku_id,
    date_format(data.create_time, 'yyyy-MM-dd') date_id,
    data.create_time
from ods_favor_info_inc
where dt = '2022-06-09'
and type = 'insert';

