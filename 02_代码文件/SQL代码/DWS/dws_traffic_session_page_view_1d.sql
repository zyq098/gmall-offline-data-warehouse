-- ============================================
-- 流量域会话粒度页面浏览最近1日汇总表
-- 粒度：会话×天
-- 来源：dwd_traffic_page_view_inc
-- ============================================

use gmall;

-- 1. 建表语句
DROP TABLE IF EXISTS dws_traffic_session_page_view_1d;
CREATE EXTERNAL TABLE dws_traffic_session_page_view_1d
(
`session_id`     STRING COMMENT '会话ID',
`mid_id`         STRING COMMENT '设备ID',
`brand`          STRING COMMENT '手机品牌',
`model`          STRING COMMENT '手机型号',
`operate_system` STRING COMMENT '操作系统',
`version_code`   STRING COMMENT 'APP版本号',
`channel`        STRING COMMENT '渠道',
`during_time_1d` BIGINT COMMENT '最近1日浏览时长',
`page_count_1d`  BIGINT COMMENT '最近1日浏览页面数'
) COMMENT '流量域会话粒度页面浏览最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_traffic_session_page_view_1d'
TBLPROPERTIES ('orc.compress'='snappy');

-- 2. 装载SQL（首日=每日，流量表不需要区分首日每日）
insert overwrite table dws_traffic_session_page_view_1d partition(dt='2022-06-08')
select
    session_id,
    mid_id,
    brand,
    model,
    operate_system,
    version_code,
    channel,
    sum(during_time),
    count(*)
from dwd_traffic_page_view_inc
where dt='2022-06-08'
group by session_id, mid_id, brand, model, operate_system, version_code, channel;
