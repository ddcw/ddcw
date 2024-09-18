# 介绍
提取mysql 8.0的mysql.ibd数据的. 要求在ibd2sql目录下使用

# 用法
```shell
python3 get_mysql_ibd.py /data/mysql_3314/mysqldata/mysql.ibd  > /tmp/t20240918.sql
或者
python get_mysql_ibd.py /data/mysql_3314/mysqldata/mysql.ibd | grep -v 'UNIQUE KEY `schema_id`' > /tmp/t20240918.sql  # 去掉唯一索引 不然ps.clone_status有重复的(就TM离谱)
```
