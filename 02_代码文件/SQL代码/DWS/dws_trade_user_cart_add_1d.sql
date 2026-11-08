use gmall;

DROP TABLE IF EXISTS dws_trade_user_cart_add_1d;
CREATE EXTERNAL TABLE dws_trade_user_cart_add_1d
(
`user_id`           STRING COMMENT '用户ID',
`cart_add_count_1d` BIGINT COMMENT '最近1日加购次数',
`cart_add_num_1d`   BIGINT COMMENT '最近1日加购商品件数'
) COMMENT '交易域用户粒度加购最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_user_cart_add_1d'
TBLPROPERTIES ('orc.compress'='snappy');
set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dws_trade_user_cart_add_1d partition(dt)
select
    user_id,
    count(*),           -- 加购次数
    sum(sku_num),       -- 加购商品件数
    dt
from dwd_trade_cart_add_inc
group by user_id, dt;
insert overwrite table dws_trade_user_cart_add_1d partition(dt='2022-06-09')
select
    user_id,
    count(*),
    sum(sku_num)
from dwd_trade_cart_add_inc
where dt='2022-06-09'
group by user_id;
