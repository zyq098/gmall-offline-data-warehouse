use gmall;

DROP TABLE IF EXISTS dws_trade_user_order_td;
CREATE EXTERNAL TABLE dws_trade_user_order_td
(
`user_id`                   STRING COMMENT '用户ID',
`order_date_first`          STRING COMMENT '历史至今首次下单日期',
`order_date_last`           STRING COMMENT '历史至今末次下单日期',
`order_count_td`            BIGINT COMMENT '历史至今下单次数',
`order_num_td`              BIGINT COMMENT '历史至今购买商品件数',
`original_amount_td`        DECIMAL(16, 2) COMMENT '历史至今下单原始金额',
`activity_reduce_amount_td` DECIMAL(16, 2) COMMENT '历史至今下单活动优惠金额',
`coupon_reduce_amount_td`   DECIMAL(16, 2) COMMENT '历史至今下单优惠券优惠金额',
`total_amount_td`           DECIMAL(16, 2) COMMENT '历史至今下单最终金额'
) COMMENT '交易域用户粒度订单历史至今汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_user_order_td'
TBLPROPERTIES ('orc.compress'='snappy');
insert overwrite table dws_trade_user_order_td partition(dt='2022-06-08')
select
    user_id,
    min(dt) order_date_first,
    max(dt) order_date_last,
    sum(order_count_1d) order_count_td,
    sum(order_num_1d) order_num_td,
    sum(order_original_amount_1d) original_amount_td,
    sum(activity_reduce_amount_1d) activity_reduce_amount_td,
    sum(coupon_reduce_amount_1d) coupon_reduce_amount_td,
    sum(order_total_amount_1d) total_amount_td
from dws_trade_user_order_1d
group by user_id;
insert overwrite table dws_trade_user_order_td partition(dt='2022-06-09')
select
    user_id,
    min(order_date_first) order_date_first,
    max(order_date_last) order_date_last,
    sum(order_count_td) order_count_td,
    sum(order_num_td) order_num_td,
    sum(original_amount_td) original_amount_td,
    sum(activity_reduce_amount_td) activity_reduce_amount_td,
    sum(coupon_reduce_amount_td) coupon_reduce_amount_td,
    sum(total_amount_td) total_amount_td
from (
    -- 昨天的累计数据
    select
        user_id,
        order_date_first,
        order_date_last,
        order_count_td,
        order_num_td,
        original_amount_td,
        activity_reduce_amount_td,
        coupon_reduce_amount_td,
        total_amount_td
    from dws_trade_user_order_td
    where dt = date_add('2022-06-09', -1)

    union all

    -- 今天的新数据
    select
        user_id,
        '2022-06-09' order_date_first,
        '2022-06-09' order_date_last,
        order_count_1d,
        order_num_1d,
        order_original_amount_1d,
        activity_reduce_amount_1d,
        coupon_reduce_amount_1d,
        order_total_amount_1d
    from dws_trade_user_order_1d
    where dt = '2022-06-09'
) t1
group by user_id;
