# 介绍
简单解析Undo文件的

# 用法
全量解析
```shell
python undo_reader.py python undo_reader.py /data/mysql_3314/mysqldata/undo_002
```
根据rollptr解析
```shell
python undo_reader.py /data/mysql_3314/mysqldata/undo_002 -r 562950864907130
```
