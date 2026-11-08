use gmall;

DROP TABLE IF EXISTS dwd_trade_trade_flow_acc;
CREATE EXTERNAL TABLE dwd_trade_trade_flow_acc
(
`order_id`               STRING COMMENT '订单ID',
`user_id`                STRING COMMENT '用户ID',
`province_id`           STRING COMMENT '省份ID',
`order_date_id`         STRING COMMENT '下单日期ID',
`order_time`             STRING COMMENT '下单时间',
`payment_date_id`        STRING COMMENT '支付日期ID',
`payment_time`           STRING COMMENT '支付时间',
`finish_date_id`         STRING COMMENT '确认收货日期ID',
`finish_time`             STRING COMMENT '确认收货时间',
`order_original_amount` DECIMAL(16, 2) COMMENT '下单原始价格',
`order_activity_amount` DECIMAL(16, 2) COMMENT '下单活动优惠分摊',
`order_coupon_amount`   DECIMAL(16, 2) COMMENT '下单优惠券优惠分摊',
`order_total_amount`    DECIMAL(16, 2) COMMENT '下单最终价格分摊',
`payment_amount`         DECIMAL(16, 2) COMMENT '支付金额'
) COMMENT '交易域交易流程累积快照事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_trade_trade_flow_acc/'
TBLPROPERTIES ('orc.compress'='snappy');

use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_trade_trade_flow_acc partition(dt)
select
    oi.id,
    oi.user_id,
    oi.province_id,
    date_format(oi.create_time, 'yyyy-MM-dd'),
    oi.create_time,
    date_format(pi.callback_time, 'yyyy-MM-dd'),
    pi.callback_time,
    date_format(log.finish_time, 'yyyy-MM-dd'),
    log.finish_time,
    oi.original_total_amount,
    oi.activity_reduce_amount,
    oi.coupon_reduce_amount,
    oi.total_amount,
    nvl(pi.payment_amount, 0.0),
    -- 收货时间不为null说明流程结束，进收货日期分区；否则进9999
    nvl(date_format(log.finish_time, 'yyyy-MM-dd'), '9999-12-31')
from
(
    select
    data.id,
    data.user_id,
    data.province_id,
    data.create_time,
    data.original_total_amount,
    data.activity_reduce_amount,
    data.coupon_reduce_amount,
    data.total_amount
    from ods_order_info_inc
    where dt='2022-06-08'
    and type='bootstrap-insert'
) oi
left join
(
    select
    data.order_id,
    data.callback_time,
    data.total_amount payment_amount
    from ods_payment_info_inc
    where dt='2022-06-08'
    and type='bootstrap-insert'
    and data.payment_status='1602'
) pi
on oi.id=pi.order_id
left join
(
    select
    data.order_id,
    data.create_time finish_time
    from ods_order_status_log_inc
    where dt='2022-06-08'
    and type='bootstrap-insert'
    and data.order_status='1004'
) log
on oi.id=log.order_id;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_trade_trade_flow_acc partition(dt)
select
    oi.order_id,
    oi.user_id,
    oi.province_id,
    oi.order_date_id,
    oi.order_time,
    -- 历史数据已有支付时间就取历史的，没有就取今天新支付的
    nvl(oi.payment_date_id, pi.payment_date_id),
    nvl(oi.payment_time, pi.payment_time),
    nvl(oi.finish_date_id, log.finish_date_id),
    nvl(oi.finish_time, log.finish_time),
    oi.order_original_amount,
    oi.order_activity_amount,
    oi.order_coupon_amount,
    oi.order_total_amount,
    nvl(oi.payment_amount, pi.payment_amount),
    -- 今天收货了就进今天分区，否则还在9999
    nvl(nvl(oi.finish_time, log.finish_time), '9999-12-31')
from
(
    -- ① 昨天未完成的订单（9999分区）
    select
    order_id,
    user_id,
    province_id,
    order_date_id,
    order_time,
    payment_date_id,
    payment_time,
    finish_date_id,
    finish_time,
    order_original_amount,
    order_activity_amount,
    order_coupon_amount,
    order_total_amount,
    payment_amount
    from dwd_trade_trade_flow_acc
    where dt='9999-12-31'

    union all

    -- ② 今天新下单的订单
    select
    data.id,
    data.user_id,
    data.province_id,
    date_format(data.create_time, 'yyyy-MM-dd'),
    data.create_time,
    null, null, null, null,
    data.original_total_amount,
    data.activity_reduce_amount,
    data.coupon_reduce_amount,
    data.total_amount,
    null
    from ods_order_info_inc
    where dt='2022-06-09'
    and type='insert'
) oi
left join
(
    -- 今天新支付成功的订单
    select
    data.order_id,
    date_format(data.callback_time, 'yyyy-MM-dd') payment_date_id,
    data.callback_time payment_time,
    data.total_amount payment_amount
    from ods_payment_info_inc
    where dt='2022-06-09'
    and type='update'
    and array_contains(map_keys(old), 'payment_status')
    and data.payment_status='1602'
) pi
on oi.order_id=pi.order_id
left join
(
    -- 今天确认收货的订单
    select
    data.order_id,
    date_format(data.create_time, 'yyyy-MM-dd') finish_date_id,
    data.create_time finish_time
    from ods_order_status_log_inc
    where dt='2022-06-09'
    and type='insert'
    and data.order_status='1004'
) log
on oi.order_id=log.order_id;
