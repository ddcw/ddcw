# 说明

**MysqlDumpSplitSQL.py** MySQL导出文件拆分脚本. 支持5.7/8.0

**testparallel.sh** MySQL并发导入脚本



# 使用方法

1. 导出MySQL数据(可选)

   ```shell
   mysqldump --events --triggers --single-transaction --routines --master-data=2 -A > t20240227_alldb.sql
   ```

2. 拆分导出文件

   ```shell
   python MysqlDumpSplitSQL.py t20240227_alldb.sql
   ```

3. 并发导入

   修改testparallel.sh设置`并发数量`, `mysql连接命令`

   然后执行如下命令开始导入:

   ```shell
   sh testparallel.sh splitByddcw_20240228_143913
   ```

   注: splitByddcw_20240228_143913 为第二步生成的文件

   目前并发数量建议为4.  如果数据量较小, 或者某张大表占比太大, 则效率可能不佳.



# 测试数据说明

```
数据大小
	t20240227_alldb.sql   	1.7GB
	db1.ddcw2023_1   		547MB   #太大了, 耗时为: 170 s
	


直接使用mysql导入:
		4m47.697s


使用脚本拆分后导入:
拆分耗时:
time python MysqlDumpSplitSQL.py t20240227_alldb.sql
real	0m5.272s
user	0m1.886s
sys		0m3.375s

导入:
4并发:  3m25.275s
8并发:  3m12.074s
16并发: 3m12.133s
```



# 导入前后数据校验方法

```shell
导入前数据校验:
mysql -h127.0.0.1 -P3314 -p123456 -NB -e "select concat('CHECKSUM TABLE \`',TABLE_SCHEMA,'\`.\`',TABLE_NAME,'\`;') FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA NOT IN('sys','mysql','information_schema','performance_schema');" | sort  | mysql -h127.0.0.1 -P3314 -p123456  > /tmp/before_check.txt

导入后数据校验:
mysql -h127.0.0.1 -P3314 -p123456 -NB -e "select concat('CHECKSUM TABLE \`',TABLE_SCHEMA,'\`.\`',TABLE_NAME,'\`;') FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA NOT IN('sys','mysql','information_schema','performance_schema');" | sort | mysql -h127.0.0.1 -P3314 -p123456  > /tmp/after_check.txt

前后数据比较
diff /tmp/before_check.txt /tmp/after_check.txt
```

