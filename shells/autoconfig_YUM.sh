#!/bin/env bash
#write by ddcw at 20201109
#图形化的, 我就不写man和用法了.^_^
#这个脚本主要是配置清华的镜像源, 支持base,epel,zabbix,mysql,elk,docker(不含docker仓库地址哦),jenkins

#判断dialog是否安装
if ! rpm -q dialog >/dev/null 2>&1
then
	echo "你要先安装dialog 命令参考: yum install dialog -y >/dev/null 2>&1"
	exit 1
fi

#定于全局标准错误文件描述符指向/tmp/.stderr_flag_ddcw
standerr_file=/tmp/.stderr_flag_ddcw
exec 2>${standerr_file}

#判断操作系统版本
OSV=$(awk -F . '{print $1}' /etc/system-release | awk '{print $NF}')

#清空标准错误文件函数
function clean_stderr() {
	cat /dev/null > ${standerr_file}	
}

#dialog的选项,每次执行函数前先清空标准错误文件
function YUM_LIST() {
	clean_stderr
	dialog --title "Please check which yum" --menu "Choose one" 20 80 20 \
1 "OS base" \
2 "OS EPEL" \
3 "ZABBIX" \
4 "MYSQL-5.7" \
5 "MYSQL-8.0" \
6 "DOCKER" \
7 "GRAFANA" \
8 "CEPH-15" \
9 "JenKins" \
10 "ELK" \
0 "LOCAL YUM" \
e "EXIT"
}

#根据用户选项配置相应的yum源, 本脚本主要针对国内的CENTOS系统, 所有选择的是清华的镜像源,毕竟速度杠杠的.
function config_yum() {
	case $1 in
		0)
		#配置本地yum源的功能我先不写,有兴趣的可以自己写.
		echo "hehe,此功能还未开发,you can visit https://cloud.tencent.com/developer/user/1130242"
		break;
		;;
		1)
		cat << EOF > /etc/yum.repos.d/baseByddcw.repo
[baseddcw]
name=qinghuayum base
enabled=1
gpgcheck=0
baseurl=http://mirror.tuna.tsinghua.edu.cn/centos/${OSV}/os/x86_64/
EOF
		;;
		2)
		cat << EOF > /etc/yum.repos.d/EPELByddcw.repo
[EPELddcw]
name=qinghuayum epel
enabled=1
gpgcheck=0
baseurl=http://mirror.tuna.tsinghua.edu.cn/epel/${OSV}/x86_64/
EOF
		;;
		3)
                cat << EOF > /etc/yum.repos.d/ZABBIXByddcw.repo
[ZABBIXddcw]
name=qinghuayum zabbix
enabled=1
gpgcheck=0
baseurl=http://mirror.tuna.tsinghua.edu.cn/zabbix/zabbix/5.0/rhel/${OSV}/x86_64/
EOF
		;;
		4)
                cat << EOF > /etc/yum.repos.d/MYSQL5.7Byddcw.repo
[MYSQL57ddcw]
name=qinghuayum mysql5.7
enabled=1
gpgcheck=0
baseurl=http://mirror.tuna.tsinghua.edu.cn/mysql/yum/mysql-5.7-community-el${OSV}-x86_64/
EOF
		;;
		5)
                cat << EOF > /etc/yum.repos.d/MYSQL8.0Byddcw.repo
[MYSQL80ddcw]
name=qinghuayum mysql8.0
enabled=1
gpgcheck=0
baseurl=http://mirror.tuna.tsinghua.edu.cn/mysql/yum/mysql-8.0-community-el${OSV}-x86_64/
EOF
		;;
		6)
                cat << EOF > /etc/yum.repos.d/dockerByddcw.repo
[dockerddcw]
name=qinghuayum docker
enabled=1
gpgcheck=0
baseurl=http://mirror.tuna.tsinghua.edu.cn/docker-ce/linux/centos/${OSV}/x86_64/stable/
EOF
		;;
		7)
                cat << EOF > /etc/yum.repos.d/grafanaByddcw.repo
[grafanaddcw]
name=qinghuayum grafana
enabled=1
gpgcheck=0
baseurl=http://mirror.tuna.tsinghua.edu.cn/grafana/yum/el${OSV}/
EOF
		;;
		8)
                cat << EOF > /etc/yum.repos.d/ceph15Byddcw.repo
[ceph15ddcw]
name=qinghuayum ceph
enabled=1
gpgcheck=0
baseurl=http://mirror.tuna.tsinghua.edu.cn/ceph/rpm-15.2.5/el${OSV}/x86_64/
EOF
		;;
		9)
                cat << EOF > /etc/yum.repos.d/jenkinsByddcw.repo
[jenkinsddcw]
name=qinghuayum jenkins
enabled=1
gpgcheck=0
baseurl=http://mirror.tuna.tsinghua.edu.cn/jenkins/redhat/
EOF
		;;
		10)
                cat << EOF > /etc/yum.repos.d/elasticsearchByddcw.repo
[elasticsearchddcw]
name=qinghuayum elasticsearch
enabled=1
gpgcheck=0
baseurl=http://mirror.tuna.tsinghua.edu.cn/ELK/yum/elasticsearch-2.x/
EOF
                cat << EOF > /etc/yum.repos.d/logstashByddcw.repo
[logstashddcw]
name=qinghuayum logstash
enabled=1
gpgcheck=0
baseurl=http://mirror.tuna.tsinghua.edu.cn/ELK/yum/logstash-5.0/
EOF
                cat << EOF > /etc/yum.repos.d/kibanaByddcw.repo
[kibanaddcw]
name=qinghuayum kibana
enabled=1
gpgcheck=0
baseurl=http://mirror.tuna.tsinghua.edu.cn/ELK/yum/kibana-4.6/
EOF
		;;
		e)
		break;
		;;
		*)
		echo "please visit https://cloud.tencent.com/developer/user/1130242"
		;;	
	esac
	echo "CONFIG FINISH, you should run  yum clean all && yum repolist"
}

#主函数,调用用户选择,然后把用户选择的选项传给配置函数.
function main_yum() {
	YUM_LIST
	config_yum $(cat ${standerr_file})	
}

main_yum

#清空标准错误文件.文件描述符只在这个脚本才生效,所有就不取消了.
rm -rf ${standerr_file}
