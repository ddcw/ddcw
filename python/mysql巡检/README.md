# 项目介绍

数据库(含主机)巡检的

web_console.py  控制台操作

xunjian_analyze.py  分析巡检结果,生成巡检报告

mysql_inspection.py 巡检mysql附操作系统

postgresql_inspection.py  巡检pg附操作系统(计划中)

templates.html 巡检报告模板



# 支持范围

##系统

| 系统              | 是否支持 |
| --------------- | ---- |
| rhel/centos/oel | 支持   |
| ubuntu          | 支持   |
| windows         | 不支持  |

##数据库

| 数据库          | 是否支持 |
| ------------ | ---- |
| mysql5.7/8.0 | 支持   |
| pg           | 计划中  |
| oracle       | 不支持  |



# 巡检范围

操作系统

```
CPU 内存 文件系统 等
```



数据库

表.....



## 数据格式描述

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

2022.03.17  第一个版本