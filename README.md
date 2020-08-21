# ddcw
only for manage script at ./*shells
and packet shells

## conf
for ddcw config, ddcw.conf define variable for other script , default.conf is default configure doc, change by release.  
conf/ddcw.conf 定义了一些常规变量,为了方便其他脚本执行, conf/default.conf是默认的配置,只和版本有关.  

## install_shells
only install_script, such as ZK_PseudoCluster_install.sh to install Zookeeper,  
install_shells目录下面的脚本都是安装类型的脚本,这里的脚本会按照conf/ddcw.conf里面定义的变量去执行  
比如定义默认安装路径BASE_INSTALL_DIR="/usr/local"   开机自启ONBOOT=1  

## man
some of shell command has Help documentation   
有些命令可以使用帮助文档,比如 man ddcw  

## readme
mayby shell script has readme  
保留的,感觉没得用处....  

## shells
main shells will copy to /usr/bin and chmod +x shells/  
这里的脚本会被拷贝到 /usr/bin下面去, 比如ddcw  scanportDDCW  


# DETAILS
- scanportDDCW:  
扫描主机端口的,默认本机(0.0.0.0),默认所有端口,time参数表示间隔多少秒扫描一次  
  ``` shell
  scanportDDCW [ip IPV4_ADDR] [port PORT] [time TIME_INTERVAL]
  scanportDDCW ip 127.0.0.1 port 1521 time 1 
    ```

- CheckCommDDCW:  
校验当前用户拥有的命令的MD5,具体的用法我也忘了,可以看看:https://cloud.tencent.com/developer/article/1597040  
  ``` shell
 	CheckCommDDCW [PARAMETER]
  ```
  
- CheckOracleENV_19c:  
这个用法比较简单,和11g,12C一样的用法,直接执行就行,然后会给出建议脚本(/tmp/CheckOracleENV_19c/fixup_by_ddcw.sh),查看该脚本,没问题的话,就直接跑,多跑两边.  
  ``` shell
  CheckOracleENV_19c
  [[ -f /tmp/CheckOracleENV_19c/fixup_by_ddcw.sh ]] && sh /tmp/CheckOracleENV_19c/fixup_by_ddcw.sh
  ```
  
- sshNopasswd:  
配置ssh免密登录的,也就是把自己的公钥拷贝到目标用户的.ssh/authorized_keys 文件  
具体的用法我也忘了... https://cloud.tencent.com/developer/article/1612304  
  ``` shell
         sshNopasswd  [用户名@]主机名[:端口]  [密码]
  ```

- net_rates.sh  
测试网速的脚本. 使用方法:sh net_rates.sh [网速限制(单位:字节)]  
  ``` shell
	#网速低于40 b/s 的就不显示.
	sh net_rates.sh 40
  ```

  
- ZK_PseudoCluster_install.sh:  
安装zookeeper伪集群的,默认端口是218+node 比如2181 2182 2183 这样子的,目前版本不支持参数  
  ``` shell
        /usr/local/ddcw/install_shells/ZK_PseudoCluster_install.sh 
  ```

  
- kafka_PseudoCluster.sh  
安装kafka集群,要依赖于zookeeper的,可以先跑ZK_PseudoCluster_install.sh脚本,目前版本也不支持参数  
  ``` shell
        /usr/local/ddcw/install_shells/kafka_PseudoCluster.sh
  ```

  
- oracle19c_install_2.2.sh  
安装oracle19c单机的脚本,用法基本上和11g,12c的安装脚本一样,也得先跑CheckOracleENV_19c.sh设置环境的脚本  
  ``` shell
        /usr/local/ddcw/install_shells/oracle19c_install_2.2.sh [PARAMETERS]
	部分参数如下(sh oracle19c_install_2.2.sh -h 就可以列出当前的脚本的默认配置):
	sysPassword=
	systemPassword=
	pdbAdminPassword=
	DB_NAME=
	ORADATA=
	INVENTORY_LOCATION_DIR=
	pga_aggregate_target=
	sga_target=
	DBNAME=
	characterSet=
	rootpassword=
  ```

