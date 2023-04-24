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
