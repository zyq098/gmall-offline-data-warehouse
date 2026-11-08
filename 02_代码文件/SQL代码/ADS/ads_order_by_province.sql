-- ============================================
-- 各省份交易统计
-- 粒度：省份×统计周期
-- 来源：dws_trade_province_order_1d + dws_trade_province_order_nd
-- ============================================

use gmall;

DROP TABLE IF EXISTS ads_order_by_province;
CREATE EXTERNAL TABLE ads_order_by_province
(
`dt`                 STRING COMMENT '统计日期',
`recent_days`        BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
`province_id`        STRING COMMENT '省份ID',
`province_name`      STRING COMMENT '省份名称',
`area_code`          STRING COMMENT '地区编码',
`iso_code`           STRING COMMENT '旧版国际标准地区编码',
`iso_code_3166_2`    STRING COMMENT '新版国际标准地区编码',
`order_count`        BIGINT COMMENT '订单数',
`order_total_amount` DECIMAL(16, 2) COMMENT '订单金额'
) COMMENT '各省份交易统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_order_by_province/';

insert overwrite table ads_order_by_province
select * from ads_order_by_province
union
select
    '2022-06-08' dt,
    1 as recent_days,
    province_id, province_name,
    area_code, iso_code, iso_3166_2,
    order_count_1d,
    order_total_amount_1d
from dws_trade_province_order_1d
where dt='2022-06-08'

union

select
    '2022-06-08' dt,
    recent_days,
    province_id, province_name,
    area_code, iso_code, iso_3166_2,
    if(recent_days=7, order_count_7d, order_count_30d) as order_count,
    if(recent_days=7, order_total_amount_7d, order_total_amount_30d) as order_total_amount
from dws_trade_province_order_nd
lateral view explode(array(7,30)) tmp as recent_days
where dt='2022-06-08';
