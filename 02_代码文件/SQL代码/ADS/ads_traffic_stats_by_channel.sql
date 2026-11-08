-- ============================================
-- 各渠道流量统计
-- 粒度：渠道×统计周期
-- 来源：dws_traffic_session_page_view_1d
-- 特点：lateral view explode炸裂，一次算1/7/30天三个周期
-- ============================================

use gmall;

-- 1. 建表语句（TextFile行存，方便导出MySQL）
DROP TABLE IF EXISTS ads_traffic_stats_by_channel;
CREATE EXTERNAL TABLE ads_traffic_stats_by_channel
(
`dt`               STRING COMMENT '统计日期',
`recent_days`      BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
`channel`          STRING COMMENT '渠道',
`uv_count`         BIGINT COMMENT '访客人数',
`avg_duration_sec` BIGINT COMMENT '会话平均停留时长，单位为秒',
`avg_page_count`   BIGINT COMMENT '会话平均浏览页面数',
`sv_count`         BIGINT COMMENT '会话数',
`bounce_rate`      DECIMAL(16, 2) COMMENT '跳出率'
) COMMENT '各渠道流量统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_traffic_stats_by_channel/';

-- 2. 装载SQL
insert overwrite table ads_traffic_stats_by_channel
select * from ads_traffic_stats_by_channel   -- 历史数据
union                                          -- 加今天新算的数据
select
    '2022-06-08' dt,
    recent_days,
    channel,
    cast(count(distinct(mid_id)) as bigint) as uv_count,
    cast(avg(during_time_1d)/1000 as bigint) as avg_duration_sec,
    cast(avg(page_count_1d) as bigint) as avg_page_count,
    cast(count(*) as bigint) as sv_count,
    cast(sum(if(page_count_1d=1, 1, 0))/count(*) as decimal(16,2)) as bounce_rate
from dws_traffic_session_page_view_1d
lateral view explode(array(1,7,30)) tmp as recent_days   -- 炸裂成3行
where dt >= date_add('2022-06-08', -recent_days + 1)
group by recent_days, channel;
