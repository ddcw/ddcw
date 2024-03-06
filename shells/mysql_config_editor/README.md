

# 介绍

**mysql_config_editor.sh** 是`mysql_config_editor`的shell版实现

mylogin.txt 格式如下

```
[root]
user = "root"
password = "123456"
socket = "/data/mysql_3314/run/mysql.sock"

[u2]
user = "u2"
password = "123456"
host = "192.168.101.21"
port = 3308

```





# 使用

## 加密

编辑文件`mylogin.txt`写入如下信息

```
[root]
user = "root"
password = "123456"
host = "127.0.0.1"
port = 3314
```



使用如下命令生成 `.mylogin.cnf`

```shell
sh mysql_config_editor.sh encode .mylogin.cnf mylogin.txt
```



验证

```shell
mysql --login-path=root -e "select @@version"
```





## 解密

使用如下命令即可解密`.mylogin.cnf `

```shell
sh mysql_config_editor.sh decode .mylogin.cnf
```



例子:

```shell
08:06:14 [root@ddcw21 ~]#sh mysql_config_editor.sh decode .mylogin.cnf mylogin.txt

[root]
user = "root"
password = "123456"
host = "127.0.0.1"
port = 3314


```

