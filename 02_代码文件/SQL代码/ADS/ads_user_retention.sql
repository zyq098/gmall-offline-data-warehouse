use gmall;

DROP TABLE IF EXISTS ads_user_retention;
CREATE EXTERNAL TABLE ads_user_retention
(
`dt`              STRING COMMENT '统计日期',
`create_date`     STRING COMMENT '用户新增日期',
`retention_day`   INT COMMENT '截至当前日期留存天数',
`retention_count` BIGINT COMMENT '留存用户数量',
`new_user_count`  BIGINT COMMENT '新增用户数量',
`retention_rate`  DECIMAL(16, 2) COMMENT '留存率'
) COMMENT '用户留存率'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_user_retention/';

-- 数据加载
insert overwrite table ads_user_retention
select
*
from ads_user_retention
union
select
'2022-06-08' as dt,
login_date_first as create_date,
datediff('2022-06-08', login_date_first) as retention_day,
sum(if(login_date_last='2022-06-08',1,0)) as retention_count,
count(*) as new_user_count,
cast(sum(if(login_date_last = '2022-06-08', 1, 0)) / count(*) * 100 as decimal(16, 2)) as retention_rate
from (
select
user_id,login_date_last,login_date_first
from dws_user_user_login_td
where dt='2022-06-08' and login_date_first>=date_add('2022-06-08',-7) and login_date_first<'2022-06-08')
group by login_date_first