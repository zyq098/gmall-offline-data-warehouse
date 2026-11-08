-- ============================================
-- DIM层：用户拉链表
-- 粒度：一行一个用户的一个历史状态
-- 存储格式：ORC + Snappy
-- 特点：拉链表，保存用户历史变化
-- ============================================

use gmall;

DROP TABLE IF EXISTS dim_user_zip;
CREATE EXTERNAL TABLE dim_user_zip
(
`id` STRING COMMENT '用户id',
`name` STRING COMMENT '用户姓名',
`phone_num` STRING COMMENT '手机号',
`email` STRING COMMENT '邮箱',
`user_level` STRING COMMENT '用户等级',
`birthday` STRING COMMENT '生日',
`gender` STRING COMMENT '性别',
`create_time` STRING COMMENT '创建时间',
`operate_time` STRING COMMENT '操作时间',
`start_date` STRING COMMENT '生效日期',
`end_date` STRING COMMENT '失效日期'
) COMMENT '用户维度表（拉链表）'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dim/dim_user_zip/';
