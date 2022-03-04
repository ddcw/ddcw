SOURCE --> KAFKA --> TARGET



# 计划支持的数据库

| 数据库    | 是否支持 |
| ------ | ---- |
| MYSQL  |      |
| ORACLE |      |
| PG     |      |



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



# 使用说明

配置 conf.cnf 文件 (文件名是固定的)

启动生产者(抽取数据的进程, 目前只支持mysql)

```shell
python producer.py
```

启动消费者(目前只是打印SQL到屏幕上)

```shell
python consumer.py
```

