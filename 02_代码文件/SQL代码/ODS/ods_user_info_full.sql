-- ============================================
-- ODS层全量表：用户信息表
-- 粒度：一行一个用户
-- 存储格式：TextFile，按dt分区
-- ============================================

use gmall;

DROP TABLE IF EXISTS ods_user_info_full;
CREATE EXTERNAL TABLE ods_user_info_full
(
`id` STRING COMMENT '用户编号',
`login_name` STRING COMMENT '用户登录名',
`nick_name` STRING COMMENT '用户昵称',
`passwd` STRING COMMENT '用户密码',
`name` STRING COMMENT '用户真实姓名',
`phone_num` STRING COMMENT '手机号',
`email` STRING COMMENT '邮箱',
`head_img` STRING COMMENT '头像',
`user_level` STRING COMMENT '用户等级',
`birthday` STRING COMMENT '生日',
`gender` STRING COMMENT '性别',
`create_time` STRING COMMENT '创建时间',
`operate_time` STRING COMMENT '操作时间',
`status` STRING COMMENT '状态'
) COMMENT '用户表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_user_info_full/';
