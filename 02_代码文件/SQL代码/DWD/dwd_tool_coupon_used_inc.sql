use gmall;

DROP TABLE IF EXISTS dwd_tool_coupon_used_inc;
CREATE EXTERNAL TABLE dwd_tool_coupon_used_inc
(
`id`           STRING COMMENT '编号',
`coupon_id`    STRING COMMENT '优惠券ID',
`user_id`      STRING COMMENT '用户ID',
`order_id`     STRING COMMENT '订单ID',
`date_id`      STRING COMMENT '日期ID',
`payment_time` STRING COMMENT '使用(支付)时间'
) COMMENT '工具域优惠券使用（支付）事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_tool_coupon_used_inc/'
TBLPROPERTIES ('orc.compress'='snappy');

use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_tool_coupon_used_inc partition(dt)
select
    data.id,
    data.coupon_id,
    data.user_id,
    data.order_id,
    date_format(data.used_time, 'yyyy-MM-dd') date_id,
    data.used_time,
    date_format(data.used_time, 'yyyy-MM-dd')   -- 动态分区
from ods_coupon_use_inc
where dt = '2022-06-08'
and type = 'bootstrap-insert'
and data.used_time is not null;   -- 只取已使用的优惠券


insert overwrite table dwd_tool_coupon_used_inc partition(dt='2022-06-09')
select
    data.id,
    data.coupon_id,
    data.user_id,
    data.order_id,
    date_format(data.used_time, 'yyyy-MM-dd') date_id,
    data.used_time
from ods_coupon_use_inc
where dt = '2022-06-09'
and type = 'update'
and array_contains(map_keys(old), 'used_time');   -- 确认这次update改的是使用时间



