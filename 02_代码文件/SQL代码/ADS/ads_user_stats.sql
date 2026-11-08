-- ============================================
-- 用户新增活跃统计
-- 粒度：统计周期
-- 来源：dws_user_user_login_td
-- 特点：lateral view explode炸裂，一次算1/7/30天
-- ============================================

use gmall;

DROP TABLE IF EXISTS ads_user_stats;
CREATE EXTERNAL TABLE ads_user_stats
(
`dt`                STRING COMMENT '统计日期',
`recent_days`       BIGINT COMMENT '最近n日,1:最近1日,7:最近7日,30:最近30日',
`new_user_count`    BIGINT COMMENT '新增用户数',
`active_user_count` BIGINT COMMENT '活跃用户数'
) COMMENT '用户新增活跃统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_user_stats/';

insert overwrite table ads_user_stats
select * from ads_user_stats
union
select
    '2022-06-08' dt,
    recent_days,
    sum(if(login_date_first >= date_add('2022-06-08', -recent_days + 1), 1, 0)) as new_user_count,
    count(*) as active_user_count
from dws_user_user_login_td
lateral view explode(array(1, 7, 30)) tmp as recent_days
where dt = '2022-06-08'
  and login_date_last >= date_add('2022-06-08', -recent_days + 1)
group by recent_days;
