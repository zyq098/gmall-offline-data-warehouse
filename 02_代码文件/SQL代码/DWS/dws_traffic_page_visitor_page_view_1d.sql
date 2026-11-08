-- ============================================
-- 流量域访客页面粒度页面浏览最近1日汇总表
-- 粒度：访客×页面×天
-- 来源：dwd_traffic_page_view_inc
-- ============================================

use gmall;

-- 1. 建表语句
DROP TABLE IF EXISTS dws_traffic_page_visitor_page_view_1d;
CREATE EXTERNAL TABLE dws_traffic_page_visitor_page_view_1d
(
`mid_id`         STRING COMMENT '访客ID',
`brand`          STRING COMMENT '手机品牌',
`model`          STRING COMMENT '手机型号',
`operate_system` STRING COMMENT '操作系统',
`page_id`        STRING COMMENT '页面ID',
`during_time_1d` BIGINT COMMENT '最近1日浏览时长',
`view_count_1d`  BIGINT COMMENT '最近1日访问次数'
) COMMENT '流量域访客页面粒度页面浏览最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_traffic_page_visitor_page_view_1d'
TBLPROPERTIES ('orc.compress'='snappy');

-- 2. 装载SQL（首日=每日）
insert overwrite table dws_traffic_page_visitor_page_view_1d partition(dt='2022-06-08')
select
    mid_id,
    brand,
    model,
    operate_system,
    page_id,
    sum(during_time),
    count(*)
from dwd_traffic_page_view_inc
where dt='2022-06-08'
group by mid_id, brand, model, operate_system, page_id;
