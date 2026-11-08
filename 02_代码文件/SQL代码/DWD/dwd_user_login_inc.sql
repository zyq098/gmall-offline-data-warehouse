use gmall;

DROP TABLE IF EXISTS dwd_user_login_inc;
CREATE EXTERNAL TABLE dwd_user_login_inc
(
`user_id`         STRING COMMENT '用户ID',
`date_id`         STRING COMMENT '日期ID',
`login_time`      STRING COMMENT '登录时间',
`channel`         STRING COMMENT '应用下载渠道',
`province_id`     STRING COMMENT '省份ID',
`version_code`    STRING COMMENT '应用版本',
`mid_id`          STRING COMMENT '设备ID',
`brand`           STRING COMMENT '设备品牌',
`model`           STRING COMMENT '设备型号',
`operate_system` STRING COMMENT '设备操作系统'
) COMMENT '用户域用户登录事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_user_login_inc/'
TBLPROPERTIES ('orc.compress'='snappy');

insert overwrite table dwd_user_login_inc partition (dt='2022-06-08')
select
    user_id,
    date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd') date_id,
    date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd HH:mm:ss') login_time,
    channel,
    province_id,
    version_code,
    mid_id,
    brand,
    model,
    operate_system
from (
    select
        user_id,
        channel,
        province_id,
        version_code,
        mid_id,
        brand,
        model,
        operate_system,
        ts
    from (
        select
            common.uid as user_id,
            common.ch  as channel,
            common.ar  as province_id,
            common.vc  as version_code,
            common.mid as mid_id,
            common.ba  as brand,
            common.md  as model,
            common.os  as operate_system,
            ts,
            row_number() over(partition by common.sid order by ts) as rn
        from ods_log_inc
        where dt = '2022-06-08'
        and page is not null
        and common.uid is not null
    ) t1
    where rn = 1   -- 每个会话第一条有用户ID的记录 = 登录
) t2;
