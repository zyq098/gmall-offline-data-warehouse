# ODS 贴源层

---

## 一、ODS层基本知识

### 1. 职责

贴源层，**原样保留业务系统数据**，不做任何加工。
相当于把业务库的数据原封不动搬到数仓里，是数仓的数据源入口。

做的事：
1. 全量数据同步（DataX）
2. 增量数据同步（Maxwell+Kafka+Flume）
3. 按天分区存储

### 2. 全量表 vs 增量表

| | 全量表 | 增量表 |
|---|---|---|
| 同步方式 | DataX每天导整张表 | Maxwell监听binlog，只导变化数据 |
| 适用场景 | 数据量小、会被修改的表（用户、商品） | 数据量大、只增不改的表（订单、支付） |
| 表后缀 | _full | _inc |
| 数据结构 | 直接是业务表字段 | data（JSON字符串）+ type + ts |

### 3. 数据采集流程

**全量表：**
```
业务MySQL → DataX → HDFS（ODS层）
```

**增量表：**
```
业务MySQL binlog → Maxwell → Kafka → Flume → HDFS（ODS层）
```

为什么要经过Kafka？解耦+削峰，Maxwell写Kafka很快，Flume消费慢一点不影响业务库。

### 4. 装载特点

- 全量表：每天DataX全量覆盖当天分区
- 增量表：每天Flume采集当天binlog到当天分区
- ODS层不做任何SQL清洗，就是把HDFS上的文件load进Hive表

### 5. 存储格式

全部用TextFile行存，按dt天分区，全部外部表。
路径在 `/warehouse/gmall/ods/`。

为什么用TextFile不用ORC？贴源层原样保留，不做格式转换，省计算。

---

## 二、全量表明细（10张）

---

### ods_user_info_full（用户信息全量表）

| 项 | 内容 |
|---|---|
| 表名 | ods_user_info_full |
| 类型 | 全量表 |
| 粒度 | 一行一个用户 |
| 来源 | 业务库user_info表，DataX全量同步 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ods_user_info_full;
CREATE EXTERNAL TABLE ods_user_info_full
(
`id` STRING COMMENT '用户编号',
`login_name` STRING COMMENT '登录名',
`nick_name` STRING COMMENT '昵称',
`passwd` STRING COMMENT '密码',
`name` STRING COMMENT '真实姓名',
`phone_num` STRING COMMENT '手机号',
`email` STRING COMMENT '邮箱',
`head_img` STRING COMMENT '头像',
`user_level` STRING COMMENT '用户等级',
`birthday` STRING COMMENT '生日',
`gender` STRING COMMENT '性别',
`create_time` STRING COMMENT '创建时间',
`operate_time` STRING COMMENT '操作时间',
`status` STRING COMMENT '状态'
) COMMENT '用户信息全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_user_info_full/';
```

#### 首日/每日装载

```sql
-- 每天DataX导新文件到HDFS，然后load进当天分区
load data inpath '/warehouse/gmall/ods/ods_user_info_full/2022-06-08'
overwrite into table ods_user_info_full partition(dt='2022-06-08');
```

---

### ods_sku_info_full（商品SKU全量表）

| 项 | 内容 |
|---|---|
| 表名 | ods_sku_info_full |
| 类型 | 全量表 |
| 粒度 | 一行一个SKU |
| 来源 | 业务库sku_info表，DataX全量同步 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ods_sku_info_full;
CREATE EXTERNAL TABLE ods_sku_info_full
(
`id` STRING COMMENT 'sku_id',
`spu_id` STRING COMMENT 'spu_id',
`price` DECIMAL(16,2) COMMENT '价格',
`sku_name` STRING COMMENT '商品名称',
`sku_desc` STRING COMMENT '商品描述',
`weight` DECIMAL(16,2) COMMENT '重量',
`tm_id` STRING COMMENT '品牌id',
`category3_id` STRING COMMENT '三级品类id',
`sku_default_img` STRING COMMENT '默认图片',
`is_sale` STRING COMMENT '是否在售',
`create_time` STRING COMMENT '创建时间',
`operate_time` STRING COMMENT '修改时间'
) COMMENT '商品SKU全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_sku_info_full/';
```

#### 装载说明
跟用户表一样，DataX全量导，然后load进当天分区。

---

### ods_spu_info_full（商品SPU全量表）

| 项 | 内容 |
|---|---|
| 表名 | ods_spu_info_full |
| 类型 | 全量表 |
| 粒度 | 一行一个SPU |
| 来源 | 业务库spu_info表 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ods_spu_info_full;
CREATE EXTERNAL TABLE ods_spu_info_full
(
`id` STRING COMMENT 'spu_id',
`spu_name` STRING COMMENT 'spu名称',
`description` STRING COMMENT '描述',
`category3_id` STRING COMMENT '三级品类id',
`tm_id` STRING COMMENT '品牌id'
) COMMENT '商品SPU全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_spu_info_full/';
```

---

### ods_base_category1_full（一级品类全量表）

| 项 | 内容 |
|---|---|
| 表名 | ods_base_category1_full |
| 类型 | 全量表 |
| 粒度 | 一行一个一级品类 |
| 来源 | 业务库base_category1表 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ods_base_category1_full;
CREATE EXTERNAL TABLE ods_base_category1_full
(
`id` STRING COMMENT '一级品类id',
`name` STRING COMMENT '一级品类名称'
) COMMENT '一级品类全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_base_category1_full/';
```

---

### ods_base_category2_full（二级品类全量表）

| 项 | 内容 |
|---|---|
| 表名 | ods_base_category2_full |
| 类型 | 全量表 |
| 粒度 | 一行一个二级品类 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ods_base_category2_full;
CREATE EXTERNAL TABLE ods_base_category2_full
(
`id` STRING COMMENT '二级品类id',
`name` STRING COMMENT '二级品类名称',
`category1_id` STRING COMMENT '一级品类id'
) COMMENT '二级品类全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_base_category2_full/';
```

---

### ods_base_category3_full（三级品类全量表）

| 项 | 内容 |
|---|---|
| 表名 | ods_base_category3_full |
| 类型 | 全量表 |
| 粒度 | 一行一个三级品类 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ods_base_category3_full;
CREATE EXTERNAL TABLE ods_base_category3_full
(
`id` STRING COMMENT '三级品类id',
`name` STRING COMMENT '三级品类名称',
`category2_id` STRING COMMENT '二级品类id'
) COMMENT '三级品类全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_base_category3_full/';
```

---

### ods_base_dic_full（数据字典全量表）

| 项 | 内容 |
|---|---|
| 表名 | ods_base_dic_full |
| 类型 | 全量表 |
| 粒度 | 一条字典数据一行 |
| 用途 | 维度退化时把编码转成名称 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ods_base_dic_full;
CREATE EXTERNAL TABLE ods_base_dic_full
(
`dic_code` STRING COMMENT '字典编码',
`dic_name` STRING COMMENT '字典名称',
`parent_code` STRING COMMENT '父编码',
`create_time` STRING COMMENT '创建时间',
`operate_time` STRING COMMENT '操作时间'
) COMMENT '数据字典全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_base_dic_full/';
```

---

### ods_base_province_full（省份全量表）

| 项 | 内容 |
|---|---|
| 表名 | ods_base_province_full |
| 类型 | 全量表 |
| 粒度 | 一行一个省份 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ods_base_province_full;
CREATE EXTERNAL TABLE ods_base_province_full
(
`id` STRING COMMENT '省份id',
`name` STRING COMMENT '省份名称',
`region_id` STRING COMMENT '地区id',
`area_code` STRING COMMENT '地区编码',
`iso_code` STRING COMMENT '旧版国际标准编码',
`iso_3166_2` STRING COMMENT '新版国际标准编码'
) COMMENT '省份全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_base_province_full/';
```

---

### ods_base_region_full（地区全量表）

| 项 | 内容 |
|---|---|
| 表名 | ods_base_region_full |
| 类型 | 全量表 |
| 粒度 | 一行一个地区（华北、华东等） |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ods_base_region_full;
CREATE EXTERNAL TABLE ods_base_region_full
(
`id` STRING COMMENT '地区id',
`region_name` STRING COMMENT '地区名称'
) COMMENT '地区全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_base_region_full/';
```

---

### ods_cart_info_full（购物车全量表）

| 项 | 内容 |
|---|---|
| 表名 | ods_cart_info_full |
| 类型 | 全量表 |
| 粒度 | 一行一条购物车记录 |
| 特点 | 周期快照，每天存一份全量 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ods_cart_info_full;
CREATE EXTERNAL TABLE ods_cart_info_full
(
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
) COMMENT '购物车全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_cart_info_full/';
```

---

## 三、增量表明细（21张）

增量表结构全部一样，只有表名不同。统一模板：

```sql
use gmall;

DROP TABLE IF EXISTS __TABLE_NAME__;
CREATE EXTERNAL TABLE __TABLE_NAME__
(
`data` STRING COMMENT '业务数据JSON字符串',
`type` STRING COMMENT '操作类型：insert/update/delete/bootstrap-insert',
`ts` BIGINT COMMENT 'binlog时间戳'
) COMMENT '__TABLE_NAME__ 增量数据'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/__TABLE_NAME__/';
```

### 装载方式

```sql
-- 每天Flume采集当天binlog到HDFS，然后load进当天分区
load data inpath '/warehouse/gmall/ods/__TABLE_NAME__/2022-06-08'
overwrite into table __TABLE_NAME__ partition(dt='2022-06-08');
```

### 21张增量表清单

| 表名 | 说明 |
|---|---|
| ods_order_info_inc | 订单主表 |
| ods_order_detail_inc | 订单明细表 |
| ods_order_status_inc | 订单状态表 |
| ods_order_activity_inc | 订单活动表 |
| ods_order_coupon_inc | 订单优惠券表 |
| ods_payment_info_inc | 支付表 |
| ods_cart_add_inc | 加购表 |
| ods_favor_info_inc | 收藏表 |
| ods_comment_info_inc | 评论表 |
| ods_coupon_use_inc | 优惠券使用表 |
| ods_user_register_inc | 用户注册表 |
| ods_user_login_inc | 用户登录表 |
| ods_activity_info_inc | 活动表 |
| ods_activity_rule_inc | 活动规则表 |
| ods_coupon_info_inc | 优惠券表 |
| ods_order_detail_activity_inc | 订单明细活动表 |
| ods_order_detail_coupon_inc | 订单明细优惠券表 |
| ods_order_refund_inc | 退单表 |
| ods_payment_refund_inc | 退款表 |
| ods_page_log_inc | 页面日志表（埋点） |
| ods_event_log_inc | 事件日志表（埋点） |

---

## 四、核心考点汇总

| 考点 | 答案 |
|---|---|
| ODS层为什么用TextFile不用ORC | 贴源层原样保留，不做格式转换，省计算 |
| 全量表和增量表怎么选 | 数据量小会改的用全量，数据量大只增的用增量 |
| 增量数据怎么采集 | Maxwell监听binlog，发到Kafka，Flume采集到HDFS |
| 为什么要经过Kafka | 解耦+削峰，不影响业务库 |
| ODS层做不做清洗 | 不做，原样保留，脏数据也留着 |
| 外部表和内部表区别 | 外部表删表不删HDFS文件，安全 |
| 增量表的三个字段是什么 | data（业务数据JSON）、type（操作类型）、ts（时间戳） |
| bootstrap-insert是什么 | Maxwell初始化历史数据的操作类型 |
