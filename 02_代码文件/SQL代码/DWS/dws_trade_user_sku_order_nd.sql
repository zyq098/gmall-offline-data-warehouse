use gmall;

DROP TABLE IF EXISTS dws_trade_user_sku_order_nd;
CREATE EXTERNAL TABLE dws_trade_user_sku_order_nd
(
`user_id`                     STRING COMMENT '用户ID',
`sku_id`                      STRING COMMENT 'SKU_ID',
`sku_name`                    STRING COMMENT 'SKU名称',
`category1_id`               STRING COMMENT '一级品类ID',
`category1_name`             STRING COMMENT '一级品类名称',
`category2_id`               STRING COMMENT '二级品类ID',
`category2_name`             STRING COMMENT '二级品类名称',
`category3_id`               STRING COMMENT '三级品类ID',
`category3_name`             STRING COMMENT '三级品类名称',
`tm_id`                       STRING COMMENT '品牌ID',
`tm_name`                     STRING COMMENT '品牌名称',
`order_count_7d`             STRING COMMENT '最近7日下单次数',
`order_num_7d`               BIGINT COMMENT '最近7日下单件数',
`order_original_amount_7d`   DECIMAL(16, 2) COMMENT '最近7日下单原始金额',
`activity_reduce_amount_7d`  DECIMAL(16, 2) COMMENT '最近7日活动优惠金额',
`coupon_reduce_amount_7d`    DECIMAL(16, 2) COMMENT '最近7日优惠券优惠金额',
`order_total_amount_7d`      DECIMAL(16, 2) COMMENT '最近7日下单最终金额',
`order_count_30d`            BIGINT COMMENT '最近30日下单次数',
`order_num_30d`              BIGINT COMMENT '最近30日下单件数',
`order_original_amount_30d`  DECIMAL(16, 2) COMMENT '最近30日下单原始金额',
`activity_reduce_amount_30d` DECIMAL(16, 2) COMMENT '最近30日活动优惠金额',
`coupon_reduce_amount_30d`   DECIMAL(16, 2) COMMENT '最近30日优惠券优惠金额',
`order_total_amount_30d`     DECIMAL(16, 2) COMMENT '最近30日下单最终金额'
) COMMENT '交易域用户商品粒度订单最近n日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_user_sku_order_nd'
TBLPROPERTIES ('orc.compress'='snappy');
insert overwrite table dws_trade_user_sku_order_nd partition(dt='2022-06-08')
select
    user_id,
    sku_id,
    sku_name,
    category1_id,
    category1_name,
    category2_id,
    category2_name,
    category3_id,
    category3_name,
    tm_id,
    tm_name,
    -- 最近7日指标：只加最近7天的
    sum(if(dt >= date_add('2022-06-08', -6), order_count_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), order_num_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), order_original_amount_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), activity_reduce_amount_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), coupon_reduce_amount_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), order_total_amount_1d, 0)),
    -- 最近30日指标：全部加（因为where已经筛了最近30天）
    sum(order_count_1d),
    sum(order_num_1d),
    sum(order_original_amount_1d),
    sum(activity_reduce_amount_1d),
    sum(coupon_reduce_amount_1d),
    sum(order_total_amount_1d)
from dws_trade_user_sku_order_1d
where dt >= date_add('2022-06-08', -29)
group by user_id, sku_id, sku_name, category1_id, category1_name,
         category2_id, category2_name, category3_id, category3_name, tm_id, tm_name;
