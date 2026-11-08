use gmall;

DROP TABLE IF EXISTS ods_cart_info_full;
CREATE EXTERNAL TABLE ods_cart_info_full(
`id` STRING COMMENT '购物车id',
`user_id` STRING COMMENT '用户id',
`sku_id` STRING COMMENT '商品id',
`cart_price` DECIMAL(16,2) COMMENT '加入时价格',
`sku_num` BIGINT COMMENT '数量',
`sku_name` STRING COMMENT '商品名称',
`img_url` STRING COMMENT '图片',
`is_checked` STRING COMMENT '是否选中',
`create_time` STRING COMMENT '创建时间',
`operate_time` STRING COMMENT '操作时间',
`spu_id` STRING COMMENT 'spu_id',
`sku_attr_id` STRING COMMENT '属性id',
`category_id` STRING COMMENT '品类id'
) COMMENT 'ods_cart_info_full 全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_cart_info_full/';