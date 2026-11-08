# DWD 明细层

---

## 一、DWD层基本知识

### 1. 职责

对ODS数据做清洗、规范化后的最细粒度明细层，**不做聚合**。

做的事：
1. 过滤无效数据（未支付订单、测试数据）
2. 字段对齐、类型统一
3. 关联维度表补名称、小维度退化
4. 敏感信息脱敏（手机号、姓名、邮箱）
5. 空值处理（nvl补0）
6. 日期格式统一

### 2. 事实表三种类型

| 类型 | 记录什么 | 特点 | 项目例子 |
|---|---|---|---|
| 事务事实表 | 一次业务动作 | 发生写一行，不回头改 | 下单、支付、注册、收藏 |
| 周期快照 | 某时刻状态 | 每天存一份全量快照 | 购物车 |
| 累积快照 | 业务全流程 | 一个业务一行，多个时间戳 | 订单全流程 |

### 3. 连接方式选择

| 场景 | 用什么 | 原因 |
|---|---|---|
| 从表是可选信息（活动、优惠券可能没参加） | left join | 主表数据不丢 |
| 从表是过滤条件（只要支付成功） | inner join | 不匹配的直接过滤 |

### 4. 首日 vs 每日装载

| | 首日 | 每日 |
|---|---|---|
| type过滤 | bootstrap-insert | insert（支付类update） |
| 分区 | 动态分区（跨天历史） | 静态分区（当天） |
| 跨天处理 | 不需要 | 下单表取当天+昨天两个分区 |

### 5. 关键技术点

- **维度退化**：小维度（支付类型）不单独建维度表，DWD装载时关联字典表，把编码+名称一起冗余到事实表
- **nvl空值处理**：`nvl(字段, 0.0)`，优惠字段为null时补0
- **array_contains判断old**：`array_contains(map_keys(old), 'payment_status')`，确认这次update改的是哪个字段
- **动态分区 dt=null坑**：多表join后裸写字段歧义，解决：所有字段加表别名

### 6. 存储格式

ORC + Snappy，按dt天分区，全部外部表。

---

## 二、事实表明细

---

### dwd_trade_order_detail_inc（交易域下单事务事实表）

| 项 | 内容 |
|---|---|
| 表名 | dwd_trade_order_detail_inc |
| 业务过程 | 用户下单 |
| 粒度 | 一个用户对一个SKU的一条下单记录 |
| 事实表类型 | 事务事实表 |
| 主表 | ods_order_detail_inc |

#### 表关联关系图

```
主表：ods_order_detail_inc（订单明细，粒度最细）
  │
  ├─ left join ods_order_info_inc（订单主表）
  │    条件：od.order_id = oi.id
  │    作用：补user_id、province_id
  │
  ├─ left join ods_order_detail_activity_inc（订单明细活动关联）
  │    条件：od.id = act.order_detail_id
  │    作用：补activity_id、activity_rule_id
  │
  └─ left join ods_order_detail_coupon_inc（订单明细优惠券关联）
       条件：od.id = cou.order_detail_id
       作用：补coupon_id
```

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dwd_trade_order_detail_inc;
CREATE EXTERNAL TABLE dwd_trade_order_detail_inc
(
`id`                     STRING COMMENT '编号',
`order_id`              STRING COMMENT '订单ID',
`user_id`               STRING COMMENT '用户ID',
`sku_id`                STRING COMMENT '商品ID',
`province_id`          STRING COMMENT '省份ID',
`activity_id`          STRING COMMENT '参与活动ID',
`activity_rule_id`    STRING COMMENT '参与活动规则ID',
`coupon_id`             STRING COMMENT '使用优惠券ID',
`date_id`               STRING COMMENT '下单日期ID',
`create_time`           STRING COMMENT '下单时间',
`sku_num`                BIGINT COMMENT '商品数量',
`split_original_amount` DECIMAL(16, 2) COMMENT '原始价格',
`split_activity_amount` DECIMAL(16, 2) COMMENT '活动优惠分摊',
`split_coupon_amount`   DECIMAL(16, 2) COMMENT '优惠券优惠分摊',
`split_total_amount`    DECIMAL(16, 2) COMMENT '最终价格分摊'
) COMMENT '交易域下单事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_trade_order_detail_inc/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_trade_order_detail_inc partition (dt)
select
od.id,
od.order_id,
od.user_id,
od.sku_id,
od.province_id,
od.activity_id,
od.activity_rule_id,
od.coupon_id,
date_format(od.create_time, 'yyyy-MM-dd') date_id,
od.create_time,
od.sku_num,
od.split_original_amount,
nvl(od.split_activity_amount, 0.0),
nvl(od.split_coupon_amount, 0.0),
od.split_total_amount,
date_format(od.create_time, 'yyyy-MM-dd')
from
(
    select
    data.id,
    data.order_id,
    data.sku_id,
    data.create_time,
    data.sku_num,
    data.sku_num * data.order_price split_original_amount,
    data.split_total_amount,
    data.split_activity_amount,
    data.split_coupon_amount
    from ods_order_detail_inc
    where dt = '2022-06-08'
    and type = 'bootstrap-insert'
) od
left join
(
    select
    data.id,
    data.user_id,
    data.province_id
    from ods_order_info_inc
    where dt = '2022-06-08'
    and type = 'bootstrap-insert'
) oi
on od.order_id = oi.id
left join
(
    select
    data.order_detail_id,
    data.activity_id,
    data.activity_rule_id
    from ods_order_detail_activity_inc
    where dt = '2022-06-08'
    and type = 'bootstrap-insert'
) act
on od.id = act.order_detail_id
left join
(
    select
    data.order_detail_id,
    data.coupon_id
    from ods_order_detail_coupon_inc
    where dt = '2022-06-08'
    and type = 'bootstrap-insert'
) cou
on od.id = cou.order_detail_id;
```

#### 每日装载（静态分区）

> 改了：分区写死、type改成insert

```sql
insert overwrite table dwd_trade_order_detail_inc partition (dt='2022-06-09')
select
od.id,
od.order_id,
od.user_id,
od.sku_id,
od.province_id,
od.activity_id,
od.activity_rule_id,
od.coupon_id,
od.date_id,
od.create_time,
od.sku_num,
od.split_original_amount,
nvl(od.split_activity_amount, 0.0),
nvl(od.split_coupon_amount, 0.0),
od.split_total_amount
from
(
    select
    data.id,
    data.order_id,
    data.sku_id,
    date_format(data.create_time, 'yyyy-MM-dd') date_id,
    data.create_time,
    data.sku_num,
    data.sku_num * data.order_price split_original_amount,
    data.split_total_amount,
    data.split_activity_amount,
    data.split_coupon_amount
    from ods_order_detail_inc
    where dt = '2022-06-09'
    and type = 'insert'
) od
left join
(
    select
    data.id,
    data.user_id,
    data.province_id
    from ods_order_info_inc
    where dt = '2022-06-09'
    and type = 'insert'
) oi
on od.order_id = oi.id
left join
(
    select
    data.order_detail_id,
    data.activity_id,
    data.activity_rule_id
    from ods_order_detail_activity_inc
    where dt = '2022-06-09'
    and type = 'insert'
) act
on od.id = act.order_detail_id
left join
(
    select
    data.order_detail_id,
    data.coupon_id
    from ods_order_detail_coupon_inc
    where dt = '2022-06-09'
    and type = 'insert'
) cou
on od.id = cou.order_detail_id;
```

---

### dwd_trade_pay_detail_suc_inc（交易域支付成功事务事实表）

| 项 | 内容 |
|---|---|
| 表名 | dwd_trade_pay_detail_suc_inc |
| 业务过程 | 用户支付成功 |
| 粒度 | 一个用户对一个SKU支付成功 |
| 事实表类型 | 事务事实表 |
| 主表 | ods_order_detail_inc inner join ods_payment_info_inc |
| 特殊 | 维度退化（支付类型名称直接冗余到事实表） |

#### 表关联关系图

```
主表：ods_order_detail_inc（订单明细）
  │
  ├─ inner join ods_payment_info_inc（支付信息）
  │    条件：od.order_id = pi.order_id
  │    过滤：payment_status='1602'（支付成功）
  │
  ├─ left join ods_order_info_inc（订单主表）
  │    条件：od.order_id = oi.id
  │    作用：补province_id
  │
  ├─ left join ods_order_detail_activity_inc
  │    条件：od.id = act.order_detail_id
  │
  ├─ left join ods_order_detail_coupon_inc
  │    条件：od.id = cou.order_detail_id
  │
  └─ left join ods_base_dic_full（字典表）
       条件：pi.payment_type = pay_dic.dic_code
       过滤：parent_code='11'（支付类型）
       作用：补支付类型名称（维度退化）
```

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dwd_trade_pay_detail_suc_inc;
CREATE EXTERNAL TABLE dwd_trade_pay_detail_suc_inc
(
`id`                      STRING COMMENT '编号',
`order_id`               STRING COMMENT '订单ID',
`user_id`                STRING COMMENT '用户ID',
`sku_id`                 STRING COMMENT 'SKU_ID',
`province_id`           STRING COMMENT '省份ID',
`activity_id`           STRING COMMENT '参与活动ID',
`activity_rule_id`     STRING COMMENT '参与活动规则ID',
`coupon_id`              STRING COMMENT '使用优惠券ID',
`payment_type_code`     STRING COMMENT '支付类型编码',
`payment_type_name`     STRING COMMENT '支付类型名称',
`date_id`                STRING COMMENT '支付日期ID',
`callback_time`         STRING COMMENT '支付成功时间',
`sku_num`                 BIGINT COMMENT '商品数量',
`split_original_amount` DECIMAL(16, 2) COMMENT '应支付原始金额',
`split_activity_amount` DECIMAL(16, 2) COMMENT '支付活动优惠分摊',
`split_coupon_amount`   DECIMAL(16, 2) COMMENT '支付优惠券优惠分摊',
`split_payment_amount`  DECIMAL(16, 2) COMMENT '支付金额'
) COMMENT '交易域支付成功事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_trade_pay_detail_suc_inc/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_trade_pay_detail_suc_inc partition (dt)
select
od.id,
od.order_id,
pi.user_id,
od.sku_id,
oi.province_id,
act.activity_id,
act.activity_rule_id,
cou.coupon_id,
pi.payment_type,
pay_dic.dic_name,
date_format(pi.callback_time, 'yyyy-MM-dd') date_id,
pi.callback_time,
od.sku_num,
od.split_original_amount,
nvl(od.split_activity_amount, 0.0),
nvl(od.split_coupon_amount, 0.0),
od.split_total_amount,
date_format(pi.callback_time, 'yyyy-MM-dd')
from
(
    select
    data.id,
    data.order_id,
    data.sku_id,
    data.sku_num,
    data.sku_num * data.order_price split_original_amount,
    data.split_total_amount,
    data.split_activity_amount,
    data.split_coupon_amount
    from ods_order_detail_inc
    where dt='2022-06-08'
    and type='bootstrap-insert'
) od
join
(
    select
    data.user_id,
    data.order_id,
    data.payment_type,
    data.callback_time
    from ods_payment_info_inc
    where dt='2022-06-08'
    and type='bootstrap-insert'
    and data.payment_status='1602'
) pi
on od.order_id=pi.order_id
left join
(
    select
    data.id,
    data.province_id
    from ods_order_info_inc
    where dt='2022-06-08'
    and type='bootstrap-insert'
) oi
on od.order_id = oi.id
left join
(
    select
    data.order_detail_id,
    data.activity_id,
    data.activity_rule_id
    from ods_order_detail_activity_inc
    where dt='2022-06-08'
    and type='bootstrap-insert'
) act
on od.id = act.order_detail_id
left join
(
    select
    data.order_detail_id,
    data.coupon_id
    from ods_order_detail_coupon_inc
    where dt='2022-06-08'
    and type='bootstrap-insert'
) cou
on od.id = cou.order_detail_id
left join
(
    select
    dic_code,
    dic_name
    from ods_base_dic_full
    where dt='2022-06-08'
    and parent_code='11'
) pay_dic
on pi.payment_type=pay_dic.dic_code;
```

#### 每日装载（静态分区）

> 关键改动：支付表type改成update+判断old，下单表取当天+昨天两个分区

```sql
insert overwrite table dwd_trade_pay_detail_suc_inc partition (dt='2022-06-09')
select
od.id,
od.order_id,
pi.user_id,
od.sku_id,
oi.province_id,
act.activity_id,
act.activity_rule_id,
cou.coupon_id,
pi.payment_type,
pay_dic.dic_name,
date_format(pi.callback_time, 'yyyy-MM-dd') date_id,
pi.callback_time,
od.sku_num,
od.split_original_amount,
nvl(od.split_activity_amount, 0.0),
nvl(od.split_coupon_amount, 0.0),
od.split_total_amount
from
(
    select
    data.id,
    data.order_id,
    data.sku_id,
    data.sku_num,
    data.sku_num * data.order_price split_original_amount,
    data.split_total_amount,
    data.split_activity_amount,
    data.split_coupon_amount
    from ods_order_detail_inc
    where (dt='2022-06-09' or dt=date_add('2022-06-09',-1))
    and (type='insert' or type='bootstrap-insert')
) od
join
(
    select
    data.user_id,
    data.order_id,
    data.payment_type,
    data.callback_time
    from ods_payment_info_inc
    where dt='2022-06-09'
    and type='update'
    and array_contains(map_keys(old), 'payment_status')
    and data.payment_status='1602'
) pi
on od.order_id=pi.order_id
left join
(
    select
    data.id,
    data.province_id
    from ods_order_info_inc
    where (dt='2022-06-09' or dt=date_add('2022-06-09',-1))
    and (type='insert' or type='bootstrap-insert')
) oi
on od.order_id = oi.id
left join
(
    select
    data.order_detail_id,
    data.activity_id,
    data.activity_rule_id
    from ods_order_detail_activity_inc
    where (dt='2022-06-09' or dt=date_add('2022-06-09',-1))
    and (type='insert' or type='bootstrap-insert')
) act
on od.id = act.order_detail_id
left join
(
    select
    data.order_detail_id,
    data.coupon_id
    from ods_order_detail_coupon_inc
    where (dt='2022-06-09' or dt=date_add('2022-06-09',-1))
    and (type='insert' or type='bootstrap-insert')
) cou
on od.id = cou.order_detail_id
left join
(
    select
    dic_code,
    dic_name
    from ods_base_dic_full
    where dt='2022-06-09'
    and parent_code='11'
) pay_dic
on pi.payment_type=pay_dic.dic_code;
```

---

### dwd_user_register_inc（用户域用户注册事务事实表）

| 项 | 内容 |
|---|---|
| 表名 | dwd_user_register_inc |
| 业务过程 | 用户注册 |
| 粒度 | 一个用户注册记录一行 |
| 事实表类型 | 事务事实表 |
| 主表 | ods_user_info_inc（业务库用户表） |
| 维度补充 | ods_log_inc（注册页面日志，补充设备/渠道/省份） |

#### 表关联关系图

```
主表：ods_user_info_inc（业务库用户表，type='bootstrap-insert'）
  │
  └─ left join ods_log_inc（注册页面日志）
        条件：ui.user_id = log.common.uid
        过滤：page.page_id='register' 且 common.uid is not null
        作用：补充注册时的设备/渠道/省份等维度信息
```

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dwd_user_register_inc;
CREATE EXTERNAL TABLE dwd_user_register_inc
(
`user_id`       STRING COMMENT '用户ID',
`date_id`       STRING COMMENT '日期ID',
`create_time`   STRING COMMENT '注册时间',
`channel`       STRING COMMENT '应用下载渠道',
`province_id`   STRING COMMENT '省份ID',
`version_code`  STRING COMMENT '应用版本',
`mid_id`        STRING COMMENT '设备ID',
`brand`         STRING COMMENT '设备品牌',
`model`         STRING COMMENT '设备型号',
`operate_system` STRING COMMENT '设备操作系统'
) COMMENT '用户域用户注册事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_user_register_inc/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_user_register_inc partition (dt)
select
    ui.user_id,
    date_format(ui.create_time, 'yyyy-MM-dd') date_id,
    ui.create_time,
    log.channel,
    log.province_id,
    log.version_code,
    log.mid_id,
    log.brand,
    log.model,
    log.operate_system,
    date_format(ui.create_time, 'yyyy-MM-dd')
from
(
    select
        data.id as user_id,
        data.create_time
    from ods_user_info_inc
    where dt = '2022-06-08'
    and type = 'bootstrap-insert'
) ui
left join
(
    select
        common.ar as province_id,
        common.ba as brand,
        common.ch as channel,
        common.md as model,
        common.mid as mid_id,
        common.os as operate_system,
        common.uid as user_id,
        common.vc as version_code
    from ods_log_inc
    where dt = '2022-06-08'
    and page.page_id = 'register'
    and common.uid is not null
) log
on ui.user_id = log.user_id;
```

#### 每日装载（静态分区）

```sql
use gmall;

insert overwrite table dwd_user_register_inc partition(dt='2022-06-09')
select
    ui.user_id,
    date_format(ui.create_time, 'yyyy-MM-dd') date_id,
    ui.create_time,
    log.channel,
    log.province_id,
    log.version_code,
    log.mid_id,
    log.brand,
    log.model,
    log.operate_system
from
(
    select
        data.id as user_id,
        data.create_time
    from ods_user_info_inc
    where dt = '2022-06-09'
    and type = 'insert'
) ui
left join
(
    select
        common.ar as province_id,
        common.ba as brand,
        common.ch as channel,
        common.md as model,
        common.mid as mid_id,
        common.os as operate_system,
        common.uid as user_id,
        common.vc as version_code
    from ods_log_inc
    where dt = '2022-06-09'
    and page.page_id = 'register'
    and common.uid is not null
) log
on ui.user_id = log.user_id;
```

---

### dwd_interaction_favor_add_inc（互动域收藏商品事务事实表）

| 项 | 内容 |
|---|---|
| 表名 | dwd_interaction_favor_add_inc |
| 业务过程 | 用户收藏商品 |
| 粒度 | 一个用户收藏一个SKU一行 |
| 事实表类型 | 事务事实表 |
| 主表 | ods_favor_info_inc（单表清洗，不join任何表） |

#### 表关联关系图

```
ods_favor_info_inc（收藏表）
  │
  └─ 直接取字段，不join任何表
     首日：type='bootstrap-insert'
     每日：type='insert'
```

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dwd_interaction_favor_add_inc;
CREATE EXTERNAL TABLE dwd_interaction_favor_add_inc
(
`id`          STRING COMMENT '编号',
`user_id`     STRING COMMENT '用户ID',
`sku_id`      STRING COMMENT 'SKU_ID',
`date_id`     STRING COMMENT '日期ID',
`create_time` STRING COMMENT '收藏时间'
) COMMENT '互动域收藏商品事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_interaction_favor_add_inc/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_interaction_favor_add_inc partition(dt)
select
    data.id,
    data.user_id,
    data.sku_id,
    date_format(data.create_time, 'yyyy-MM-dd') date_id,
    data.create_time,
    date_format(data.create_time, 'yyyy-MM-dd')
from ods_favor_info_inc
where dt = '2022-06-08'
and type = 'bootstrap-insert';
```

#### 每日装载（静态分区）

```sql
insert overwrite table dwd_interaction_favor_add_inc partition(dt='2022-06-09')
select
    data.id,
    data.user_id,
    data.sku_id,
    date_format(data.create_time, 'yyyy-MM-dd') date_id,
    data.create_time
from ods_favor_info_inc
where dt = '2022-06-09'
and type = 'insert';
```

---

### dwd_tool_coupon_used_inc（工具域优惠券使用事务事实表）

| 项 | 内容 |
|---|---|
| 表名 | dwd_tool_coupon_used_inc |
| 业务过程 | 用户使用优惠券支付 |
| 粒度 | 一次优惠券核销一行 |
| 事实表类型 | 事务事实表 |
| 主表 | ods_coupon_use_inc（单表清洗） |
| 关键判断 | used_time不为null = 优惠券已被使用 |

#### 表关联关系图

```
ods_coupon_use_inc（优惠券领用表）
  │
  └─ 直接取字段，不join任何表
     首日：type='bootstrap-insert' 且 used_time is not null
     每日：type='update' 且 old里改过used_time字段
```

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dwd_tool_coupon_used_inc;
CREATE EXTERNAL TABLE dwd_tool_coupon_used_inc
(
`id`           STRING COMMENT '编号',
`coupon_id`    STRING COMMENT '优惠券ID',
`user_id`      STRING COMMENT '用户ID',
`order_id`     STRING COMMENT '订单ID',
`date_id`      STRING COMMENT '日期ID',
`payment_time` STRING COMMENT '使用(支付)时间'
) COMMENT '工具域优惠券使用（支付）事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd_tool_coupon_used_inc/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_tool_coupon_used_inc partition(dt)
select
    data.id,
    data.coupon_id,
    data.user_id,
    data.order_id,
    date_format(data.used_time, 'yyyy-MM-dd') date_id,
    data.used_time,
    date_format(data.used_time, 'yyyy-MM-dd')
from ods_coupon_use_inc
where dt = '2022-06-08'
and type = 'bootstrap-insert'
and data.used_time is not null;
```

#### 每日装载（静态分区）

```sql
insert overwrite table dwd_tool_coupon_used_inc partition(dt='2022-06-09')
select
    data.id,
    data.coupon_id,
    data.user_id,
    data.order_id,
    date_format(data.used_time, 'yyyy-MM-dd') date_id,
    data.used_time
from ods_coupon_use_inc
where dt = '2022-06-09'
and type = 'update'
and array_contains(map_keys(old), 'used_time');
```

---

### dwd_traffic_page_view_inc（流量域页面浏览事务事实表）

| 项 | 内容 |
|---|---|
| 表名 | dwd_traffic_page_view_inc |
| 业务过程 | 用户浏览页面 |
| 粒度 | 一次页面访问一行 |
| 事实表类型 | 事务事实表 |
| 主表 | ods_log_inc（用户行为日志） |
| 特点 | 首日=每日（日志没有历史数据） |

#### 表关联关系图

```
ods_log_inc（用户行为日志）
  │
  └─ 筛选 page is not null（只取页面日志，排除启动日志）
     从common结构体取设备维度
     从page结构体取页面信息
     ts时间戳转东八区时间
```

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dwd_traffic_page_view_inc;
CREATE EXTERNAL TABLE dwd_traffic_page_view_inc
(
`province_id`    STRING COMMENT '省份ID',
`brand`          STRING COMMENT '手机品牌',
`channel`        STRING COMMENT '渠道',
`is_new`         STRING COMMENT '是否首次启动',
`model`          STRING COMMENT '手机型号',
`mid_id`         STRING COMMENT '设备ID',
`operate_system` STRING COMMENT '操作系统',
`user_id`        STRING COMMENT '会员ID',
`version_code`   STRING COMMENT 'APP版本号',
`page_item`      STRING COMMENT '目标ID',
`page_item_type` STRING COMMENT '目标类型',
`last_page_id`   STRING COMMENT '上页ID',
`page_id`        STRING COMMENT '页面ID',
`from_pos_id`    STRING COMMENT '点击坑位ID',
`from_pos_seq`   STRING COMMENT '点击坑位位置',
`refer_id`       STRING COMMENT '营销渠道ID',
`date_id`        STRING COMMENT '日期ID',
`view_time`      STRING COMMENT '跳入时间',
`session_id`     STRING COMMENT '所属会话ID',
`during_time`    BIGINT COMMENT '持续时间毫秒'
) COMMENT '流量域页面浏览事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_traffic_page_view_inc/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 装载SQL（首日=每日，逻辑一样）

```sql
use gmall;

set hive.cbo.enable=false;

insert overwrite table dwd_traffic_page_view_inc partition (dt='2022-06-08')
select
    common.ar  as province_id,
    common.ba  as brand,
    common.ch  as channel,
    common.is_new as is_new,
    common.md  as model,
    common.mid as mid_id,
    common.os  as operate_system,
    common.uid as user_id,
    common.vc  as version_code,
    page.item  as page_item,
    page.item_type as page_item_type,
    page.last_page_id as last_page_id,
    page.page_id as page_id,
    page.from_pos_id as from_pos_id,
    page.from_pos_seq as from_pos_seq,
    page.refer_id as refer_id,
    date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd') date_id,
    date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd HH:mm:ss') view_time,
    common.sid as session_id,
    cast(page.during_time as bigint) as during_time
from ods_log_inc
where dt = '2022-06-08'
and page is not null;

set hive.cbo.enable=true;
```

---

### dwd_trade_cart_add_inc（交易域加购事务事实表）

| 项 | 内容 |
|---|---|
| 表名 | dwd_trade_cart_add_inc |
| 业务过程 | 用户加购物车 |
| 粒度 | 一次加购操作一行 |
| 事实表类型 | 事务事实表 |
| 主表 | ods_cart_info_inc（购物车表，单表清洗） |

#### 表关联关系图

```
ods_cart_info_inc（购物车增量表）
  │
  ├─ 首日：type='bootstrap-insert'，create_time作为加购时间
  │
  └─ 每日：两类加购操作
     ├─ type='insert'：新增购物车记录，create_time是加购时间
     └─ type='update' 且 sku_num变大：加购数量增加，update_time是加购时间
```

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dwd_trade_cart_add_inc;
CREATE EXTERNAL TABLE dwd_trade_cart_add_inc
(
`id`          STRING COMMENT '编号',
`user_id`     STRING COMMENT '用户ID',
`sku_id`      STRING COMMENT 'SKU_ID',
`date_id`     STRING COMMENT '日期ID',
`create_time` STRING COMMENT '加购时间',
`sku_num`     BIGINT COMMENT '加购物车件数'
) COMMENT '交易域加购事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_trade_cart_add_inc/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_trade_cart_add_inc partition (dt)
select
    data.id,
    data.user_id,
    data.sku_id,
    date_format(data.create_time, 'yyyy-MM-dd') date_id,
    data.create_time,
    data.sku_num,
    date_format(data.create_time, 'yyyy-MM-dd')
from ods_cart_info_inc
where dt = '2022-06-08'
and type = 'bootstrap-insert';
```

#### 每日装载（静态分区）

```sql
insert overwrite table dwd_trade_cart_add_inc partition (dt='2022-06-09')
select
    data.id,
    data.user_id,
    data.sku_id,
    date_format(from_utc_timestamp(ts * 1000, 'GMT+8'), 'yyyy-MM-dd') date_id,
    date_format(from_utc_timestamp(ts * 1000, 'GMT+8'), 'yyyy-MM-dd HH:mm:ss') create_time,
    if(type = 'insert', data.sku_num, cast(data.sku_num as int) - cast(old['sku_num'] as int)) sku_num
from ods_cart_info_inc
where dt = '2022-06-09'
and (type = 'insert'
     or (type = 'update' and old['sku_num'] is not null and cast(data.sku_num as int) > cast(old['sku_num'] as int)));
```

---

### dwd_trade_cart_full（交易域购物车周期快照事实表）

| 项 | 内容 |
|---|---|
| 表名 | dwd_trade_cart_full |
| 业务过程 | 购物车每日快照 |
| 粒度 | 一个用户一个SKU在购物车里的存量 |
| 事实表类型 | **周期快照事实表** |
| 主表 | ods_cart_info_full（购物车全量表） |

#### 表关联关系图

```
ods_cart_info_full（购物车全量表）
  │
  └─ 筛选 is_ordered='0'（未下单的才在购物车里）
```

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dwd_trade_cart_full;
CREATE EXTERNAL TABLE dwd_trade_cart_full
(
`id`         STRING COMMENT '编号',
`user_id`   STRING COMMENT '用户ID',
`sku_id`    STRING COMMENT 'SKU_ID',
`sku_name`  STRING COMMENT '商品名称',
`sku_num`   BIGINT COMMENT '现存商品件数'
) COMMENT '交易域购物车周期快照事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_trade_cart_full/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 装载SQL（首日=每日，每天全量覆盖）

```sql
insert overwrite table dwd_trade_cart_full partition(dt='2022-06-08')
select
    id,
    user_id,
    sku_id,
    sku_name,
    sku_num
from ods_cart_info_full
where dt = '2022-06-08'
and is_ordered = '0';
```

---

### dwd_trade_trade_flow_acc（交易域交易流程累积快照事实表）

| 项 | 内容 |
|---|---|
| 表名 | dwd_trade_trade_flow_acc |
| 业务过程 | 订单全流程（下单→支付→收货） |
| 粒度 | 一个订单一行 |
| 事实表类型 | **累积快照事实表** |
| 主表 | ods_order_info_inc（订单主表） |
| 关联 | left join支付表、left join订单状态流水表 |

#### 表关联关系图

```
主表：ods_order_info_inc（订单主表）
  │
  ├─ left join ods_payment_info_inc（支付成功）
  │    条件：order_id，过滤payment_status='1602'
  │    作用：补支付时间、支付金额
  │
  └─ left join ods_order_status_log_inc（订单状态流水）
       条件：order_id，过滤order_status='1004'（确认收货）
       作用：补收货时间
```

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dwd_trade_trade_flow_acc;
CREATE EXTERNAL TABLE dwd_trade_trade_flow_acc
(
`order_id`               STRING COMMENT '订单ID',
`user_id`                STRING COMMENT '用户ID',
`province_id`           STRING COMMENT '省份ID',
`order_date_id`         STRING COMMENT '下单日期ID',
`order_time`             STRING COMMENT '下单时间',
`payment_date_id`        STRING COMMENT '支付日期ID',
`payment_time`           STRING COMMENT '支付时间',
`finish_date_id`         STRING COMMENT '确认收货日期ID',
`finish_time`             STRING COMMENT '确认收货时间',
`order_original_amount` DECIMAL(16, 2) COMMENT '下单原始价格',
`order_activity_amount` DECIMAL(16, 2) COMMENT '下单活动优惠分摊',
`order_coupon_amount`   DECIMAL(16, 2) COMMENT '下单优惠券优惠分摊',
`order_total_amount`    DECIMAL(16, 2) COMMENT '下单最终价格分摊',
`payment_amount`         DECIMAL(16, 2) COMMENT '支付金额'
) COMMENT '交易域交易流程累积快照事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_trade_trade_flow_acc/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_trade_trade_flow_acc partition(dt)
select
    oi.id,
    oi.user_id,
    oi.province_id,
    date_format(oi.create_time, 'yyyy-MM-dd'),
    oi.create_time,
    date_format(pi.callback_time, 'yyyy-MM-dd'),
    pi.callback_time,
    date_format(log.finish_time, 'yyyy-MM-dd'),
    log.finish_time,
    oi.original_total_amount,
    oi.activity_reduce_amount,
    oi.coupon_reduce_amount,
    oi.total_amount,
    nvl(pi.payment_amount, 0.0),
    nvl(date_format(log.finish_time, 'yyyy-MM-dd'), '9999-12-31')
from
(
    select
    data.id, data.user_id, data.province_id, data.create_time,
    data.original_total_amount, data.activity_reduce_amount,
    data.coupon_reduce_amount, data.total_amount
    from ods_order_info_inc
    where dt='2022-06-08' and type='bootstrap-insert'
) oi
left join
(
    select data.order_id, data.callback_time, data.total_amount payment_amount
    from ods_payment_info_inc
    where dt='2022-06-08' and type='bootstrap-insert' and data.payment_status='1602'
) pi
on oi.id=pi.order_id
left join
(
    select data.order_id, data.create_time finish_time
    from ods_order_status_log_inc
    where dt='2022-06-08' and type='bootstrap-insert' and data.order_status='1004'
) log
on oi.id=log.order_id;
```

#### 每日装载（动态分区）

```sql
set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dwd_trade_trade_flow_acc partition(dt)
select
    oi.order_id,
    oi.user_id,
    oi.province_id,
    oi.order_date_id,
    oi.order_time,
    nvl(oi.payment_date_id, pi.payment_date_id),
    nvl(oi.payment_time, pi.payment_time),
    nvl(oi.finish_date_id, log.finish_date_id),
    nvl(oi.finish_time, log.finish_time),
    oi.order_original_amount,
    oi.order_activity_amount,
    oi.order_coupon_amount,
    oi.order_total_amount,
    nvl(oi.payment_amount, pi.payment_amount),
    nvl(nvl(oi.finish_time, log.finish_time), '9999-12-31')
from
(
    -- 昨天未完成的订单
    select order_id, user_id, province_id, order_date_id, order_time,
           payment_date_id, payment_time, finish_date_id, finish_time,
           order_original_amount, order_activity_amount, order_coupon_amount,
           order_total_amount, payment_amount
    from dwd_trade_trade_flow_acc
    where dt='9999-12-31'
    union all
    -- 今天新下单的订单
    select data.id, data.user_id, data.province_id,
           date_format(data.create_time, 'yyyy-MM-dd'), data.create_time,
           null, null, null, null,
           data.original_total_amount, data.activity_reduce_amount,
           data.coupon_reduce_amount, data.total_amount, null
    from ods_order_info_inc
    where dt='2022-06-09' and type='insert'
) oi
left join
(
    select data.order_id,
           date_format(data.callback_time, 'yyyy-MM-dd') payment_date_id,
           data.callback_time payment_time,
           data.total_amount payment_amount
    from ods_payment_info_inc
    where dt='2022-06-09' and type='update'
    and array_contains(map_keys(old), 'payment_status')
    and data.payment_status='1602'
) pi
on oi.order_id=pi.order_id
left join
(
    select data.order_id,
           date_format(data.create_time, 'yyyy-MM-dd') finish_date_id,
           data.create_time finish_time
    from ods_order_status_log_inc
    where dt='2022-06-09' and type='insert' and data.order_status='1004'
) log
on oi.order_id=log.order_id;
```

---

### dwd_user_login_inc（用户域用户登录事务事实表）

| 项 | 内容 |
|---|---|
| 表名 | dwd_user_login_inc |
| 业务过程 | 用户登录 |
| 粒度 | 一次登录一行 |
| 事实表类型 | 事务事实表 |
| 主表 | ods_log_inc（用户行为日志） |
| 关键技术 | row_number() 按会话分组，取每个会话第一条有user_id的记录 |

#### 表关联关系图

```
ods_log_inc（用户行为日志）
  │
  ├─ 筛选 page is not null 且 common.uid is not null
  ├─ row_number() over(partition by common.sid order by ts) rn
  └─ 筛选 rn=1（每个会话第一条有user_id的记录 = 登录）
```

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dwd_user_login_inc;
CREATE EXTERNAL TABLE dwd_user_login_inc
(
`user_id`         STRING COMMENT '用户ID',
`date_id`         STRING COMMENT '日期ID',
`login_time`      STRING COMMENT '登录时间',
`channel`         STRING COMMENT '应用下载渠道',
`province_id`     STRING COMMENT '省份ID',
`version_code`    STRING COMMENT '应用版本',
`mid_id`          STRING COMMENT '设备ID',
`brand`           STRING COMMENT '设备品牌',
`model`           STRING COMMENT '设备型号',
`operate_system` STRING COMMENT '设备操作系统'
) COMMENT '用户域用户登录事务事实表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_user_login_inc/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 装载SQL（首日=每日）

```sql
insert overwrite table dwd_user_login_inc partition (dt='2022-06-08')
select
    user_id,
    date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd') date_id,
    date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd HH:mm:ss') login_time,
    channel,
    province_id,
    version_code,
    mid_id,
    brand,
    model,
    operate_system
from (
    select user_id, channel, province_id, version_code, mid_id, brand, model, operate_system, ts
    from (
        select
            common.uid as user_id,
            common.ch  as channel,
            common.ar  as province_id,
            common.vc  as version_code,
            common.mid as mid_id,
            common.ba  as brand,
            common.md  as model,
            common.os  as operate_system,
            ts,
            row_number() over(partition by common.sid order by ts) as rn
        from ods_log_inc
        where dt = '2022-06-08'
        and page is not null
        and common.uid is not null
    ) t1
    where rn = 1
) t2;
```
