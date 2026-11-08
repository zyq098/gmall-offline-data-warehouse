-- ============================================
-- 优惠券使用统计
-- 粒度：优惠券
-- 来源：dws_tool_user_coupon_coupon_used_1d
-- ============================================

use gmall;

DROP TABLE IF EXISTS ads_coupon_stats;
CREATE EXTERNAL TABLE ads_coupon_stats
(
`dt`              STRING COMMENT '统计日期',
`coupon_id`       STRING COMMENT '优惠券ID',
`coupon_name`     STRING COMMENT '优惠券名称',
`used_count`      BIGINT COMMENT '使用次数',
`used_user_count` BIGINT COMMENT '使用人数'
) COMMENT '优惠券使用统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_coupon_stats/';

insert overwrite table ads_coupon_stats
select * from ads_coupon_stats
union
select
    '2022-06-08' dt,
    coupon_id,
    coupon_name,
    cast(sum(used_count_1d) as bigint) as used_count,
    cast(count(*) as bigint) as used_user_count
from dws_tool_user_coupon_coupon_used_1d
where dt='2022-06-08'
group by coupon_id, coupon_name;
