# DWS 汇总层

---

## 一、DWS层基本知识

### 1. 职责

对DWD明细层按**维度分组聚合**，沉淀公共指标，供ADS层报表直接使用。

做的事：
1. 按维度（用户、商品、省份）分组聚合
2. 计算公共指标（下单次数、支付金额、加购数）
3. 分粒度：1d（最近1日）、nd（最近n日）、td（历史累计）

### 2. 粒度分类

| 类型 | 含义 | 例子 |
|---|---|---|
| 1d | 最近1日 | 用户今天下了几单 |
| nd | 最近n日（7日/30日） | 用户最近7天下了几单 |
| td | 历史累计 | 用户从注册到现在一共下了几单 |

### 3. 维度分类

| 维度 | 例子 |
|---|---|
| 用户粒度 | 每个用户每天的指标 |
| 商品粒度 | 每个SKU每天的指标 |
| 用户+商品粒度 | 每个用户买每个SKU的指标 |
| 省份粒度 | 每个省份每天的指标 |

### 4. 装载特点

- 首日：动态分区，按业务日期落分区
- 每日：静态分区，写死当天日期
- 核心就是 `group by + 聚合函数`，比DWD简单

### 5. 存储格式

ORC + Snappy，按dt天分区，全部外部表。

---

## 二、汇总表明细

---

### dws_trade_user_order_1d（交易域用户粒度订单最近1日汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_trade_user_order_1d |
| 粒度 | 用户×天 |
| 来源 | dwd_trade_order_detail_inc（订单明细事实表） |
| 指标 | 下单次数、商品件数、原始金额、活动优惠、优惠券优惠、最终金额 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dws_trade_user_order_1d;
CREATE EXTERNAL TABLE dws_trade_user_order_1d
(
`user_id`                   STRING COMMENT '用户ID',
`order_count_1d`            BIGINT COMMENT '最近1日下单次数',
`order_num_1d`              BIGINT COMMENT '最近1日下单商品件数',
`order_original_amount_1d`  DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
`activity_reduce_amount_1d` DECIMAL(16, 2) COMMENT '最近1日下单活动优惠金额',
`coupon_reduce_amount_1d`   DECIMAL(16, 2) COMMENT '最近1日下单优惠券优惠金额',
`order_total_amount_1d`     DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
) COMMENT '交易域用户粒度订单最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_user_order_1d'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dws_trade_user_order_1d partition(dt)
select
    user_id,
    count(distinct order_id),            -- 下单次数
    sum(sku_num),                         -- 下单商品件数
    sum(split_original_amount),           -- 原始金额
    sum(nvl(split_activity_amount, 0)),   -- 活动优惠
    sum(nvl(split_coupon_amount, 0)),    -- 优惠券优惠
    sum(split_total_amount),               -- 最终金额
    dt
from dwd_trade_order_detail_inc
group by user_id, dt;
```

#### 每日装载（静态分区）

```sql
insert overwrite table dws_trade_user_order_1d partition(dt='2022-06-09')
select
    user_id,
    count(distinct order_id),
    sum(sku_num),
    sum(split_original_amount),
    sum(nvl(split_activity_amount, 0)),
    sum(nvl(split_coupon_amount, 0)),
    sum(split_total_amount)
from dwd_trade_order_detail_inc
where dt='2022-06-09'
group by user_id;
```

---

### dws_trade_user_cart_add_1d（交易域用户粒度加购最近1日汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_trade_user_cart_add_1d |
| 粒度 | 用户×天 |
| 来源 | dwd_trade_cart_add_inc（加购事实表） |
| 指标 | 加购次数、加购商品件数 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dws_trade_user_cart_add_1d;
CREATE EXTERNAL TABLE dws_trade_user_cart_add_1d
(
`user_id`           STRING COMMENT '用户ID',
`cart_add_count_1d` BIGINT COMMENT '最近1日加购次数',
`cart_add_num_1d`   BIGINT COMMENT '最近1日加购商品件数'
) COMMENT '交易域用户粒度加购最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_user_cart_add_1d'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dws_trade_user_cart_add_1d partition(dt)
select
    user_id,
    count(*),           -- 加购次数
    sum(sku_num),       -- 加购商品件数
    dt
from dwd_trade_cart_add_inc
group by user_id, dt;
```

#### 每日装载（静态分区）

```sql
insert overwrite table dws_trade_user_cart_add_1d partition(dt='2022-06-09')
select
    user_id,
    count(*),
    sum(sku_num)
from dwd_trade_cart_add_inc
where dt='2022-06-09'
group by user_id;
```

---

### dws_trade_user_payment_1d（交易域用户粒度支付最近1日汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_trade_user_payment_1d |
| 粒度 | 用户×天 |
| 来源 | dwd_trade_pay_detail_suc_inc（支付成功事实表） |
| 指标 | 支付次数、支付商品件数、支付金额 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dws_trade_user_payment_1d;
CREATE EXTERNAL TABLE dws_trade_user_payment_1d
(
`user_id`           STRING COMMENT '用户ID',
`payment_count_1d`  BIGINT COMMENT '最近1日支付次数',
`payment_num_1d`    BIGINT COMMENT '最近1日支付商品件数',
`payment_amount_1d` DECIMAL(16, 2) COMMENT '最近1日支付金额'
) COMMENT '交易域用户粒度支付最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_user_payment_1d'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dws_trade_user_payment_1d partition(dt)
select
    user_id,
    count(distinct order_id),
    sum(sku_num),
    sum(split_payment_amount),
    dt
from dwd_trade_pay_detail_suc_inc
group by user_id, dt;
```

#### 每日装载（静态分区）

```sql
insert overwrite table dws_trade_user_payment_1d partition(dt='2022-06-09')
select
    user_id,
    count(distinct order_id),
    sum(sku_num),
    sum(split_payment_amount)
from dwd_trade_pay_detail_suc_inc
where dt='2022-06-09'
group by user_id;
```

---

### dws_tool_user_coupon_coupon_used_1d（工具域用户优惠券粒度使用最近1日汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_tool_user_coupon_coupon_used_1d |
| 粒度 | 用户×优惠券×天 |
| 来源 | dwd_tool_coupon_used_inc（优惠券使用事实表） |
| 维度补充 | dim_coupon_full（优惠券维度表） |
| 指标 | 使用次数 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dws_tool_user_coupon_coupon_used_1d;
CREATE EXTERNAL TABLE dws_tool_user_coupon_coupon_used_1d
(
`user_id`          STRING COMMENT '用户ID',
`coupon_id`        STRING COMMENT '优惠券ID',
`coupon_name`      STRING COMMENT '优惠券名称',
`coupon_type_code` STRING COMMENT '优惠券类型编码',
`coupon_type_name` STRING COMMENT '优惠券类型名称',
`benefit_rule`     STRING COMMENT '优惠规则',
`used_count_1d`    STRING COMMENT '使用(支付)次数'
) COMMENT '工具域用户优惠券粒度优惠券使用(支付)最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_tool_user_coupon_coupon_used_1d'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dws_tool_user_coupon_coupon_used_1d partition(dt)
select
    t1.user_id,
    t1.coupon_id,
    t2.coupon_name,
    t2.coupon_type_code,
    t2.coupon_type_name,
    t2.benefit_rule,
    t1.used_count,
    t1.dt
from
(
    select
        dt,
        user_id,
        coupon_id,
        count(*) used_count
    from dwd_tool_coupon_used_inc
    group by dt, user_id, coupon_id
) t1
left join
(
    select
        id,
        coupon_name,
        coupon_type_code,
        coupon_type_name,
        benefit_rule
    from dim_coupon_full
    where dt='2022-06-08'
) t2
on t1.coupon_id = t2.id;
```

#### 每日装载（静态分区）

```sql
insert overwrite table dws_tool_user_coupon_coupon_used_1d partition(dt='2022-06-09')
select
    t1.user_id,
    t1.coupon_id,
    t2.coupon_name,
    t2.coupon_type_code,
    t2.coupon_type_name,
    t2.benefit_rule,
    t1.used_count
from
(
    select
        user_id,
        coupon_id,
        count(*) used_count
    from dwd_tool_coupon_used_inc
    where dt='2022-06-09'
    group by user_id, coupon_id
) t1
left join
(
    select
        id,
        coupon_name,
        coupon_type_code,
        coupon_type_name,
        benefit_rule
    from dim_coupon_full
    where dt='2022-06-09'
) t2
on t1.coupon_id = t2.id;
```

---

### dws_interaction_sku_favor_add_1d（互动域商品粒度收藏最近1日汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_interaction_sku_favor_add_1d |
| 粒度 | 商品×天 |
| 来源 | dwd_interaction_favor_add_inc（收藏事实表） |
| 维度补充 | dim_sku_full（商品维度表） |
| 指标 | 被收藏次数 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dws_interaction_sku_favor_add_1d;
CREATE EXTERNAL TABLE dws_interaction_sku_favor_add_1d
(
`sku_id`             STRING COMMENT 'SKU_ID',
`sku_name`           STRING COMMENT 'SKU名称',
`category1_id`       STRING COMMENT '一级品类ID',
`category1_name`     STRING COMMENT '一级品类名称',
`category2_id`       STRING COMMENT '二级品类ID',
`category2_name`     STRING COMMENT '二级品类名称',
`category3_id`       STRING COMMENT '三级品类ID',
`category3_name`     STRING COMMENT '三级品类名称',
`tm_id`              STRING COMMENT '品牌ID',
`tm_name`            STRING COMMENT '品牌名称',
`favor_add_count_1d` BIGINT COMMENT '商品被收藏次数'
) COMMENT '互动域商品粒度收藏商品最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_interaction_sku_favor_add_1d'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dws_interaction_sku_favor_add_1d partition(dt)
select
    favor.sku_id,
    sku.sku_name,
    sku.category1_id,
    sku.category1_name,
    sku.category2_id,
    sku.category2_name,
    sku.category3_id,
    sku.category3_name,
    sku.tm_id,
    sku.tm_name,
    favor.favor_add_count,
    favor.dt
from
(
    select
        dt,
        sku_id,
        count(*) favor_add_count
    from dwd_interaction_favor_add_inc
    group by dt, sku_id
) favor
left join
(
    select
        id,
        sku_name,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        tm_id,
        tm_name
    from dim_sku_full
    where dt='2022-06-08'
) sku
on favor.sku_id = sku.id;
```

#### 每日装载（静态分区）

```sql
insert overwrite table dws_interaction_sku_favor_add_1d partition(dt='2022-06-09')
select
    favor.sku_id,
    sku.sku_name,
    sku.category1_id,
    sku.category1_name,
    sku.category2_id,
    sku.category2_name,
    sku.category3_id,
    sku.category3_name,
    sku.tm_id,
    sku.tm_name,
    favor.favor_add_count
from
(
    select
        sku_id,
        count(*) favor_add_count
    from dwd_interaction_favor_add_inc
    where dt='2022-06-09'
    group by sku_id
) favor
left join
(
    select
        id,
        sku_name,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        tm_id,
        tm_name
    from dim_sku_full
    where dt='2022-06-09'
) sku
on favor.sku_id = sku.id;
```

---

### dws_traffic_session_page_view_1d（流量域会话粒度页面浏览最近1日汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_traffic_session_page_view_1d |
| 粒度 | 会话×天 |
| 来源 | dwd_traffic_page_view_inc（页面浏览事实表） |
| 指标 | 浏览时长、浏览页面数 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dws_traffic_session_page_view_1d;
CREATE EXTERNAL TABLE dws_traffic_session_page_view_1d
(
`session_id`     STRING COMMENT '会话ID',
`mid_id`         STRING COMMENT '设备ID',
`brand`          STRING COMMENT '手机品牌',
`model`          STRING COMMENT '手机型号',
`operate_system` STRING COMMENT '操作系统',
`version_code`   STRING COMMENT 'APP版本号',
`channel`        STRING COMMENT '渠道',
`during_time_1d` BIGINT COMMENT '最近1日浏览时长',
`page_count_1d`  BIGINT COMMENT '最近1日浏览页面数'
) COMMENT '流量域会话粒度页面浏览最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_traffic_session_page_view_1d'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 装载SQL（首日=每日）

```sql
insert overwrite table dws_traffic_session_page_view_1d partition(dt='2022-06-08')
select
    session_id,
    mid_id,
    brand,
    model,
    operate_system,
    version_code,
    channel,
    sum(during_time),
    count(*)
from dwd_traffic_page_view_inc
where dt='2022-06-08'
group by session_id, mid_id, brand, model, operate_system, version_code, channel;
```

---

### dws_traffic_page_visitor_page_view_1d（流量域访客页面粒度页面浏览最近1日汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_traffic_page_visitor_page_view_1d |
| 粒度 | 访客×页面×天 |
| 来源 | dwd_traffic_page_view_inc（页面浏览事实表） |
| 指标 | 浏览时长、访问次数 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dws_traffic_page_visitor_page_view_1d;
CREATE EXTERNAL TABLE dws_traffic_page_visitor_page_view_1d
(
`mid_id`         STRING COMMENT '访客ID',
`brand`          STRING COMMENT '手机品牌',
`model`          STRING COMMENT '手机型号',
`operate_system` STRING COMMENT '操作系统',
`page_id`        STRING COMMENT '页面ID',
`during_time_1d` BIGINT COMMENT '最近1日浏览时长',
`view_count_1d`  BIGINT COMMENT '最近1日访问次数'
) COMMENT '流量域访客页面粒度页面浏览最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_traffic_page_visitor_page_view_1d'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 装载SQL（首日=每日）

```sql
insert overwrite table dws_traffic_page_visitor_page_view_1d partition(dt='2022-06-08')
select
    mid_id,
    brand,
    model,
    operate_system,
    page_id,
    sum(during_time),
    count(*)
from dwd_traffic_page_view_inc
where dt='2022-06-08'
group by mid_id, brand, model, operate_system, page_id;
```

---

### dws_trade_province_order_1d（交易域省份粒度订单最近1日汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_trade_province_order_1d |
| 粒度 | 省份×天 |
| 来源 | dwd_trade_order_detail_inc（订单明细事实表） |
| 维度补充 | dim_province_full（省份维度表） |
| 指标 | 下单次数、原始金额、活动优惠、优惠券优惠、最终金额 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dws_trade_province_order_1d;
CREATE EXTERNAL TABLE dws_trade_province_order_1d
(
`province_id`               STRING COMMENT '省份ID',
`province_name`             STRING COMMENT '省份名称',
`area_code`                 STRING COMMENT '地区编码',
`iso_code`                  STRING COMMENT '旧版国际标准地区编码',
`iso_3166_2`                STRING COMMENT '新版国际标准地区编码',
`order_count_1d`            BIGINT COMMENT '最近1日下单次数',
`order_original_amount_1d`  DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
`activity_reduce_amount_1d` DECIMAL(16, 2) COMMENT '最近1日下单活动优惠金额',
`coupon_reduce_amount_1d`   DECIMAL(16, 2) COMMENT '最近1日下单优惠券优惠金额',
`order_total_amount_1d`     DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
) COMMENT '交易域省份粒度订单最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_province_order_1d'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dws_trade_province_order_1d partition(dt)
select
    o.province_id,
    p.province_name,
    p.area_code,
    p.iso_code,
    p.iso_3166_2,
    o.order_count_1d,
    o.order_original_amount_1d,
    o.activity_reduce_amount_1d,
    o.coupon_reduce_amount_1d,
    o.order_total_amount_1d,
    o.dt
from
(
    select
        province_id,
        count(distinct order_id) order_count_1d,
        sum(split_original_amount) order_original_amount_1d,
        sum(nvl(split_activity_amount, 0)) activity_reduce_amount_1d,
        sum(nvl(split_coupon_amount, 0)) coupon_reduce_amount_1d,
        sum(split_total_amount) order_total_amount_1d,
        dt
    from dwd_trade_order_detail_inc
    group by province_id, dt
) o
left join
(
    select
        id,
        province_name,
        area_code,
        iso_code,
        iso_3166_2
    from dim_province_full
    where dt='2022-06-08'
) p
on o.province_id = p.id;
```

#### 每日装载（静态分区）

```sql
insert overwrite table dws_trade_province_order_1d partition(dt='2022-06-09')
select
    o.province_id,
    p.province_name,
    p.area_code,
    p.iso_code,
    p.iso_3166_2,
    o.order_count_1d,
    o.order_original_amount_1d,
    o.activity_reduce_amount_1d,
    o.coupon_reduce_amount_1d,
    o.order_total_amount_1d
from
(
    select
        province_id,
        count(distinct order_id) order_count_1d,
        sum(split_original_amount) order_original_amount_1d,
        sum(nvl(split_activity_amount, 0)) activity_reduce_amount_1d,
        sum(nvl(split_coupon_amount, 0)) coupon_reduce_amount_1d,
        sum(split_total_amount) order_total_amount_1d
    from dwd_trade_order_detail_inc
    where dt='2022-06-09'
    group by province_id
) o
left join
(
    select
        id,
        province_name,
        area_code,
        iso_code,
        iso_3166_2
    from dim_province_full
    where dt='2022-06-09'
) p
on o.province_id = p.id;
```

---

### dws_trade_user_sku_order_1d（交易域用户+商品粒度订单最近1日汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_trade_user_sku_order_1d |
| 粒度 | 用户×商品×天 |
| 来源 | dwd_trade_order_detail_inc（订单明细事实表） |
| 维度补充 | dim_sku_full（商品维度表） |
| 指标 | 下单次数、下单件数、原始金额、活动优惠、优惠券优惠、最终金额 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dws_trade_user_sku_order_1d;
CREATE EXTERNAL TABLE dws_trade_user_sku_order_1d
(
`user_id`                   STRING COMMENT '用户ID',
`sku_id`                    STRING COMMENT 'SKU_ID',
`sku_name`                  STRING COMMENT 'SKU名称',
`category1_id`              STRING COMMENT '一级品类ID',
`category1_name`            STRING COMMENT '一级品类名称',
`category2_id`              STRING COMMENT '二级品类ID',
`category2_name`            STRING COMMENT '二级品类名称',
`category3_id`              STRING COMMENT '三级品类ID',
`category3_name`            STRING COMMENT '三级品类名称',
`tm_id`                      STRING COMMENT '品牌ID',
`tm_name`                    STRING COMMENT '品牌名称',
`order_count_1d`            BIGINT COMMENT '最近1日下单次数',
`order_num_1d`              BIGINT COMMENT '最近1日下单件数',
`order_original_amount_1d`  DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
`activity_reduce_amount_1d` DECIMAL(16, 2) COMMENT '最近1日活动优惠金额',
`coupon_reduce_amount_1d`   DECIMAL(16, 2) COMMENT '最近1日优惠券优惠金额',
`order_total_amount_1d`     DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
) COMMENT '交易域用户商品粒度订单最近1日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_user_sku_order_1d'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（动态分区）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;
-- Hive bug：关矢量化查询避免报错
set hive.vectorized.execution.enabled = false;

insert overwrite table dws_trade_user_sku_order_1d partition(dt)
select
    od.user_id,
    sku.id,
    sku.sku_name,
    sku.category1_id,
    sku.category1_name,
    sku.category2_id,
    sku.category2_name,
    sku.category3_id,
    sku.category3_name,
    sku.tm_id,
    sku.tm_name,
    od.order_count_1d,
    od.order_num_1d,
    od.order_original_amount_1d,
    od.activity_reduce_amount_1d,
    od.coupon_reduce_amount_1d,
    od.order_total_amount_1d,
    od.dt
from
(
    select
        dt,
        user_id,
        sku_id,
        count(*) order_count_1d,
        sum(sku_num) order_num_1d,
        sum(split_original_amount) order_original_amount_1d,
        sum(nvl(split_activity_amount, 0.0)) activity_reduce_amount_1d,
        sum(nvl(split_coupon_amount, 0.0)) coupon_reduce_amount_1d,
        sum(split_total_amount) order_total_amount_1d
    from dwd_trade_order_detail_inc
    group by dt, user_id, sku_id
) od
left join
(
    select
        id,
        sku_name,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        tm_id,
        tm_name
    from dim_sku_full
    where dt='2022-06-08'
) sku
on od.sku_id = sku.id;

set hive.vectorized.execution.enabled = true;
```

#### 每日装载（静态分区）

```sql
set hive.vectorized.execution.enabled = false;

insert overwrite table dws_trade_user_sku_order_1d partition(dt='2022-06-09')
select
    od.user_id,
    sku.id,
    sku.sku_name,
    sku.category1_id,
    sku.category1_name,
    sku.category2_id,
    sku.category2_name,
    sku.category3_id,
    sku.category3_name,
    sku.tm_id,
    sku.tm_name,
    od.order_count,
    od.order_num,
    od.order_original_amount,
    od.activity_reduce_amount,
    od.coupon_reduce_amount,
    od.order_total_amount
from
(
    select
        user_id,
        sku_id,
        count(*) order_count,
        sum(sku_num) order_num,
        sum(split_original_amount) order_original_amount,
        sum(nvl(split_activity_amount, 0)) activity_reduce_amount,
        sum(nvl(split_coupon_amount, 0)) coupon_reduce_amount,
        sum(split_total_amount) order_total_amount
    from dwd_trade_order_detail_inc
    where dt='2022-06-09'
    group by user_id, sku_id
) od
left join
(
    select
        id,
        sku_name,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        tm_id,
        tm_name
    from dim_sku_full
    where dt='2022-06-09'
) sku
on od.sku_id = sku.id;

set hive.vectorized.execution.enabled = true;
```

---

### dws_trade_user_sku_order_nd（交易域用户+商品粒度订单最近n日汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_trade_user_sku_order_nd |
| 粒度 | 用户×商品×天 |
| 来源 | dws_trade_user_sku_order_1d（复用1日汇总表） |
| 指标 | 最近7日/最近30日下单次数、件数、原始金额、活动优惠、优惠券优惠、最终金额 |

#### 核心逻辑

- 不从DWD明细取数，直接从1d汇总表取，复用计算结果
- 一个SQL同时算7日和30日指标：sum(if(dt>=最近7天, 指标, 0)) 算7日，直接sum算30日
- where先筛最近30天的数据

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dws_trade_user_sku_order_nd;
CREATE EXTERNAL TABLE dws_trade_user_sku_order_nd
(
`user_id`                     STRING COMMENT '用户ID',
`sku_id`                      STRING COMMENT 'SKU_ID',
`sku_name`                    STRING COMMENT 'SKU名称',
`category1_id`               STRING COMMENT '一级品类ID',
`category1_name`             STRING COMMENT '一级品类名称',
`category2_id`               STRING COMMENT '二级品类ID',
`category2_name`             STRING COMMENT '二级品类名称',
`category3_id`               STRING COMMENT '三级品类ID',
`category3_name`             STRING COMMENT '三级品类名称',
`tm_id`                       STRING COMMENT '品牌ID',
`tm_name`                     STRING COMMENT '品牌名称',
`order_count_7d`             STRING COMMENT '最近7日下单次数',
`order_num_7d`               BIGINT COMMENT '最近7日下单件数',
`order_original_amount_7d`   DECIMAL(16, 2) COMMENT '最近7日下单原始金额',
`activity_reduce_amount_7d`  DECIMAL(16, 2) COMMENT '最近7日活动优惠金额',
`coupon_reduce_amount_7d`    DECIMAL(16, 2) COMMENT '最近7日优惠券优惠金额',
`order_total_amount_7d`      DECIMAL(16, 2) COMMENT '最近7日下单最终金额',
`order_count_30d`            BIGINT COMMENT '最近30日下单次数',
`order_num_30d`              BIGINT COMMENT '最近30日下单件数',
`order_original_amount_30d`  DECIMAL(16, 2) COMMENT '最近30日下单原始金额',
`activity_reduce_amount_30d` DECIMAL(16, 2) COMMENT '最近30日活动优惠金额',
`coupon_reduce_amount_30d`   DECIMAL(16, 2) COMMENT '最近30日优惠券优惠金额',
`order_total_amount_30d`     DECIMAL(16, 2) COMMENT '最近30日下单最终金额'
) COMMENT '交易域用户商品粒度订单最近n日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_user_sku_order_nd'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 装载SQL（首日=每日，逻辑相同）

```sql
insert overwrite table dws_trade_user_sku_order_nd partition(dt='2022-06-08')
select
    user_id,
    sku_id,
    sku_name,
    category1_id,
    category1_name,
    category2_id,
    category2_name,
    category3_id,
    category3_name,
    tm_id,
    tm_name,
    -- 最近7日指标：只加最近7天的
    sum(if(dt >= date_add('2022-06-08', -6), order_count_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), order_num_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), order_original_amount_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), activity_reduce_amount_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), coupon_reduce_amount_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), order_total_amount_1d, 0)),
    -- 最近30日指标：全部加（where已筛最近30天）
    sum(order_count_1d),
    sum(order_num_1d),
    sum(order_original_amount_1d),
    sum(activity_reduce_amount_1d),
    sum(coupon_reduce_amount_1d),
    sum(order_total_amount_1d)
from dws_trade_user_sku_order_1d
where dt >= date_add('2022-06-08', -29)
group by user_id, sku_id, sku_name, category1_id, category1_name,
         category2_id, category2_name, category3_id, category3_name, tm_id, tm_name;
```

---

### dws_trade_province_order_nd（交易域省份粒度订单最近n日汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_trade_province_order_nd |
| 粒度 | 省份×天 |
| 来源 | dws_trade_province_order_1d（复用1日汇总表） |
| 指标 | 最近7日/最近30日下单次数、原始金额、活动优惠、优惠券优惠、最终金额 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dws_trade_province_order_nd;
CREATE EXTERNAL TABLE dws_trade_province_order_nd
(
`province_id`                STRING COMMENT '省份ID',
`province_name`              STRING COMMENT '省份名称',
`area_code`                  STRING COMMENT '地区编码',
`iso_code`                   STRING COMMENT '旧版国际标准地区编码',
`iso_3166_2`                 STRING COMMENT '新版国际标准地区编码',
`order_count_7d`             BIGINT COMMENT '最近7日下单次数',
`order_original_amount_7d`   DECIMAL(16, 2) COMMENT '最近7日下单原始金额',
`activity_reduce_amount_7d`  DECIMAL(16, 2) COMMENT '最近7日活动优惠金额',
`coupon_reduce_amount_7d`    DECIMAL(16, 2) COMMENT '最近7日优惠券优惠金额',
`order_total_amount_7d`      DECIMAL(16, 2) COMMENT '最近7日下单最终金额',
`order_count_30d`            BIGINT COMMENT '最近30日下单次数',
`order_original_amount_30d`  DECIMAL(16, 2) COMMENT '最近30日下单原始金额',
`activity_reduce_amount_30d` DECIMAL(16, 2) COMMENT '最近30日活动优惠金额',
`coupon_reduce_amount_30d`   DECIMAL(16, 2) COMMENT '最近30日优惠券优惠金额',
`order_total_amount_30d`     DECIMAL(16, 2) COMMENT '最近30日下单最终金额'
) COMMENT '交易域省份粒度订单最近n日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_province_order_nd'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 装载SQL（首日=每日）

```sql
insert overwrite table dws_trade_province_order_nd partition(dt='2022-06-08')
select
    province_id,
    province_name,
    area_code,
    iso_code,
    iso_3166_2,
    -- 最近7日
    sum(if(dt >= date_add('2022-06-08', -6), order_count_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), order_original_amount_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), activity_reduce_amount_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), coupon_reduce_amount_1d, 0)),
    sum(if(dt >= date_add('2022-06-08', -6), order_total_amount_1d, 0)),
    -- 最近30日
    sum(order_count_1d),
    sum(order_original_amount_1d),
    sum(activity_reduce_amount_1d),
    sum(coupon_reduce_amount_1d),
    sum(order_total_amount_1d)
from dws_trade_province_order_1d
where dt >= date_add('2022-06-08', -29)
  and dt <= '2022-06-08'
group by province_id, province_name, area_code, iso_code, iso_3166_2;
```

---

### dws_trade_user_order_td（交易域用户粒度订单历史至今汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_trade_user_order_td |
| 粒度 | 用户×天 |
| 来源 | dws_trade_user_order_1d（复用1日汇总表） |
| 指标 | 历史至今首次/末次下单日期、累计下单次数、累计件数、累计金额 |

#### 核心逻辑

- 首日：直接从1d表全部数据按user_id分组聚合
- 每日：昨天的累计数据 + 今天的新增数据，union all后按user_id分组sum
- td表是只增不减的累计，所以可以做增量，不用扫全量历史

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dws_trade_user_order_td;
CREATE EXTERNAL TABLE dws_trade_user_order_td
(
`user_id`                   STRING COMMENT '用户ID',
`order_date_first`          STRING COMMENT '历史至今首次下单日期',
`order_date_last`           STRING COMMENT '历史至今末次下单日期',
`order_count_td`            BIGINT COMMENT '历史至今下单次数',
`order_num_td`              BIGINT COMMENT '历史至今购买商品件数',
`original_amount_td`        DECIMAL(16, 2) COMMENT '历史至今下单原始金额',
`activity_reduce_amount_td` DECIMAL(16, 2) COMMENT '历史至今下单活动优惠金额',
`coupon_reduce_amount_td`   DECIMAL(16, 2) COMMENT '历史至今下单优惠券优惠金额',
`total_amount_td`           DECIMAL(16, 2) COMMENT '历史至今下单最终金额'
) COMMENT '交易域用户粒度订单历史至今汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dws/dws_trade_user_order_td'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载

```sql
insert overwrite table dws_trade_user_order_td partition(dt='2022-06-08')
select
    user_id,
    min(dt) order_date_first,
    max(dt) order_date_last,
    sum(order_count_1d) order_count_td,
    sum(order_num_1d) order_num_td,
    sum(order_original_amount_1d) original_amount_td,
    sum(activity_reduce_amount_1d) activity_reduce_amount_td,
    sum(coupon_reduce_amount_1d) coupon_reduce_amount_td,
    sum(order_total_amount_1d) total_amount_td
from dws_trade_user_order_1d
group by user_id;
```

#### 每日装载（union all方式，推荐）

```sql
insert overwrite table dws_trade_user_order_td partition(dt='2022-06-09')
select
    user_id,
    min(order_date_first) order_date_first,
    max(order_date_last) order_date_last,
    sum(order_count_td) order_count_td,
    sum(order_num_td) order_num_td,
    sum(original_amount_td) original_amount_td,
    sum(activity_reduce_amount_td) activity_reduce_amount_td,
    sum(coupon_reduce_amount_td) coupon_reduce_amount_td,
    sum(total_amount_td) total_amount_td
from (
    -- 昨天的累计数据
    select
        user_id,
        order_date_first,
        order_date_last,
        order_count_td,
        order_num_td,
        original_amount_td,
        activity_reduce_amount_td,
        coupon_reduce_amount_td,
        total_amount_td
    from dws_trade_user_order_td
    where dt = date_add('2022-06-09', -1)

    union all

    -- 今天的新数据
    select
        user_id,
        '2022-06-09' order_date_first,
        '2022-06-09' order_date_last,
        order_count_1d,
        order_num_1d,
        order_original_amount_1d,
        activity_reduce_amount_1d,
        coupon_reduce_amount_1d,
        order_total_amount_1d
    from dws_trade_user_order_1d
    where dt = '2022-06-09'
) t1
group by user_id;
```

---

### dws_user_user_login_td（用户域用户粒度登录历史至今汇总表）

| 项 | 内容 |
|---|---|
| 表名 | dws_user_user_login_td |
| 粒度 | 用户×天 |
| 来源 | dwd_user_login_inc + dim_user_zip |
| 指标 | 历史至今首次/末次登录日期、累计登录次数 |

#### 核心逻辑

- 首日：关联用户拉链表，因为登录日志可能不全，注册了的用户都要算
- 每日：昨天累计 + 今天新增，full outer join合并
- 特殊点：没登录记录的用户，默认登录次数算1次（注册即登录）

#### 建表语句

```sql
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
```

#### 首日装载

```sql
insert overwrite table dws_user_user_login_td partition(dt='2022-06-08')
select
    u.id as user_id,
    nvl(login_date_last, date_format(create_time, 'yyyy-MM-dd')) as login_date_last,
    date_format(create_time, 'yyyy-MM-dd') as login_date_first,
    nvl(login_count_td, 1) as login_count_td
from (
    -- 所有注册用户
    select id, create_time
    from dim_user_zip
    where dt = '9999-12-31'
) u
left join (
    -- 今天有登录记录的用户
    select
        user_id,
        max(dt) as login_date_last,
        count(*) as login_count_td
    from dwd_user_login_inc
    group by user_id
) l
on u.id = l.user_id;
```

#### 每日装载

```sql
insert overwrite table dws_user_user_login_td partition(dt='2022-06-09')
select
    nvl(old.user_id, new.user_id) as user_id,
    -- 今天登录了就用今天，没登录就用昨天的
    if(new.user_id is null, old.login_date_last, '2022-06-09') as login_date_last,
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
```

---

## 三、DWS层总结

| 类型 | 数量 | 说明 |
|---|---|---|
| 1d表 | 9张 | 按维度分组聚合当日数据 |
| nd表 | 2张 | 最近7日/30日滚动窗口，从1d表取数重算 |
| td表 | 2张 | 历史累计，昨天累计+今天新增做增量 |
| **总计** | **13张** | DWS层全部完成 |
