-- ============================================
-- 交易域用户粒度支付最近1日汇总表
-- 粒度：用户×天
-- 来源：dwd_trade_pay_detail_suc_inc
-- ============================================

use gmall;

-- 1. 建表语句
DROP TABLE IF EXISTS dws_trade_user_payment_1d;
CREATE EXTERNAL TABLE dws_trade_user_payment_1d
(
`user_id`           STRING COMMENT '用户ID',
`payment_count_1d`  BIGINT COMMENT '最近1日支付次数',
`payment_num_1d`    BIGINT COMMENT '最近1日支付商品件数',
`payment_amount_1d` DECIMAL(16, 2) COMMENT '最近1日支付金额'
) COMMENT '交易域用户粒度支付最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_user_payment_1d'
TBLPROPERTIES ('orc.compress'='snappy');

-- 2. 首日装载（动态分区）
set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dws_trade_user_payment_1d partition(dt)
select
    user_id,
    count(distinct order_id),
    sum(sku_num),
    sum(split_payment_amount),
    dt
from dwd_trade_pay_detail_suc_inc
group by user_id, dt;

-- 3. 每日装载（静态分区）
insert overwrite table dws_trade_user_payment_1d partition(dt='2022-06-09')
select
    user_id,
    count(distinct order_id),
    sum(sku_num),
    sum(split_payment_amount)
from dwd_trade_pay_detail_suc_inc
where dt='2022-06-09'
group by user_id;
