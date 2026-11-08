# ADS 应用层

---

## 一、ADS层基本知识

### 1. 职责

ADS（Application Data Service）应用数据服务层，是数仓最顶层，直接对接BI报表和业务系统。

做的事：
1. 从DWS汇总表取数，生成最终报表指标
2. 多维度组合（渠道×周期、用户×品牌、品类×SKU）
3. 导出到MySQL，供报表平台查询

### 2. 特点

| 特点 | 说明 |
|---|---|
| 存储格式 | TextFile行存，Tab分隔 |
| 为什么不用ORC | 数据量小，且要导出到MySQL做报表，纯文本方便load data infile导入 |
| 分区策略 | 不分区，dt为普通字段，每次union全量重写 |
| 数据来源 | 全部来自DWS层汇总表，不再扫明细 |

### 3. 为什么用union而不是分区

1. ADS表数据量极小（几千几万行），分区意义不大
2. 报表要按时间范围查询（比如最近30天），全表扫也很快
3. 每天跑的时候把历史数据+今天新数据union一下写回，保证幂等

### 4. 装载特点

- 首日：直接insert into，初始化全量数据
- 每日：历史数据 union all 今天新数据，insert overwrite全表覆盖

### 5. 核心技术点

- **lateral view explode炸裂**：一行炸成多行，一次算多个周期（1天/7天/30天）指标
- **lead()窗口函数**：取当前行下面第N行的值，用于页面路径、连续N天统计
- **rank() TopN**：按分组取前N名

---

## 二、表明细

---

### ads_traffic_stats_by_channel（各渠道流量统计）

| 项 | 内容 |
|---|---|
| 表名 | ads_traffic_stats_by_channel |
| 粒度 | 渠道×统计周期 |
| 来源 | dws_traffic_session_page_view_1d |
| 核心技术 | lateral view explode炸裂 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ads_traffic_stats_by_channel;
CREATE EXTERNAL TABLE ads_traffic_stats_by_channel
(
`dt` STRING COMMENT '统计日期',
`recent_days` BIGINT COMMENT '最近天数：1/7/30',
`channel` STRING COMMENT '渠道',
`uv_count` BIGINT COMMENT '访客数',
`avg_duration_sec` DECIMAL(16,2) COMMENT '平均停留时长（秒）',
`avg_page_count` DECIMAL(16,2) COMMENT '平均页面数',
`sv_count` BIGINT COMMENT '会话数',
`bounce_rate` DECIMAL(16,2) COMMENT '跳出率（%）'
) COMMENT '各渠道流量统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_traffic_stats_by_channel/';
```

#### 首日装载

```sql
use gmall;

insert overwrite table ads_traffic_stats_by_channel
select
    '2022-06-08' as dt,
    recent_days,
    channel,
    count(distinct mid_id) as uv_count,
    round(avg(during_time)/1000, 2) as avg_duration_sec,
    round(avg(page_count), 2) as avg_page_count,
    count(*) as sv_count,
    round(sum(if(page_count = 1, 1, 0))/count(*)*100, 2) as bounce_rate
from dws_traffic_session_page_view_1d
lateral view explode(array(1, 7, 30)) tmp as recent_days
where dt >= date_add('2022-06-08', -recent_days + 1)
group by recent_days, channel;
```

#### 每日装载

```sql
-- 历史数据 union all 今天新数据，全量重写
insert overwrite table ads_traffic_stats_by_channel
select * from ads_traffic_stats_by_channel
union
select '2022-06-09' as dt, recent_days, channel, ... from dws_traffic_session_page_view_1d
where dt >= date_add('2022-06-09', -recent_days + 1)
group by recent_days, channel;
```

---

### ads_page_path（页面浏览路径分析）

| 项 | 内容 |
|---|---|
| 表名 | ads_page_path |
| 粒度 | 页面跳转路径 |
| 来源 | dwd_traffic_page_view_inc |
| 核心技术 | lead()窗口函数 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ads_page_path;
CREATE EXTERNAL TABLE ads_page_path
(
`dt` STRING COMMENT '统计日期',
`source` STRING COMMENT '跳转来源页面',
`target` STRING COMMENT '跳转目标页面',
`path_count` BIGINT COMMENT '路径次数'
) COMMENT '页面路径分析'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_page_path/';
```

#### 首日装载

```sql
use gmall;

insert overwrite table ads_page_path
select
    '2022-06-08' as dt,
    concat('step-', rn, '-', page_id) as source,
    concat('step-', rn+1, '-', next_page) as target,
    count(*) as path_count
from (
    select
        mid_id, user_id, page_id, view_time,
        lead(page_id, 1, null) over(partition by session_id order by view_time) as next_page,
        row_number() over(partition by session_id order by view_time) as rn
    from dwd_traffic_page_view_inc
    where dt = '2022-06-08'
) t
where next_page is not null
group by page_id, next_page, rn;
```

---

### ads_user_change（用户变动统计：流失+回流）

| 项 | 内容 |
|---|---|
| 表名 | ads_user_change |
| 粒度 | 天 |
| 来源 | dws_user_user_login_td |
| 核心指标 | 流失用户数、回流用户数 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ads_user_change;
CREATE EXTERNAL TABLE ads_user_change
(
`dt` STRING COMMENT '统计日期',
`churn_count` BIGINT COMMENT '流失用户数',
`return_count` BIGINT COMMENT '回流用户数'
) COMMENT '用户变动统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_user_change/';
```

#### 首日装载

```sql
use gmall;

insert overwrite table ads_user_change
select
    '2022-06-08' as dt,
    -- 流失：连续7天没登录，且刚好第7天
    sum(if(login_date_last = date_sub('2022-06-08', 7), 1, 0)) as churn_count,
    0 as return_count  -- 首日没有历史数据，回流为0
from dws_user_user_login_td
where dt = '2022-06-08';
```

---

### ads_user_retention（用户留存率）⭐ 面试必考题

| 项 | 内容 |
|---|---|
| 表名 | ads_user_retention |
| 粒度 | 新增日期×留存天数 |
| 来源 | dws_user_user_login_td |
| 核心逻辑 | 按注册日期分组，算每组今天还有多少人登录 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ads_user_retention;
CREATE EXTERNAL TABLE ads_user_retention
(
`dt` STRING COMMENT '统计日期',
`create_date` STRING COMMENT '用户新增日期',
`retention_day` BIGINT COMMENT '留存天数',
`retention_count` BIGINT COMMENT '留存用户数',
`new_user_count` BIGINT COMMENT '新增用户数',
`retention_rate` DECIMAL(16,2) COMMENT '留存率（%）'
) COMMENT '用户留存率'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_user_retention/';
```

#### 什么是留存率

某天新增的用户，过了N天之后还回来登录的比例。
比如6月8号新增了100个用户，到6月10号还有20个登录了，那2日留存率就是20%。

#### 首日装载

```sql
use gmall;

insert overwrite table ads_user_retention
select
    '2022-06-08' as dt,
    login_date_first as create_date,
    datediff('2022-06-08', login_date_first) as retention_day,
    count(*) as retention_count,
    count(*) as new_user_count,
    100.00 as retention_rate
from dws_user_user_login_td
where dt = '2022-06-08'
group by login_date_first;
```

为什么排除今天注册的？今天刚注册，还没有"过几天"的后续数据，算不了留存。

---

### ads_user_stats（用户新增活跃统计）

| 项 | 内容 |
|---|---|
| 表名 | ads_user_stats |
| 粒度 | 统计周期 |
| 来源 | dws_user_user_login_td |
| 核心技术 | lateral view explode炸裂 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ads_user_stats;
CREATE EXTERNAL TABLE ads_user_stats
(
`dt` STRING COMMENT '统计日期',
`recent_days` BIGINT COMMENT '最近天数：1/7/30',
`new_user_count` BIGINT COMMENT '新增用户数',
`active_user_count` BIGINT COMMENT '活跃用户数'
) COMMENT '用户新增活跃统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_user_stats/';
```

#### 首日装载

```sql
use gmall;

insert overwrite table ads_user_stats
select
    '2022-06-08' as dt,
    recent_days,
    -- 新增：首次登录日期落在最近N天内
    sum(if(login_date_first >= date_add('2022-06-08', -recent_days+1), 1, 0)) as new_user_count,
    -- 活跃：最近N天登录过的总人数
    count(*) as active_user_count
from dws_user_user_login_td
lateral view explode(array(1, 7, 30)) tmp as recent_days
where dt = '2022-06-08'
group by recent_days;
```

---

### ads_user_action（用户行为漏斗分析）

| 项 | 内容 |
|---|---|
| 表名 | ads_user_action |
| 粒度 | 天 |
| 来源 | 4张DWS 1d表join |
| 核心指标 | 首页→详情→加购→下单→支付 各阶段人数 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ads_user_action;
CREATE EXTERNAL TABLE ads_user_action
(
`dt` STRING COMMENT '统计日期',
`home_count` BIGINT COMMENT '首页访问人数',
`detail_count` BIGINT COMMENT '详情页访问人数',
`cart_count` BIGINT COMMENT '加购人数',
`order_count` BIGINT COMMENT '下单人数',
`payment_count` BIGINT COMMENT '支付人数'
) COMMENT '用户行为漏斗分析'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_user_action/';
```

---

### ads_new_order_user_stats（新增下单用户统计）

| 项 | 内容 |
|---|---|
| 表名 | ads_new_order_user_stats |
| 粒度 | 统计周期 |
| 来源 | dws_trade_user_order_td |
| 核心技术 | lateral view explode炸裂 |

#### 建表语句

```sql
use gmall;

DROP TABLE IF EXISTS ads_new_order_user_stats;
CREATE EXTERNAL TABLE ads_new_order_user_stats
(
`dt` STRING COMMENT '统计日期',
`recent_days` BIGINT COMMENT '最近天数：1/7/30',
`new_order_user_count` BIGINT COMMENT '新增下单用户数'
) COMMENT '新增下单用户统计'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/ads/ads_new_order_user_stats/';
```

---

### ads_order_continuously_user_count（连续3日下单用户数）⭐

| 项 | 内容 |
|---|---|
| 表名 | ads_order_continuously_user_count |
| 粒度 | 天 |
| 来源 | dws_trade_user_order_1d |
| 核心技术 | lead()窗口函数 |

#### 核心逻辑

- 按用户分区，日期升序排列
- lead(dt, 2)取后两行的日期
- datediff(后两行日期, 当前日期) = 2 → 连续3天下单
- count(distinct user_id)去重

```sql
select
    '2022-06-08' as dt,
    count(distinct user_id) as continuous_count
from (
    select
        user_id, dt,
        lead(dt, 2, '9999-12-31') over(partition by user_id order by dt) as dt2
    from dws_trade_user_order_1d
    where dt <= '2022-06-08'
) t
where datediff(dt2, dt) = 2;
```

---

### ads_repeat_purchase_by_tm（品牌复购率）

| 项 | 内容 |
|---|---|
| 表名 | ads_repeat_purchase_by_tm |
| 粒度 | 品牌 |
| 来源 | dws_trade_user_sku_order_nd |
| 核心指标 | 复购率 = 下单>=2次的用户数 / 下单>=1次的用户数 |

#### 核心逻辑

1. 先按用户+品牌汇总总下单次数
2. 再按品牌分组，数一下多少人买过（>=1次），多少人买过两次以上（>=2次）
3. 两个数相除就是复购率

---

### ads_order_stats_by_tm（品牌交易统计）

| 项 | 内容 |
|---|---|
| 表名 | ads_order_stats_by_tm |
| 粒度 | 品牌×统计周期 |
| 来源 | dws_trade_user_sku_order_1d + nd |

#### 核心逻辑

- 1天从1d表取
- 7天/30天从nd表炸成两份取
- sum订单数，count(distinct user_id)下单人数

---

### ads_order_stats_by_cate（品类交易统计）

跟上一张品牌交易统计一模一样，分组字段换成三级品类。

---

### ads_sku_cart_num_top3_by_cate（品类加购Top3）

| 项 | 内容 |
|---|---|
| 表名 | ads_sku_cart_num_top3_by_cate |
| 粒度 | 品类×SKU |
| 来源 | dwd_trade_cart_full + dim_sku_full |
| 核心技术 | rank()窗口函数取TopN |

#### 核心逻辑

1. 先从购物车全量表算每个SKU总加购数
2. 关联维度表拿品类信息
3. 按品类分区，加购数降序排名
4. where rk<=3取每个品类前3名

---

### ads_sku_favor_count_top3_by_tm（品牌收藏Top3）

跟上一张品类Top3一模一样，直接从DWS收藏1d表取，按品牌分组排名取前3。

---

### ads_order_to_pay_interval_avg（下单到支付平均时长）

| 项 | 内容 |
|---|---|
| 表名 | ads_order_to_pay_interval_avg |
| 粒度 | 天 |
| 来源 | dwd_trade_trade_flow_acc（累计快照表） |

#### 核心逻辑

- 累计快照表里同时有下单时间和支付时间
- 直接avg(payment_time - order_time)

---

### ads_order_by_province（省份交易统计）

跟品牌、品类交易统计一样，分组字段换成省份，1d+nd炸裂。

---

### ads_coupon_stats（优惠券使用统计）

最简单的一张，从DWS优惠券使用1d表按优惠券分组sum就行。

---

## 三、核心考点汇总

| 考点 | 答案 |
|---|---|
| lateral view explode干嘛的 | 把一行炸裂成多行，一次算多个周期指标，不用写三遍SQL |
| ADS为什么用TextFile不用ORC | 数据量小，且要导出MySQL，纯文本方便导入 |
| ADS为什么不分区用union | 数据量小，每次全量重写保证幂等 |
| 流失用户怎么定义 | 连续7天没登录，且刚好第7天（避免重复统计） |
| 回流用户怎么定义 | 今天登录了，但距上次登录间隔>=8天 |
| 什么是留存率 | 某天新增的用户，过了N天还回来登录的比例 |
| lead()函数干嘛的 | 取当前行下面第N行的值，用来找下一个页面 |
| 留存率为什么排除今天注册 | 今天刚注册，还没有后续登录数据，算不了 |
| 连续N天下单怎么算 | lead取后N-1行日期，日期差=N-1就是连续N天 |
| 复购率怎么算 | 买过2次以上的用户数 / 买过至少1次的用户数 |
| 分组TopN怎么写 | rank() over(partition by 分组 order by 指标 desc)，where rk<=N |
| nd表炸裂后为什么要加if(order_count>0) | nd表是30天窗口，7天没下单但30天下单的用户order_count_7d=0，要踢掉 |

---

> 
