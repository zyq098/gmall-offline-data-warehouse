-- ============================================
-- 用户变动统计
-- 粒度：天
-- 来源：dws_user_user_login_td
-- 指标：流失用户数（连续7天没登录）、回流用户数（流失后又回来）
-- ============================================

use gmall;

-- 1. 建表语句
DROP TABLE IF EXISTS ads_user_change;
CREATE EXTERNAL TABLE ads_user_change
(
`dt`               STRING COMMENT '统计日期',
`user_churn_count` BIGINT COMMENT '流失用户数',
`user_back_count`  BIGINT COMMENT '回流用户数'
) COMMENT '用户变动统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_user_change/';

-- 2. 装载SQL
insert overwrite table ads_user_change
select * from ads_user_change
union
select
    churn.dt,
    user_churn_count,
    user_back_count
from
(
    -- 流失用户：刚好7天前没登录的
    select '2022-06-08' dt, count(*) user_churn_count
    from dws_user_user_login_td
    where dt='2022-06-08'
      and login_date_last = date_add('2022-06-08', -7)
) churn
join
(
    -- 回流用户：今天登录了，但之前至少8天没登录
    select '2022-06-08' dt, count(*) user_back_count
    from
    (
        -- 今天登录了的用户
        select user_id, login_date_last
        from dws_user_user_login_td
        where dt='2022-06-08'
          and login_date_last = '2022-06-08'
    ) t1
    join
    (
        -- 昨天记录的这些用户的上次登录日期
        select user_id, login_date_last as login_date_previous
        from dws_user_user_login_td
        where dt = date_add('2022-06-08', -1)
    ) t2
    on t1.user_id = t2.user_id
    -- 间隔8天以上才算回流
    where datediff(login_date_last, login_date_previous) >= 8
) back
on churn.dt = back.dt;
