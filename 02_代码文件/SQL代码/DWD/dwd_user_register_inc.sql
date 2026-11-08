use gmall;

DROP TABLE IF EXISTS dwd_user_register_inc;
CREATE EXTERNAL TABLE dwd_user_register_inc
(
`user_id`       STRING COMMENT '用户ID',
`date_id`       STRING COMMENT '日期ID',
`create_time`   STRING COMMENT '注册时间',
`channel`       STRING COMMENT '应用下载渠道',
`province_id`   STRING COMMENT '省份ID',
`version_code`  STRING COMMENT '应用版本',
`mid_id`        STRING COMMENT '设备ID',
`brand`         STRING COMMENT '设备品牌',
`model`         STRING COMMENT '设备型号',
`operate_system` STRING COMMENT '设备操作系统'
) COMMENT '用户域用户注册事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_user_register_inc/'
TBLPROPERTIES ('orc.compress'='snappy');

use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_user_register_inc partition (dt)
select
    ui.user_id,
    date_format(ui.create_time, 'yyyy-MM-dd') date_id,
    ui.create_time,
    log.channel,
    log.province_id,
    log.version_code,
    log.mid_id,
    log.brand,
    log.model,
    log.operate_system,
    date_format(ui.create_time, 'yyyy-MM-dd')   -- 动态分区字段
from
(
    select
        data.id as user_id,
        data.create_time
    from ods_user_info_inc
    where dt = '2022-06-08'
    and type = 'bootstrap-insert'
) ui
left join
(
    select
        common.ar as province_id,
        common.ba as brand,
        common.ch as channel,
        common.md as model,
        common.mid as mid_id,
        common.os as operate_system,
        common.uid as user_id,
        common.vc as version_code
    from ods_log_inc
    where dt = '2022-06-08'
    and page.page_id = 'register'
    and common.uid is not null
) log
on ui.user_id = log.user_id;

use gmall;

insert overwrite table dwd_user_register_inc partition(dt='2022-06-09')
select
    ui.user_id,
    date_format(ui.create_time, 'yyyy-MM-dd') date_id,
    ui.create_time,
    log.channel,
    log.province_id,
    log.version_code,
    log.mid_id,
    log.brand,
    log.model,
    log.operate_system
from
(
    select
        data.id as user_id,
        data.create_time
    from ods_user_info_inc
    where dt = '2022-06-09'
    and type = 'insert'
) ui
left join
(
    select
        common.ar as province_id,
        common.ba as brand,
        common.ch as channel,
        common.md as model,
        common.mid as mid_id,
        common.os as operate_system,
        common.uid as user_id,
        common.vc as version_code
    from ods_log_inc
    where dt = '2022-06-09'
    and page.page_id = 'register'
    and common.uid is not null
) log
on ui.user_id = log.user_id;
