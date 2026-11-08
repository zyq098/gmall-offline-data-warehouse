# DIM 维度层

---

## 一、DIM层基本知识

### 1. 职责

存放维度数据，为上层事实表提供维度关联。
相当于把业务系统里的"字典表"整理好，做宽表、做退化，方便上层用。

做的事：
1. 维度表清洗、规范化
2. 维度退化（把小维度直接冗余到事实表）
3. 拉链表保存维度历史变化
4. 敏感信息脱敏

### 2. 维度表三种类型

| 类型 | 特点 | 项目例子 |
|---|---|---|
| 全量快照维度 | 每天存一份全量，取最新分区 | SKU、品类、地区 |
| 拉链维度 | 一行记录有生效日期和失效日期，保存历史 | 用户信息 |
| 静态维度 | 提前造好，不变化 | 日期表 |

### 3. 拉链表原理

为什么要用拉链表？
- 全量快照：每天存一份全量，数据量翻倍，浪费空间
- 只存最新：历史状态丢了，没法追溯"昨天这个用户是什么等级"
- 拉链表：用start_date和end_date标记每条记录的生效时间，一条用户变化只存一行

拉链表数据长这样：

| id | name | level | start_date | end_date | dt |
|---|---|---|---|---|---|
| 1 | 张三 | 普通 | 2022-06-01 | 2022-06-08 | 9999-12-31 |
| 1 | 张三 | 会员 | 2022-06-09 | 9999-12-31 | 9999-12-31 |

查6月8号用户等级：找 `start_date <= '2022-06-08' and end_date > '2022-06-08'` 的那条。

### 4. 装载特点

| | 首日 | 每日 |
|---|---|---|
| 全量维度 | 直接全量导入 | 每天覆盖最新分区 |
| 拉链维度 | 初始化所有历史数据 | 昨天9999分区 + 今天变更数据，打时间标签合并 |

### 5. 存储格式

ORC + Snappy压缩，按dt天分区，全部外部表。
路径在 `/warehouse/gmall/dim/`。

为什么用ORC？维度表经常全表扫描做join，ORC列存压缩率高、查询快。

---

## 二、表明细

---

### dim_user_zip（用户拉链维度表）

| 项 | 内容 |
|---|---|
| 表名 | dim_user_zip |
| 类型 | 拉链表 |
| 粒度 | 一行一个用户的一个历史状态 |
| 来源 | ods_user_info_full + ods_user_info_inc |

#### 建表语句

```sql
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
LOCATION '/warehouse/gmall/dim/dim_user_zip/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载（初始化拉链）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dim_user_zip partition(dt)
select
    id,
    -- 敏感信息脱敏：姓名只留姓，手机号中间打星
    concat(substr(name, 1, 1), '*') as name,
    if(phone_num regexp '^1[3-9]\\d{9}$', concat(substr(phone_num,1,3), '****', substr(phone_num,8,4)), null) as phone_num,
    if(email regexp '^[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+$', concat('*@', split(email, '@')[1]), null) as email,
    user_level,
    birthday,
    gender,
    create_time,
    operate_time,
    '2022-06-08' as start_date,
    '9999-12-31' as end_date,
    '9999-12-31' as dt
from ods_user_info_full
where dt='2022-06-08';
```

#### 每日装载（拉链合并）

```sql
use gmall;

set hive.exec.dynamic.partition.mode=nonstrict;

insert overwrite table dim_user_zip partition(dt)
select
    id, name, phone_num, email, user_level, birthday, gender,
    create_time, operate_time, start_date,
    -- rn=2的旧记录，end_date改成昨天
    if(rn = 2, date_sub('2022-06-09', 1), end_date) as end_date,
    -- rn=1的最新记录放9999分区，旧记录放昨天分区
    if(rn = 1, '9999-12-31', date_sub('2022-06-09', 1)) as dt
from (
    select
        id, name, phone_num, email, user_level, birthday, gender,
        create_time, operate_time, start_date, end_date,
        row_number() over (partition by id order by start_date desc) as rn
    from (
        -- ① 昨天9999分区的旧数据
        select
            id, name, phone_num, email, user_level, birthday, gender,
            create_time, operate_time, start_date, end_date
        from dim_user_zip
        where dt = '9999-12-31'

        union all

        -- ② 今天变更的新数据
        select
            data.id as id,
            concat(substr(data.name, 1, 1), '*') as name,
            if(data.phone_num regexp '^1[3-9]\\d{9}$', concat(substr(data.phone_num,1,3), '****', substr(data.phone_num,8,4)), null) as phone_num,
            if(data.email regexp '^[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+$', concat('*@', split(data.email, '@')[1]), null) as email,
            data.user_level as user_level,
            data.birthday as birthday,
            data.gender as gender,
            data.create_time as create_time,
            data.operate_time as operate_time,
            '2022-06-09' as start_date,
            '9999-12-31' as end_date
        from ods_user_info_inc
        where dt = '2022-06-09'
        and type = 'update'
    ) t1
) t2;
```

---

### dim_sku_full（商品SKU全量维度表）

| 项 | 内容 |
|---|---|
| 表名 | dim_sku_full |
| 类型 | 全量快照维度 |
| 粒度 | 一行一个SKU |
| 来源 | ods_sku_info_full + 品类表 + 品牌表 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dim_sku_full;
CREATE EXTERNAL TABLE dim_sku_full
(
`id` STRING COMMENT 'sku_id',
`spu_id` STRING COMMENT 'spu_id',
`price` DECIMAL(16,2) COMMENT '价格',
`sku_name` STRING COMMENT '商品名称',
`sku_desc` STRING COMMENT '商品描述',
`weight` DECIMAL(16,2) COMMENT '重量',
`is_sale` STRING COMMENT '是否在售',
`sku_default_img` STRING COMMENT '默认图片',
`category1_id` STRING COMMENT '一级品类id',
`category1_name` STRING COMMENT '一级品类名称',
`category2_id` STRING COMMENT '二级品类id',
`category2_name` STRING COMMENT '二级品类名称',
`category3_id` STRING COMMENT '三级品类id',
`category3_name` STRING COMMENT '三级品类名称',
`tm_id` STRING COMMENT '品牌id',
`tm_name` STRING COMMENT '品牌名称'
) COMMENT '商品SKU维度表（退化品类+品牌）'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dim/dim_sku_full/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载

```sql
use gmall;

insert overwrite table dim_sku_full partition(dt='2022-06-08')
select
    sku.id,
    sku.spu_id,
    sku.price,
    sku.sku_name,
    sku.sku_desc,
    sku.weight,
    sku.is_sale,
    sku.sku_default_img,
    c1.id as category1_id,
    c1.name as category1_name,
    c2.id as category2_id,
    c2.name as category2_name,
    c3.id as category3_id,
    c3.name as category3_name,
    sku.tm_id,
    tm.tm_name
from ods_sku_info_full sku
left join ods_base_category3_full c3 on sku.category3_id = c3.id
left join ods_base_category2_full c2 on c3.category2_id = c2.id
left join ods_base_category1_full c1 on c2.category1_id = c1.id
left join ods_base_trademark_full tm on sku.tm_id = tm.id
where sku.dt='2022-06-08';
```

#### 每日装载

```sql
-- 全量维度，每天覆盖当天分区，逻辑跟首日一样，换日期
insert overwrite table dim_sku_full partition(dt='2022-06-09')
select ... -- 同上，from ods_sku_info_full where dt='2022-06-09'
```

---

### dim_category_full（品类全量维度表）

| 项 | 内容 |
|---|---|
| 表名 | dim_category_full |
| 类型 | 全量快照维度 |
| 粒度 | 一行一条三级品类（连一二级名称） |
| 来源 | ods_base_category1/2/3_full 三表join |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dim_category_full;
CREATE EXTERNAL TABLE dim_category_full
(
`category1_id` STRING COMMENT '一级品类id',
`category1_name` STRING COMMENT '一级品类名称',
`category2_id` STRING COMMENT '二级品类id',
`category2_name` STRING COMMENT '二级品类名称',
`category3_id` STRING COMMENT '三级品类id',
`category3_name` STRING COMMENT '三级品类名称'
) COMMENT '品类维度表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dim/dim_category_full/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载

```sql
use gmall;

insert overwrite table dim_category_full partition(dt='2022-06-08')
select
    c1.id as category1_id,
    c1.name as category1_name,
    c2.id as category2_id,
    c2.name as category2_name,
    c3.id as category3_id,
    c3.name as category3_name
from ods_base_category3_full c3
join ods_base_category2_full c2 on c3.category2_id = c2.id
join ods_base_category1_full c1 on c2.category1_id = c1.id
where c3.dt='2022-06-08';
```

#### 每日装载

```sql
-- 全量覆盖，逻辑同首日，换日期
insert overwrite table dim_category_full partition(dt='2022-06-09')
select ... -- from 三张品类表 where dt='2022-06-09'
```

---

### dim_province_full（地区全量维度表）

| 项 | 内容 |
|---|---|
| 表名 | dim_province_full |
| 类型 | 全量快照维度 |
| 粒度 | 一行一个省份 |
| 来源 | ods_base_province_full + ods_base_region_full |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dim_province_full;
CREATE EXTERNAL TABLE dim_province_full
(
`id` STRING COMMENT '省份id',
`province_name` STRING COMMENT '省份名称',
`area_code` STRING COMMENT '地区编码',
`iso_code` STRING COMMENT '旧版国际标准编码',
`iso_3166_2` STRING COMMENT '新版国际标准编码'
) COMMENT '地区维度表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dim/dim_province_full/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载

```sql
use gmall;

insert overwrite table dim_province_full partition(dt='2022-06-08')
select
    id,
    name as province_name,
    area_code,
    iso_code,
    iso_3166_2
from ods_base_province_full
where dt='2022-06-08';
```

#### 每日装载

```sql
-- 全量覆盖，逻辑同首日
insert overwrite table dim_province_full partition(dt='2022-06-09')
select id, name, area_code, iso_code, iso_3166_2 from ods_base_province_full where dt='2022-06-09';
```

---

### dim_date（日期静态维度表）

| 项 | 内容 |
|---|---|
| 表名 | dim_date |
| 类型 | 静态维度（不分区） |
| 粒度 | 一行一天 |
| 特点 | 提前造好所有日期，不随业务更新 |

#### 建表语句

```sql
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
) COMMENT '日期维度表（静态表，不分区）'
STORED AS ORC
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 装载说明

静态表，一次性导入，不用每天跑。
用存储过程或者Python脚本批量生成2020-2030年的所有日期，insert进去就行。

---

### dim_activity_full（活动全量维度表）

| 项 | 内容 |
|---|---|
| 表名 | dim_activity_full |
| 类型 | 全量快照维度 |
| 粒度 | 一行一个活动 |
| 来源 | ods_activity_info_full + ods_activity_rule_full |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS dim_activity_full;
CREATE EXTERNAL TABLE dim_activity_full
(
`activity_id` STRING COMMENT '活动id',
`activity_name` STRING COMMENT '活动名称',
`activity_type` STRING COMMENT '活动类型',
`start_time` STRING COMMENT '开始时间',
`end_time` STRING COMMENT '结束时间',
`rule_desc` STRING COMMENT '规则描述'
) COMMENT '活动维度表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dim/dim_activity_full/'
TBLPROPERTIES ('orc.compress'='snappy');
```

#### 首日装载

```sql
use gmall;

insert overwrite table dim_activity_full partition(dt='2022-06-08')
select
    info.id as activity_id,
    info.activity_name,
    info.activity_type,
    info.start_time,
    info.end_time,
    rule.rule_desc
from ods_activity_info_full info
left join ods_activity_rule_full rule on info.id = rule.activity_id
where info.dt='2022-06-08';
```

#### 每日装载

```sql
-- 全量覆盖，逻辑同首日
insert overwrite table dim_activity_full partition(dt='2022-06-09')
select ... -- from ods_activity_info_full where dt='2022-06-09'
```

---

## 三、核心考点汇总

| 考点 | 答案 |
|---|---|
| 为什么要有DIM层 | 把维度数据整理好，避免上层重复join，做维度退化 |
| 拉链表是什么 | 用start_date和end_date标记每条记录生效时间，保存维度历史 |
| 为什么用拉链表不用全量快照 | 全量快照每天存一份全量太浪费空间，拉链表只存变化 |
| 拉链表怎么查历史 | 找 start_date <= 要查的日期 and end_date > 要查的日期 |
| 维度退化是什么意思 | 小维度不单独建表，直接冗余到事实表里，减少join |
| DIM层为什么用ORC | 维度表经常全表扫描做join，ORC列存压缩率高、查询快 |
| 敏感数据怎么处理 | 手机号中间打星、姓名只留姓、邮箱域名保留 |
| 静态维度表是什么 | 日期表这种提前造好、不随业务变化的维度表 |
