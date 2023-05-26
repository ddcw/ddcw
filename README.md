[旧版readme.md](https://github.com/ddcw/ddcw/blob/master/README_OLD.md)

# 介绍

主要使用**python**/shell写一些关于**mysql**和linux的常用工具. 

也会在[博客](https://cloud.tencent.com/developer/user/1130242)上分享相关例子.

部分觉得不错的工具也会出相关的[视频](https://space.bilibili.com/448260423)演示



# [ibd2sql](https://github.com/ddcw/ibd2sql)

解析mysql 8.0 的数据文件为sql语句. 用处不大...... 

离线解析ibd文件,支持生成DDL,支持查看被标记为delete的数据,仅支持常用数据类型. [详情](https://github.com/ddcw/ibd2sql)



# [inspection](https://github.com/ddcw/inspection)

mysql的巡检报告, 支持5.7/8.0,  支持shell采集数据.

支持常用环境(主从,pxc,mgr), 能自动识别集群关系, 能够生成**html**或者**word**版巡检报告. [详情](https://github.com/ddcw/inspection)



# [innodb_status](https://github.com/ddcw/innodb_status)

支持5.7/8.0查看`show engine innodb status` 信息. 基本上就是个翻译....

 `Total large memory allocated`为0, 不是本软件的锅, 是mysql8.0.27开始就是这样..... [详情](https://github.com/ddcw/innodb_status)



# [ddcw](https://github.com/ddcw/ddcw)

这个比较杂, 基本上就是一些小点的工具, 有部分我都忘了是干啥的了. 

- [mysql/oracle导出导入数据命令生成(html/js)](https://github.com/ddcw/ddcw/blob/master/html/GetImportExportCommand.html)
- [MYSQL安装脚本(shell)](https://github.com/ddcw/ddcw/blob/master/install_shells/MysqlInstallerByDDCW_ei_1.0.sh)
- [MYSQL日志清理脚本(shell)](https://github.com/ddcw/ddcw/blob/master/shells/MysqlClearLog.sh)
- [OPENSSL安装脚本(shell)](https://github.com/ddcw/ddcw/blob/master/install_shells/OpensslInstall.sh)
- [oracle 19C安装脚本(shell)](https://github.com/ddcw/ddcw/blob/master/install_shells/oracle19c_install_2.2.sh)
- [oracle 19c环境检查设置脚本(shell)](https://github.com/ddcw/ddcw/blob/master/shells/CheckOracleENV_19c.sh)
- [zookeeper伪集群安装脚本(shell)](https://github.com/ddcw/ddcw/blob/master/install_shells/ZK_PseudoCluster_install.sh)
- [kafka伪集群安装脚本(shell)](https://github.com/ddcw/ddcw/blob/master/install_shells/kafka_PseudoCluster.sh)
- [mysql备份恢复脚本(shell)](https://github.com/ddcw/ddcw/tree/master/shells/BackupRestoreMysqlByDDCW)
- [数据(O/M/P)校验脚本(python)](https://github.com/ddcw/ddcw/tree/master/shells/%E6%95%B0%E6%8D%AE%E6%A0%A1%E9%AA%8C)
- [配置YUM源脚本(shell)](https://github.com/ddcw/ddcw/blob/master/shells/autoconfig_YUM.sh)
- [查看文件占用小于记录值的脚本(shell)](https://github.com/ddcw/ddcw/blob/master/shells/dulsdiffddcw.sh)
- [查看本地端口和进程的脚本(shell)](https://github.com/ddcw/ddcw/blob/master/shells/getLocalPortProcess.sh)
- [查看本地监听TCP和UDP的脚本(shell)](https://github.com/ddcw/ddcw/blob/master/shells/getTCPorUDP.sh)
- [高亮显示(shell)](https://github.com/ddcw/ddcw/blob/master/shells/grepDDCW.sh)
- [设置linux登录提示信息(shell)](https://github.com/ddcw/ddcw/blob/master/shells/login.sh)
- [binlog备份脚本(shell)](https://github.com/ddcw/ddcw/blob/master/shells/mysqlBinlogSYNC.sh)
- [查看linux网速脚本(shell)](https://github.com/ddcw/ddcw/blob/master/shells/net_rates.sh)
- [扫描端口脚本(shell)](https://github.com/ddcw/ddcw/blob/master/shells/scanportDDCW.sh)
- [配置ssh免密脚本(shell)](https://github.com/ddcw/ddcw/blob/master/shells/sshNopasswd)
- [mysql数据行数校验脚本(shell)](https://github.com/ddcw/ddcw/blob/master/shells/tableCheckSum.sh)
- [MYSQL ONLINE DDL脚本(python)](https://github.com/ddcw/ddcw/tree/master/python/mysql-onlineDDL)
- [MYSQL测脚本(python)](https://github.com/ddcw/ddcw/tree/master/python/mysql%E5%8E%8B%E6%B5%8B)
- [ORACLE压测脚本(python)](https://github.com/ddcw/ddcw/tree/master/python/oracle%E5%8E%8B%E6%B5%8B)
- [数据同步(M->M/O)脚本(python)](https://github.com/ddcw/ddcw/tree/master/python/%E6%95%B0%E6%8D%AE%E5%90%8C%E6%AD%A5)
- [mysql,linux常用工具ddcw_tool(python)](https://github.com/ddcw/ddcw/blob/master/python/ddcw_tool.py)
- [自制类tar工具(python)](https://github.com/ddcw/ddcw/blob/master/python/ddcw_tar.py)
- [sqlite3网络模块(python)](https://github.com/ddcw/ddcw/blob/master/python/sqlite3_net.py)
- [MYSQL读写分离脚本(python)](https://github.com/ddcw/ddcw/blob/master/python/mysql_rw.py)
- [MYSQL流量镜像(审计)脚本(python)](https://github.com/ddcw/ddcw/blob/master/python/mysql_monitor.py)
- [解析binlog得到DDL(python)](https://github.com/ddcw/ddcw/blob/master/python/getddl_frombinlog.py)
