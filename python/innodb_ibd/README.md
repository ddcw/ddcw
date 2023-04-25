详情: https://cloud.tencent.com/developer/article/2270548

# 提取DDL和DML
```python
import innodb_index
filename = '/data/mysql_3314/mysqldata/db1/t20230424_666.ibd'
page_size = 16384
aa = innodb_index.rec_data_cluster(filename)
for x in aa[:10]:
    print(x)
```

# 提取DDL(推荐)
```python
import innodb_sdi
aa = innodb_sdi.sdi('/data/mysql_3314/mysqldata/db1/ddcw_benchmark__12.ibd')
print(aa.get_ddl())

```
