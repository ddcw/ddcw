# 用法:
和pymysql一样的用法, 丐版pymysql. 为inspection&ei做准备
```python
import pymysql
conn = pymysql.connect(
	host='192.168.101.21',
	port=3314,
	user='root',
	password='123456',
	)

cursor = conn.cursor()
cursor.execute('select "ddcw"')
cursor.fetchall()
```

# 例子

```shell
17:11:34 [root@ddcw21 tmp]#python3
Python 3.10.4 (main, May 11 2022, 13:58:32) [GCC 4.8.5 20150623 (Red Hat 4.8.5-44)] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import pymysql
>>> conn = pymysql.connect(
...     host='192.168.101.21',
...     port=3314,
...     user='root',
...     password='123456',
...     )
>>> 
>>> cursor = conn.cursor()
>>> cursor.execute('select "ddcw"')
>>> cursor.fetchall()
[['ddcw']]
>>> 

>>> 
```
