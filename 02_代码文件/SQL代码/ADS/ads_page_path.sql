-- ============================================
-- 页面浏览路径分析
-- 粒度：页面跳转路径
-- 来源：dwd_traffic_page_view_inc
-- 特点：lead()窗口函数取下一页，桑基图数据源
-- ============================================

use gmall;

-- 1. 建表语句
DROP TABLE IF EXISTS ads_page_path;
CREATE EXTERNAL TABLE ads_page_path
(
`dt`          STRING COMMENT '统计日期',
`source`      STRING COMMENT '跳转起始页面ID',
`target`      STRING COMMENT '跳转终到页面ID',
`path_count`  BIGINT COMMENT '跳转次数'
) COMMENT '页面浏览路径分析'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_page_path/';

-- 2. 装载SQL
insert overwrite table ads_page_path
select * from ads_page_path
union
select
    '2022-06-08' dt,
    source,
    nvl(target, 'null') as target,
    count(*) as path_count
from
(
    select
        concat('step-', rn, ':', page_id) as source,
        concat('step-', rn+1, ':', next_page_id) as target
    from
    (
        select
            page_id,
            -- 取下一行的page_id，就是用户下一个看的页面
            lead(page_id, 1, null) over(partition by session_id order by view_time) as next_page_id,
            -- 给当前会话里的页面按时间排序编号
            row_number() over(partition by session_id order by view_time) as rn
        from dwd_traffic_page_view_inc
        where dt='2022-06-08'
    ) t1
) t2
group by source, target;
