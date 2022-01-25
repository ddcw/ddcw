# 介绍

校验数据一致性的方法有很多,  可以 select md5(group_concat(id,name)) 计算hash值来判断, 也可以用第三方工具, 也可以自己写脚本

##原理: 

把数据查询出来, 使用 datacompy 比较数据

##支持:

mysql oracle postgresql等

##优点: 

简单, 自定义SQL(可以比较任意段的数据), 数据库压力小

##缺点: 

因为是把数据拉到客户端, 查询的数据量大了, 就会占用大量带宽



# 使用

```shell
pip install -r requirements.txt
```

然后修改db.ini文件, 把你自己的信息填上去


最后执行compareDB.py就行

```shell
python compareDB.py
```

