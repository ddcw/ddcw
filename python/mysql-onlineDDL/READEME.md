# 原理

1. 创建变更之后的表

2. 记录当前日志点, 并开始抽取日志(pymysqlreplication)

3. 把旧表的数据查询出来写入新表

4. 数据写完之后, 开始写这段时间变化的数据(日志)

5. 数据量小于5时, 停止抽取日志的进程, 并继续写剩下的几行数据

6. 数据全部写完之后,  交换旧表的名字和新表的名字

   ​



# 使用说明

--host HOST                 数据库服务器地址. default 127.0.0.1
--port PORT, -P PORT  数据库端口. default 3306
--user USER, -u USER  数据库用户
--password PASSWORD, -p PASSWORD 	 数据库密码
--db-name DBNAME, -D DBNAME		 数据库名字
--table-name TABLE_NAME, -t TABLE_NAME 表名字
--version, -v, -V     VERSION
--add-cols ADD_COLS, -a ADD_COLS   添加字段, 多个字段用,隔开(比如 id int,name varchar(20) )
--del-cols DEL_COLS, -d DEL_COLS     删除字段, 多个字段用,隔开(比如 id ,name )
--reset-cols RESET_COLS, -r RESET_COLS 重新设置某个(些)字段, 多个字段用,隔开(比如 id int ,name varchar(22) )
--lock-table-min-rows LOCK_TABLE_MIN_ROWS, -l LOCK_TABLE_MIN_ROWS 还剩多少行的时候就可以锁表了(默认5)
--no-log, -n      不记录日志(默认否, 就是要记录的意思, 不然主从里面, 主库变了, 从库没变....)





# 使用例子

新增字段aa,bb

```shell
./ddcw_osc --password 123456 -D db1 -t ddcw1 -a "aa int,bb varchar(20)"
```

删除字段aa,bb

```shell
./ddcw_osc --password 123456 -D db1 -t ddcw1 -d "aa,bb"
```

修改字段cc

```shell
./ddcw_osc --password 123456 -D db1 -t ddcw1 -r "cc varchar(222)"
```

删除字段aa,并添加字段bb

```shell
./ddcw_osc --password 123456 -D db1 -t ddcw1 -d "aa" -a "bb int"
```









# 特别说明

本脚本不打算维护, 因为mysql本来就支持在线DDL......