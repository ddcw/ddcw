# 原理

producer 通过日志把数据抽取到 kafka.   partition 0 记录数据, partition1 记录当前的日志号

然后consumer把kafka里面的数据 拼接成sql 写入数据库.  并记录已写入的事务,方便下次继续.目前是每个事务都flush一次, 后面可以用参数控制(按时间, 事务数量, 系统自动刷新).



# 源端支持

| 数据库    | 是否支持 |
| ------ | ---- |
| MYSQL  | YES  |
| ORACLE | NO   |
| PG     | NO   |



# 目标端支持

| 数据库    | 是否支持 |
| ------ | ---- |
| MYSQL  | YES  |
| ORACLE | YES  |
| PG     | NO   |



# 功能

| 功能                 | 是否支持 |
| ------------------ | ---- |
| table/schema remap | YES  |
| extra col          |      |
| DDL                |      |
| 记录事务               |      |
| 数据类型自动转换           | 部分   |



# 支持的数据类型

| 数据类型 | 是否支持 |
| ---- | ---- |
| 字符串  | YES  |
| int  | YES  |
| date | YES  |



# TODO

并行写, 目前是不支持的. 

可以把主键和唯一索引做hash 映射到某个线程去执行, 这样涉及到相同的行的数据一定会在同一个线程上执行. 从而保障数据一致. 那么对于update是hash变化前的数据还是变化后的数据呢???





# 使用说明

配置 conf.cnf 文件 

启动生产者(抽取数据的进程, 目前只支持mysql)

```shell
python producer.py
```

启动消费者

```shell
python consumer.py
```



# #CHANGE LOG

2022.03.07  BY DDCW

​	NOTHING ...
