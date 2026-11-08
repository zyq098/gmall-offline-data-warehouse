-- ============================================
-- DIM层：日期维度表
-- 粒度：一行一天
-- 存储格式：ORC + Snappy
-- 特点：静态表，提前造好所有日期
-- ============================================

use gmall;

DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date
(
`date_id` STRING COMMENT '日期',
`week_id` STRING COMMENT '周id',
`week_start` STRING COMMENT '周开始日期',
`month_id` STRING COMMENT '月id',
`month_start` STRING COMMENT '月开始日期',
`quarter_id` STRING COMMENT '季度id',
`quarter_start` STRING COMMENT '季度开始日期',
`year_id` STRING COMMENT '年id'
) COMMENT '日期维度表'
STORED AS ORC;
