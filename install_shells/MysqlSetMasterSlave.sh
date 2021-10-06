#!/usr/bin/env bash
#write by ddcw at 2021.10.05

#使用方式 sh MysqlSetMasterSlave.sh master=/etc/ddcw/mysql_3306.conf  slave=/etc/ddcw/mysql_3308.conf
#本脚本仅支持MysqlInstallerByDDCW_ei_1.0.sh安装的mysql实例.

stty erase ^H
export LANG="en_US.UTF-8"
umask 0022
export PARAMS=$@
export HELP_FLAG=0
export LOCAL_MOST_IP16=$(cat /proc/net/tcp | awk '{print $2}' | tail -n +2 | awk -F : '{print $1}' | grep -v 00000000 | sort | uniq -c | sort -n -r | head -1 |awk '{print $2}')

#run this function and exit with $2
exits() {
  echo -e "[`date +%Y%m%d-%H:%M:%S`] \033[31;40m$1\033[0m"
  [ -z $2 ] || exit $2
  exit 1
}


help_this() {
	echo "用法参考: sh $0 master=/etc/ddcw/mysql_3306.conf slave=/etc/ddcw/mysql_3308.conf"
	echo ""
	echo "配置信息如下:"
#	echo "LOCAL_IP=$((0x${LOCAL_MOST_IP16:6:2})).$((0x${LOCAL_MOST_IP16:4:2})).$((0x${LOCAL_MOST_IP16:2:2})).$((0x${LOCAL_MOST_IP16:0:2}))"
#	echo "MYSQL_PORT=3306"
#	echo "REPL_USER=repl"
#	echo "REPL_PASSWORD=repl"
#	echo "MYSQL_COMMAND=/soft/mysql_3306/mysqlbase/mysql/bin/mysql"
	echo "MASTER_HOST: ${MASTER_HOST}"
	echo "MASTER_PORT: ${MASTER_PORT}"
	echo "MASTER_USER: ${MASTER_USER}"
	echo "MASTER_PASSWORD: ${MASTER_PASSWORD}"
	echo "MASTER_ROOT_PASSWORD: ${MASTER_ROOT_PASSWORD}"
	echo "MASTER_LOG_FILE: ${MASTER_LOG_FILE}"
	echo "MASTER_LOG_POS: ${MASTER_LOG_POS}"
	echo ""
	echo "SLAVE_HOST: ${SLAVE_HOST}"
	echo "SLAVE_PORT: ${SLAVE_PORT}"
	echo "SLAVE_USER: ${SLAVE_USER}"
	echo "SLAVE_PASSWORD: ${SLAVE_PASSWORD}"
	echo "SLAVE_ROOT_PASSWORD: ${SLAVE_ROOT_PASSWORD}"
	echo ""
	exit 2
}

for param_value in ${PARAMS}
do
	param="${param_value%=*}"
	param="${param/--/}"
	value="${param_value##*=}"
	case ${param,,} in
		master)
			export MASTER_INFO=${value}
			;;
		slave)
			export SLAVE_INFO=${value}
			;;
		master_host)
			export MASTER_HOST=${value}
			;;
		master_port)
			export MASTER_PORT=${value}
			;;
		master_user)
			export MASTER_USER=${value}
			;;
		master_password)
			export MASTER_PASSWORD=${value}
			;;
		master_root_password)
			export MASTER_ROOT_PASSWORD=${value}
			;;
		master_log_file)
			export MASTER_LOG_FILE=${value}
			;;
		master_log_pos)
			export MYSQL_LOG_POS=${value}
			;;
		slave_host)
			export SLAVE_HOST=${value}
			;;
		slave_port)
			export SLAVE_PORT=${value}
			;;
		slave_user)
			export SLAVE_USER=${value}
			;;
		slave_password)
			export SLAVE_PASSWORD=${value}
			;;
		slave_root_password)
			export SLAVE_ROOT_PASSWORD=${value}
			;;
		-h|h|help)
			export HELP_FLAG=1
			;;
		*)
			echo "参数有误 ${param}"
			export HELP_FLAG=1
			;;
	esac 
done


set_master_info() {
	export LOCAL_IP=""
	export MYSQL_PORT=""
	export REPL_USER=""
	export REPL_PASSWORD=""
	export ROOT_PASSWORD=""
	[[ -f ${MASTER_INFO} ]] && source ${MASTER_INFO}
	[[ -z ${MASTER_HOST} ]] && export MASTER_HOST="${LOCAL_IP}"
	[[ -z ${MASTER_PORT} ]] && export MASTER_PORT="${MYSQL_PORT}"
	[[ -z ${MASTER_USER} ]] && export MASTER_USER="${REPL_USER}"
	[[ -z ${MASTER_PASSWORD} ]] && export MASTER_PASSWORD="${REPL_PASSWORD}"
	[[ -z ${MASTER_ROOT_PASSWORD} ]] && export MASTER_ROOT_PASSWORD="${ROOT_PASSWORD}"
	export LOCAL_IP=""
	export MYSQL_PORT=""
	export REPL_USER=""
	export REPL_PASSWORD=""
	export ROOT_PASSWORD=""
}

set_slave_info() {
	export LOCAL_IP=""
	export MYSQL_PORT=""
	export REPL_USER=""
	export REPL_PASSWORD=""
	export ROOT_PASSWORD=""
	[[ -f ${SLAVE_INFO} ]] && source ${SLAVE_INFO}
	[[ -z ${SLAVE_HOST} ]] && export SLAVE_HOST="${LOCAL_IP}"
	[[ -z ${SLAVE_PORT} ]] && export SLAVE_PORT="${MYSQL_PORT}"
	[[ -z ${SLAVE_USER} ]] && export SLAVE_USER="${REPL_USER}"
	[[ -z ${SLAVE_PASSWORD} ]] && export SLAVE_PASSWORD="${REPL_PASSWORD}"
	[[ -z ${SLAVE_ROOT_PASSWORD} ]] && export SLAVE_ROOT_PASSWORD="${ROOT_PASSWORD}"
	export LOCAL_IP=""
	export MYSQL_PORT=""
	export REPL_USER=""
	export REPL_PASSWORD=""
	export ROOT_PASSWORD=""
	which mysql >/dev/null 2>&1 || export PATH=${MYSQL_COMMAND%/mysql*}:$PATH
}

check_conn() {
	if [[ -z ${MASTER_PASSWORD} ]] || ! mysql -h${MASTER_HOST} -P${MASTER_PORT} -u${MASTER_USER} -p${MASTER_PASSWORD} -e "select 1;" >/dev/null 2>&1;then
		echo  "连接主库(${MASTER_HOST}:${MASTER_PORT} ${MASTER_USER} )失败."
		export HELP_FLAG=1
	fi
	#mysql -h${MASTER_HOST} -P${MASTER_PORT} -uroot -p${MASTER_ROOT_PASSWORD} -e "select 1;" >/dev/null || exits "连接主库(${MASTER_HOST}:${MASTER_PORT} root)失败."
	#mysql -h${SLAVE_HOST} -P${SLAVE_PORT} -u${SLAVE_USER} -p${SLAVE_PASSWORD} -e "select 1;" >/dev/null 2>&1 || exits "连接从库(${SLAVE_HOST}:${SLAVE_PORT} ${SLAVE_USER} )失败."
	if [[ -z ${SLAVE_ROOT_PASSWORD} ]] || ! mysql -h${SLAVE_HOST} -P${SLAVE_PORT} -uroot -p${SLAVE_ROOT_PASSWORD} -e "select 1;" >/dev/null 2>&1 ;then
		echo "连接从库(${SLAVE_HOST}:${SLAVE_PORT} root)失败."
		export HELP_FLAG=1
	fi

	[[ -z ${MASTER_LOG_FILE} ]] && export MASTER_LOG_FILE=$(mysql -h${MASTER_HOST} -P${MASTER_PORT} -u${MASTER_USER} -p${MASTER_PASSWORD} -e "show master status\G" 2>/dev/null | grep -i 'File:' | awk '{print $2}')
	[[ -z ${MASTER_LOG_POS} ]] && export MASTER_LOG_POS=$(mysql -h${MASTER_HOST} -P${MASTER_PORT} -u${MASTER_USER} -p${MASTER_PASSWORD} -e "show master status\G" 2>/dev/null | grep -i 'Position:' | awk '{print $2}')
}

set_master_slave() {
	slave_info=$(mysql -h${SLAVE_HOST} -P${SLAVE_PORT} -u${SLAVE_USER} -p${SLAVE_PASSWORD} -e "select Number_of_lines,Master_log_name,Master_log_pos,Host,User_name,User_password,Port,Connect_retry,Uuid from mysql.slave_master_info\G" 2>/dev/null)
	mkdir -p /tmp/ddcw/.set_MASTER_${MASTER_HOST}_${MASTER_PORT}_SLAVE_${SLAVE_HOST}_${SLAVE_PORT}
	echo ${slave_info} >/tmp/ddcw/.set_MASTER_${MASTER_HOST}_${MASTER_PORT}_SLAVE_${SLAVE_HOST}_${SLAVE_PORT}/slave_info_old_${dt}
	
	#echo "mysql -h${SLAVE_HOST} -P${SLAVE_PORT} -uroot -p${SLAVE_ROOT_PASSWORD} -e \"stop slave;CHANGE MASTER TO MASTER_HOST='${MASTER_HOST}',
        #master_port=${MASTER_PORT},
        #MASTER_USER='${MASTER_USER}',
        #MASTER_PASSWORD='${MASTER_PASSWORD}', 
        #master_log_file='${MASTER_LOG_FILE}',
        #master_log_pos=${MASTER_LOG_POS},
        #master_auto_position=0;\""


	mysql -h${SLAVE_HOST} -P${SLAVE_PORT} -uroot -p${SLAVE_ROOT_PASSWORD} -e "stop slave;CHANGE MASTER TO MASTER_HOST='${MASTER_HOST}',
	master_port=${MASTER_PORT},
	MASTER_USER='${MASTER_USER}',
	MASTER_PASSWORD='${MASTER_PASSWORD}', 
	master_log_file='${MASTER_LOG_FILE}',
	master_log_pos=${MASTER_LOG_POS},
	master_auto_position=0;" 2>/dev/null
	mysql -h${SLAVE_HOST} -P${SLAVE_PORT} -uroot -p${SLAVE_ROOT_PASSWORD} -e "start slave;" 2>/dev/null
	sleep 2.3
	SLAVE_IO_STATUS=$(mysql -h${SLAVE_HOST} -P${SLAVE_PORT} -uroot -p${SLAVE_ROOT_PASSWORD} -e"show slave status\G" 2>/dev/null | grep -i Slave_IO_Running: | awk '{print $2}')
	SLAVE_SQL_STATUS=$(mysql -h${SLAVE_HOST} -P${SLAVE_PORT} -uroot -p${SLAVE_ROOT_PASSWORD} -e"show slave status\G" 2>/dev/null | grep -i Slave_SQL_Running: | awk '{print $2}')
	if [[ "${SLAVE_IO_STATUS^^}" == "YES" ]] && [[ "${SLAVE_SQL_STATUS^^}" == "YES" ]] ;then
		echo -e "[\033[32;40mINFO\033[0m `date +%Y%m%d-%H:%M:%S`] \033[32;40m配置完成, 当前 Slave_IO_Running 和 Slave_SQL_Running 都是Yes的.\033[0m"
		#SLAVE_SQL_RUNNING_STATE=$(mysql -h${SLAVE_HOST} -P${SLAVE_PORT} -uroot -p${SLAVE_ROOT_PASSWORD} -e"show slave status\G" 2>/dev/null | grep -i Slave_SQL_Running_State: | awk '{print $2}')
		#echo "${SLAVE_SQL_RUNNING_STATE}" | grep 'waiting for more updates' >/dev/null 2>&1 && echo -e "[\033[32;40mINFO\033[0m `date +%Y%m%d-%H:%M:%S`] \033[32;40m数据已追平.\033[0m"
		exit 0
	else
		echo "配置完成, 但是Slave_IO_Running或者Slave_SQL_Running状态不算yes, 请人工排查( mysql -h${SLAVE_HOST} -P${SLAVE_PORT} -uroot -p${SLAVE_ROOT_PASSWORD} )"
	fi
}

set_master_info
set_slave_info
check_conn
[[ ${HELP_FLAG} -eq 1 ]] && help_this
set_master_slave
