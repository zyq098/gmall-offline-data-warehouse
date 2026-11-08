use gmall;

DROP TABLE IF EXISTS dwd_trade_cart_add_inc;
CREATE EXTERNAL TABLE dwd_trade_cart_add_inc
(
`id`          STRING COMMENT '编号',
`user_id`     STRING COMMENT '用户ID',
`sku_id`      STRING COMMENT 'SKU_ID',
`date_id`     STRING COMMENT '日期ID',
`create_time` STRING COMMENT '加购时间',
`sku_num`     BIGINT COMMENT '加购物车件数'
) COMMENT '交易域加购事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_trade_cart_add_inc/'
TBLPROPERTIES ('orc.compress'='snappy');

use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_trade_cart_add_inc partition (dt)
select
    data.id,
    data.user_id,
    data.sku_id,
    date_format(data.create_time, 'yyyy-MM-dd') date_id,
    data.create_time,
    data.sku_num,
    date_format(data.create_time, 'yyyy-MM-dd')
from ods_cart_info_inc
where dt = '2022-06-08'
and type = 'bootstrap-insert';

insert overwrite table dwd_trade_cart_add_inc partition (dt='2022-06-09')
select
    data.id,
    data.user_id,
    data.sku_id,
    date_format(from_utc_timestamp(ts * 1000, 'GMT+8'), 'yyyy-MM-dd') date_id,
    date_format(from_utc_timestamp(ts * 1000, 'GMT+8'), 'yyyy-MM-dd HH:mm:ss') create_time,
    -- insert直接取数量；update算差值（新数量-旧数量=本次加购数）
    if(type = 'insert', data.sku_num, cast(data.sku_num as int) - cast(old['sku_num'] as int)) sku_num
from ods_cart_info_inc
where dt = '2022-06-09'
and (type = 'insert'
     or (type = 'update' and old['sku_num'] is not null and cast(data.sku_num as int) > cast(old['sku_num'] as int)));
