use gmall;

DROP TABLE IF EXISTS dws_user_user_login_td;
CREATE EXTERNAL TABLE dws_user_user_login_td
(
`user_id`          STRING COMMENT '用户ID',
`login_date_last`  STRING COMMENT '历史至今末次登录日期',
`login_date_first` STRING COMMENT '历史至今首次登录日期',
`login_count_td`   BIGINT COMMENT '历史至今累计登录次数'
) COMMENT '用户域用户粒度登录历史至今汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_user_user_login_td'
TBLPROPERTIES ('orc.compress'='snappy');
-- 首日加载
insert overwrite table dws_user_user_login_td partition(dt='2022-06-08')
SELECT
t.id AS user_id,
nvl(login_date_last,date_format(t.create_time,'yyyy-MM-dd')) AS login_date_last,
date_format(t.create_time,'yyyy-MM-dd') AS login_date_first,
nvl(m.login_count_td,1) AS login_count_td
FROM (SELECT id,
             create_time
      FROM dim_user_zip
      WHERE dt = '9999-12-31') t
LEFT JOIN
(SELECT
user_id,
MAX(dt) AS login_date_last,
COUNT(*) AS login_count_td
FROM
dwd_user_login_inc
GROUP BY user_id)
m
ON t.id=m.user_id;

-- 每日加载
insert overwrite table dws_user_user_login_td partition(dt='2022-06-09')
select
    nvl(old.user_id,new.user_id) AS user_id,
    -- 今天登录了就用今天，没登录就用昨天的
    nvl(new.user_id is null, old.login_date_last, '2022-06-09' null,)as login_date_last,
    -- 老用户首次日期不变，新用户用今天
    if(old.login_date_first is null, '2022-06-09', old.login_date_first) as login_date_first,
    -- 累计次数 = 昨天累计 + 今天新增
    nvl(old.login_count_td, 0) + nvl(new.login_count_1d, 0) as login_count_td
from (
    -- 昨天的累计数据
    select user_id, login_date_last, login_date_first, login_count_td
    from dws_user_user_login_td
    where dt = date_add('2022-06-09', -1)
) old
full outer join (
    -- 今天的登录数据
    select user_id, count(*) as login_count_1d
    from dwd_user_login_inc
    where dt = '2022-06-09'
    group by user_id
) new
on old.user_id = new.user_id;