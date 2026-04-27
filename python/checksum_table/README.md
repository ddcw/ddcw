# 校验原理
查询所有数据行, 对每行做crc32,并求和.
目前只实现了mysql数据库的校验

# 使用方法
```shell
-- 校验指定表
python3 CHECKSUM_TABLE_MYSQL.py -h127.0.0.1 -P5744 -p123456 --databases db1 --table t20260427_01

-- 校验某个库的所有表
python3 CHECKSUM_TABLE_MYSQL.py -h127.0.0.1 -P5744 -p123456 --databases db1 
```
