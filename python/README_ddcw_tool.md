ddcw_tool是集成了一些常用功能, 主要是数据库方向的



# CLASS

## mysql

连接mysql的. 使用的pymysql

使用例子:

```python
import ddcw_tool
mysql = ddcw_tool.mysql(host='192.168.101.19',port=3306,password='123456')
mysql.conn()
mysql.sql('show databases') #提交和回滚需要自己commit/rollback
```

支持的方法如下:

conn() #连接

sql() #执行SQL

get_conn 返回一个连接

get_tps_qps 返回一个生成器, (tps,qps)

get_max_tables 返回最大的n张表

get_max_dbs 返回最大的N个库

get_same_user_password 返回账号密码相同的用户. 仅mysql_native_password

get_sample_user_password 返回密码过于简单的用户

get_nopk_table 返回没有主键的表

get_big_table 返回大表

get_fragment_table 返回碎片表





## ssh

使用ssh连接linux操作系统的. 依赖paramiko

使用例子:

```python
import ddcw_tool
ssh = ddcw_tool.ssh(host='192.168.101.19',password='123456')
ssh.conn()
ssh.command('whoami') #exit_code,stdout,stderr
```

支持的方法:

cpu

mem

disk

fs

get_proc_by_mem  返回使用内存最多的线程信息

get_proc_by_cpu 返回使用CPU最多的线程信息

get_net_rate 返回生成器(Receive,Transmit)

stop_firewall 停止防火墙

close_selinux 关闭selinux

virtual 判断是否是虚拟机



## localcmd

使用本地shell的

例子:

```python
import ddcw_tool
cmd = ddcw_tool.localcmd()
cmd.command('whoami')
```

支持的方法和ssh一样.



## sftp

连接ssh的, 主要是上传下载文件

使用例子:

```python
import ddcw_tool
sftp = ddcw_tool.sftp(host='192.168.101.19',password='123456')
sftp.conn()
sftp.put('localfilename','remote_filename')
sftp.get('remotefile','localfile')
```



## oracle

使用cx_oracle连接oracle

例子:

```python
import ddcw_tool
oracle = ddcw_tool.oracle(host='192.168.101.19',password='123456',servicename='ddcw19pdb')
oracle.conn()
oracle.sql('select * from t1') #小坑.结尾不能加分号(;)
```



## postgres

使用psycopg2连接postgres的

例子:

```python
import ddcw_tool
postgres = ddcw_tool.postgres(host='192.168.101.19',password='123456')
postgres.conn()
postgres.sql('select * from t1')
```



## benchmark_mysql

压测Mysql的, 继承的ddcw_tool.mysql.  模拟数据使用的是fake.

参考的 sysbench.

只读: 10主键读 +  4范围读

只写:  2update + 1delete + 1insert

读写混合: 只读+只写

使用例子:

```python
import ddcw_tool
test = ddcw_tool.benchmark_mysql(host='192.168.101.19',password='123456',database='db1')
test.prepare()  #初始化数据(可选)
test.run() #开始压测
test.cleanup() #清理数据(可选)
```



## benchmark_oracle

同benchmark_mysql



## benchmark_postgres

同benchmark_mysql (不显示tps,qps)



## costcpu

模拟CPU使用的.

例子:

```python
import ddcw_tool
test = ddcw_tool.costcpu(4)  #4进程
test.start() #开始占用CPU
test.stop() #停止占用, 释放资源
```



## costmem

模拟内存占用的

例子

```python
import ddcw_tool
test = ddcw_tool.costmem(2*1024*1024*1024)  #2GB内存
test.start() #开始占用CPU
test.stop() #停止占用, 释放资源
```

注: 可以使用 `ddcw_tool.localcmd().get_proc_by_mem()` 查看内存使用排行, 单位默认是KB



## remote_yaml

读取远程的yaml, 修改完成后,再上传回去

例子:

```python
import ddcw_tool
remote_yaml = ddcw_tool.remote_yaml(remote_file='/tmp/aaa.yaml')
print(remote_yaml.data) #这就是要修改的数据
remote_yaml.save() #保存并上传到远程服务器
remote_yaml.close() #断开连接. 不保存上传.
```



## mysql_ms

mysql主从切换的. 需要给出所有从库信息(不给的不参与选主,和执行change master)

主库信息可以不用给, 能自动识别

例子:

```python
import ddcw_tool
slave1 = ddcw_tool.mysql(port=3308,password='123456',user='repl')
slave2 = ddcw_tool.mysql(port=3310,password='123456',user='repl')
mysql_ms = ddcw_tool.mysql_ms(slave1,slave2)
mysql_ms.conn() #连接主从节点, 并获取相关信息.
mysql_ms.master #主库信息
mysql_ms.slave #从库信息
mysql_ms.switch() 主从切换
```



## mysql_set_ms

设置mysql主从.(数据初始化要自己做)

TODO



## mysql_install

安装mysql的

例子

```python
import ddcw_tool
mysql = ddcw_tool.mysql(host='192.168.101.19',port=3306,password='123456')
ssh = ddcw_tool.ssh(host='192.168.101.19',password='Ddcw@123.')
aa = ddcw_tool.mysql_install(mysql=mysql,ssh=ssh,cnf='mysql_template.cnf',local_pack='/root/mysql-5.7.41-linux-glibc2.12-x86_64.tar.gz')
aa.init() #初始化, 主要是相关参数设置 
#aa.cnf['mysqld'] #参数修改,可选
aa.auto_install() #自动安装.
```

自动安装步骤:

self.init() #初始化参数

self.env_set() 环境设置

self.transfile([(self.local_pack,self.remote_pack)]) #上传软件包

self.env_check() #环境检测

self.install_base() #解压二进制包

self.install_init() #数据库初始化

self.post_start() #启动mysqld

self.post_user() #设置root@localhost密码  self.mysql.password

self.post_create_user(mysql_cmd) #创建新用户

self.post_grant_user(mysql_cmd) #新用户授权

self.post_start_stop_script() #设置启停脚本

self.post_backup_script() #设置备份脚本



参数设置 除了直接修改 self.cnf['mysqld']之外, 还可以使用如下方法修改

set_basedir

set_cnfdir

set_datadir

set_logdir

set_rundir



# FUNCTION

## read_yaml

```python
test = ddcw_tool.read_yaml('ei.yaml') #返回的是dict
```



## save_yaml

```python
test = ddcw_tool.read_yaml('ei.yaml')
ddcw_tool.save_yaml(filename,test)
```



## read_conf

```python
test = ddcw_tool.read_conf('mysql_template.cnf')
```



## read_conf_template

读取配置文件, 返回已经模板处理过的数据

```python
cnf = ddcw_tool.read_conf_template(filename,dict_data)
```



## save_conf

```python
ddcw_tool.save_conf(filename,cnf_dict)
```



## sendpack_tcp

```python
ddcw_tool.sendpack_tcp('192.168.101.19',3306,b'how are you')
```



## getlog

```python
log = ddcw_tool.getlog(filename)
```



## file_abs

```python
ddcw_tool.file_abs('/tmp/aa.txt')
```



## file_dir

```python
ddcw_tool.file_dir('/tmp/aa.txt')
```



## file_name

```python
ddcw_tool.file_name('/tmp/aa.txt')
```



## encrypt

```python
test = ddcw_tool.encrypt('aa')
```



## decrypt

```python
test = ddcw_tool.encrypt('aa')
ddcw_tool.decrypt(test)
```



## scanport

测试TCP端口是否打开. 返回打开的端口

```python
ddcw_tool.scanport() #扫描本机所有端口
ddcw_tool.scanport('192.168.101.21') #扫描指定IP的所有端口
ddcw_tool.scanport('192.168.101.21',22) #扫描指定IP的指定端口
ddcw_tool.scanport('192.168.101.21',22,10000) #扫描指定IP的指定范围的端口
```

