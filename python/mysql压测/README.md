# 工具介绍

参考的sysbench, 只不过是用python3写的, 目前只支持mysql, (其它类型数据库自己改一改就可以了)

只读事务  18个select

只写事务 2update + 1delete + 1insert

读写 = 只写+只读



# 用法

```shell
python3 ddcw_bench.py  --password 123456 -d testdb2 prepare #初始化数据
python3 ddcw_bench.py  --password 123456 -d testdb2 run  #压测
python3 ddcw_bench.py  --password 123456 -d testdb2 cleanup #清理数据
```



# 参数说明

--host  指定mysql服务器

--port  指定mysql服务器端口

--user  指定mysql用户名

--password 指定mysql用户的密码

--db-name  指定mysql服务器数据库名

--table-count  指定表的数量

--table-name 指定表的名字

--table-rows 每张表多少行数据

--insert-per-commit 每次insert多少数据

--no-log  初始化数据的时候, 不写日志(我后面忘了这个功能,就没写... 可以自己加 set sql_log_bin=0;)

--report-interval  多少秒显示一次信息

--thread  并发数量

--run-time 运行时间

--mode  0表示读写混合   1表示只读  2表示只写

prepare|run|cleanup    prepare初始化数据  run运行压测  cleanup清除数据



# 支持:

mysql5.7/8.0



