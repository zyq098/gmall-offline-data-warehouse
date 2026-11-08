use gmall;

DROP TABLE IF EXISTS dwd_traffic_page_view_inc;
CREATE EXTERNAL TABLE dwd_traffic_page_view_inc
(
`province_id`    STRING COMMENT '省份ID',
`brand`          STRING COMMENT '手机品牌',
`channel`        STRING COMMENT '渠道',
`is_new`         STRING COMMENT '是否首次启动',
`model`          STRING COMMENT '手机型号',
`mid_id`         STRING COMMENT '设备ID',
`operate_system` STRING COMMENT '操作系统',
`user_id`        STRING COMMENT '会员ID',
`version_code`   STRING COMMENT 'APP版本号',
`page_item`      STRING COMMENT '目标ID',
`page_item_type` STRING COMMENT '目标类型',
`last_page_id`   STRING COMMENT '上页ID',
`page_id`        STRING COMMENT '页面ID',
`from_pos_id`    STRING COMMENT '点击坑位ID',
`from_pos_seq`   STRING COMMENT '点击坑位位置',
`refer_id`       STRING COMMENT '营销渠道ID',
`date_id`        STRING COMMENT '日期ID',
`view_time`      STRING COMMENT '跳入时间',
`session_id`     STRING COMMENT '所属会话ID',
`during_time`    BIGINT COMMENT '持续时间毫秒'
) COMMENT '流量域页面浏览事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_traffic_page_view_inc/'
TBLPROPERTIES ('orc.compress'='snappy');

use gmall;

set hive.cbo.enable=false;

insert overwrite table dwd_traffic_page_view_inc partition (dt='2022-06-08')
select
    common.ar  as province_id,
    common.ba  as brand,
    common.ch  as channel,
    common.is_new as is_new,
    common.md  as model,
    common.mid as mid_id,
    common.os  as operate_system,
    common.uid as user_id,
    common.vc  as version_code,
    page.item  as page_item,
    page.item_type as page_item_type,
    page.last_page_id as last_page_id,
    page.page_id as page_id,
    page.from_pos_id as from_pos_id,
    page.from_pos_seq as from_pos_seq,
    page.refer_id as refer_id,
    date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd') date_id,
    date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd HH:mm:ss') view_time,
    common.sid as session_id,
    cast(page.during_time as bigint) as during_time
from ods_log_inc
where dt = '2022-06-08'
and page is not null;   -- 只取页面日志，排除启动日志

set hive.cbo.enable=true;
