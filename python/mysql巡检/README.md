# 项目介绍

**已经单独成立项目了, 最新地址: https://github.com/ddcw/inspection**

巡检mysql的脚本

mysql_inspection 采集数据库信息(如果指定了主机的ssh信息或者是本机, 也会顺便采集主机信息), 支持远程采集.

xunjian_analyze  根据模板文件生成html报告的(默认是templates.html, 也可以 -t 指定)

templates.html 巡检报告模板,  可以随便改. 比如我建议的是RC隔离级别, 你也可以改为建议RR隔离级别.



# pyinstaller打包

```shell
pyinstaller -F mysql_inspection.py
pyinstaller -F xunjian_analyze.py
```



# 使用方法

```shell
mysql_inspection --host 127.0.0.1 -P 3332 -p 123456  #生成数据原始文件json
xunjian_analyze  xxx.json #分析并生成巡检报告
```





# 数据收集脚本 mysql_inspection

| 对象                                 | 范围             |
| ---------------------------------- | -------------- |
| mysql.user                         | 排除password字段   |
| information_schema.schemata        | 全部             |
| information_schema.tables          | 全部             |
| information_schema.COLUMNS         | 全部             |
| information_schema.VIEWS           | 这个目前还没分析       |
| information_schema.events          | 下个版本说不定就取消了.   |
| information_schema.PARTITIONS      | 我都忘了还收集了这张表... |
| information_schema.statistics      | 全部             |
| information_schema.USER_PRIVILEGES | 全部             |
| mysql.db                           | 全部             |
| show global status                 | 全部             |
| show global variables              | 全部             |
| SHOW ENGINE INNODB STATUS          | 全部             |
| SHOW BINARY LOGS                   | 全部             |
| performance_schema.threads         | 全部             |
| mysql.slave_master_info            | 全部             |
| mysql.slave_relay_log_info         | 全部             |
| mysql.slave_worker_info            | 全部             |
| show slave status                  | 全部             |
| information_schema.INNODB_TRX      | 全部             |
| sys.innodb_lock_waits              | 全部             |
| information_schema.PROCESSLIST     | 全部             |
| mysql.innodb_table_stats           | 全部             |
| mysql.innodb_index_stats           | 全部             |
| sys.statement_analysis             | 全部             |
| 操作系统: /proc/stat                   |                |
| 操作系统: lscpu                        |                |
| 操作系统: /etc/os-release              |                |
| 操作系统: /proc/sys/kernel/ostype      |                |
| 操作系统: /proc/uptime                 |                |
| 操作系统: df -PT                       | 注意是1024-blocks |
| 操作系统: /etc/localtime               |                |
| 操作系统: /var/log/dmesg               |                |
| 操作系统: /proc/meminfo                |                |



# 生成巡检报告 xunjian_analyze

巡检项如下:

- [基础参数](#base_parameter)
- [主机信息](#host_info)
- [主从信息](#master_slave_info)
- [数据库信息](#db_tables)
- [非Innodb表](#no_innodb)
- [无主键的表](#no_primary)
- [重复索引的表](#repeat_index)
- [没得索引的表](#no_index)
- [超过30天未跟新统计信息的表](#over30_statics)
- [超过100M碎片的表](#over100M_suipian)
- [任意主机都可登陆的用户](#any_host)
- [连接时间最长的10个用户](#top10_con)
- [执行次数前10的SQL](#top10_sql)
- [最大的前10张表](#top10_table)
- [TOP10 锁等待(锁)](#top10_lock)
- [所有插件](#all_plugin)
- [TOP20 慢日志](#top20_slow)
- [LASTET 20 错误日志](#latest_20_error_log)




# 数据格式描述

整体是一个JSON,  读取后就是dataframe

inspection_info["DBTYPE"]    数据库类型

inspection_info["HOST"]  数据库主机地址

inspection_info["AUTHOR"] 作者, 会显示在html titile

inspection_info["START_TIME"] 采集数据的时间

inspection_info["VERSION"] 采集数据的工具的版本, 0.2(不含)以下的是内测版本,未发布

inspection_info["DATA"]  数据库信息, 很多, 也是JSON的格式

inspection_info["HOST_INFO"] 主机信息, 很多, 也是JSON格式

```
inspection_info["HOST_INFO"]["HAVE_DATA"] 表示是否采集了主机信息
inspection_info["HOST_INFO"]["MYSQL_INFO"]  采集的MYSQL在操作系统上的相关信息
```









# CHANGELOG

2022.03.22  v0.2

可以指定模板文件, 增加右侧导航栏,  其它的我忘了....



2022.03.17   v0.11

第一个版本
