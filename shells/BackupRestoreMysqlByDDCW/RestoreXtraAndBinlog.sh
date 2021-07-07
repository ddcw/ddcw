#!/bin/env bash
#write by ddcw at 2021.07.07
#恢复脚本
#文件和目录都写绝对路径, 我不想去判断

#备份目录
XTRABACKUP_DIR=/data/backup
BINLOGBACKUP_DIR=/data/backup/binlog


#备份命令,有时候备份命令不在环境变量里面 
XTRABACKUP_COMMAND=/usr/bin/xtrabackup
BINLOGBACKUP_COMMAND=/usr/bin/mysqlbinlog
MYSQL_COMMAND=/usr/bin/mysql


#服务器信息
BACKUP_HOST=192.168.101.151
BACKUP_PORT=3366
BACKUP_USER=restore
BACKUP_PASSWORD=restore
BACKUP_SOCKET=/data/3366/prod/mysql.sock
DEFAULT_CONFIG_FILES=/data/3366/conf/my_3366.cnf


#启停mysql的命令
STOP_MYSQL_COMMAND='service mysqld_3366 stop'
START_MYSQL_COMMAND='service mysqld_3366 start'

#恢复的用户, 恢复需要的权限非常大, 因为恢复binlog会写很多数据库
# -- create user "restore"@"%" identified WITH 'mysql_native_password' by "restore";
# -- grant all on *.* to "restore"@"%";
# -- flush privileges;

#xtrabackup备份恢复脚本和binlog备份恢复脚本
RESTORE_XTRABACKUP_SCRIPT=XtraRestore.sh
RESTORE_BINLOG_SCRIPT=binlogRestore.sh


#恢复并行度,只对xtrabackup有效
PARALLEL=2

#启用物理备份恢复
ENABLE_XTRA=1

#启用binlog备份恢复
ENABLE_BINLOG=1

TIME_POINT=$1
TIME_POINT_FORMAT=$(echo ${TIME_POINT} | grep -o -E [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9])

#run this function and exit with $2
function exits(){
  echo -e "[`date +%Y%m%d-%H:%M:%S`] \033[31;40m$1\033[0m"
  [ -z $2 ] && exit $2
  exit 1
}

function echo_color() {
  case $1 in
    green)
      echo -e "\033[32;40m$2\033[0m"
      ;;
    red)
      echo -e "\033[31;40m$2\033[0m"
      ;;
    error|erro|ERROR|E|e)
      echo -e "[\033[1;5;41;33mERROR\033[0m `date +%Y%m%d-%H:%M:%S`] \033[1;41;33m$2\033[0m"
      ;;
    redflicker)
      echo -e "\033[1;5;41;33m$2\033[0m"
      ;;
    info|INFO|IF|I|i)
      echo -e "[\033[32;40mINFO\033[0m `date +%Y%m%d-%H:%M:%S`] \033[32;40m$2\033[0m"
      ;;
    highlightbold)
      echo -e "\033[1;41;33m$2\033[0m"
      ;;
    warn|w|W|WARN|warning)
      echo -e "[\033[31;40mWARNNING\033[0m `date +%Y%m%d-%H:%M:%S`] \033[31;40m$2\033[0m"
      ;;
    *)
      echo "INTERNAL ERROR: echo_color KEY VALUE"
      ;;
  esac
}

trap 'WhenCtrlC' INT
function WhenCtrlC () {
	echo_color error "恢复失败, GG -_-"
        exit 2
}

function help_this() {
	echo_color info "你可以选择恢复到以下任意时间点(或者以下时间点的范围内) 格式要求严格"
	echo  "${XTRA_TIME_POINT}"
	echo "${LATEST_BINLOG_TIME_POINT}"
	echo_color info "  例子: sh $0 $(echo ${XTRA_TIME_POINT} | awk '{print $(NF-1)}')"
	[[ -z $1 ]] || echo_color warn "$1"
	exit 1
}

function init_AND_check_() {
	#变量涉及到的相关的文件目录这里就不判断了, 备份脚本判断了的
	[[ -d ${XTRABACKUP_DIR} ]] || exits "物理备份目录不存在, 无法恢复"
	[[ -d ${BINLOGBACKUP_DIR} ]] || exits "binlog备份目录不存在, 无法恢复"
	which mysql >/dev/null 2>&1 || exits "env has no command mysql"
	mysql -s -h${BACKUP_HOST}  -u${BACKUP_USER} -p${BACKUP_PASSWORD} -P${BACKUP_PORT} -e "show variables like 'log_bin_basename';" 2>/dev/null > /tmp/._msyqlRestorBinlogtmpbyddcw.tmp || exits "cant login mysql:  mysql -s -h${BACKUP_HOST}  -u${BACKUP_USER} -p${BACKUP_PASSWORD} -P${BACKUP_PORT}"
	export LOG_BIN_BASENAME=$(awk '{print $2}' /tmp/._msyqlRestorBinlogtmpbyddcw.tmp)
	export LOG_BIN_BASENAME=${LOG_BIN_BASENAME##*/}
	#echo "${BINLOGBACKUP_DIR}  ++ ${LOG_BIN_BASENAME}"
	LATEST_BINLOG_FILE=$(find ${BINLOGBACKUP_DIR} -type f -name "${LOG_BIN_BASENAME}.[0-9][0-9][0-9][0-9][0-9][0-9]" | sort | tail -1)
	export LATEST_BINLOG_TIME_POINT_A=$(mysqlbinlog ${LATEST_BINLOG_FILE} | grep "#[0-9][0-9][0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]" | tail -1 | awk '{print "20"$1}' | sed 's/#//' | awk -F '' '{print $1$2$3$4"-"$5$6"-"$7$8}' )
	export LATEST_BINLOG_TIME_POINT_B=$(mysqlbinlog ${LATEST_BINLOG_FILE} | grep "#[0-9][0-9][0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]" | tail -1 | awk '{print $2}' | sed 's/:/-/g')
	export LATEST_BINLOG_TIME_POINT=${LATEST_BINLOG_TIME_POINT_A}_${LATEST_BINLOG_TIME_POINT_B}


	export XTRA_TIME_POINT=$(find ${XTRABACKUP_DIR%/}/FULLBACKUP ${XTRABACKUP_DIR%/}/INCREMENT_BACKUP -type d -name [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | awk -F / '{print $NF}' | sort)


	[[ -z ${TIME_POINT} ]] && help_this 
	[[ ${TIME_POINT} == ${TIME_POINT_FORMAT} ]] || help_this "${TIME_POINT} 时间格式不对,请严格遵守"
	echo_color info "初始化变量"

	#binlog的开头时间, 同时也是xtra的结尾时间
	export TIME_POINT_BINLOG_BEGIN=$(echo ${XTRA_TIME_POINT} | awk '{print $1}')
	for TIME_POINT_XTRA_END in ${XTRA_TIME_POINT}
	do
		if [[ ${TIME_POINT_XTRA_END} < ${TIME_POINT} ]] || [[ ${TIME_POINT_XTRA_END} == ${TIME_POINT} ]];then
			export TIME_POINT_BINLOG_BEGIN=${TIME_POINT_XTRA_END}
		else
			break
		fi
	done
	
	#binlog的结尾时间
	export TIME_POINT_BINLOG_END=$(echo ${TIME_POINT} | sed 's/_/ /;' | awk -F - '{print $1"-"$2"-"$3":"$4":"$5}')
}

function set_backup_xtra() {
	echo_color info "配置xtrabackup恢复脚本 ${RESTORE_XTRABACKUP_SCRIPT}的参数"
	sed -i "/^USER=/cUSER=${BACKUP_USER}" ${RESTORE_XTRABACKUP_SCRIPT}
	sed -i "/^PASSWORD=/cPASSWORD=${BACKUP_PASSWORD}" ${RESTORE_XTRABACKUP_SCRIPT}
	sed -i "/^PORT=/cPORT=${BACKUP_PORT}" ${RESTORE_XTRABACKUP_SCRIPT}
	sed -i "/^DEFAULTS_FILE=/cDEFAULTS_FILE=${DEFAULT_CONFIG_FILES}" ${RESTORE_XTRABACKUP_SCRIPT}
	sed -i "/^PARALLEL=/cPARALLEL=${PARALLEL}" ${RESTORE_XTRABACKUP_SCRIPT}
	sed -i "/^STOP_MYSQL_COMMAND=/cSTOP_MYSQL_COMMAND='${STOP_MYSQL_COMMAND}'" ${RESTORE_XTRABACKUP_SCRIPT}
	sed -i "/^START_MYSQL_COMMAND=/cSTART_MYSQL_COMMAND='${START_MYSQL_COMMAND}'" ${RESTORE_XTRABACKUP_SCRIPT}


	echo_color info "开始物理恢复"
	echo_color info "sh ${RESTORE_XTRABACKUP_SCRIPT} ${TIME_POINT_BINLOG_BEGIN}"
	sh ${RESTORE_XTRABACKUP_SCRIPT} ${TIME_POINT_BINLOG_BEGIN}
	echo_color info "物理恢复完成"
}

function set_backup_binlog() {
	echo_color info "配置binlog恢复脚本 ${RESTORE_BINLOG_SCRIPT}脚本"
	sed -i "/^USER=/cUSER=${BACKUP_USER}" ${RESTORE_BINLOG_SCRIPT}
	sed -i "/^PASSWORD=/cPASSWORD=${BACKUP_PASSWORD}" ${RESTORE_BINLOG_SCRIPT}
	sed -i "/^PORT=/cPORT=${BACKUP_PORT}" ${RESTORE_BINLOG_SCRIPT}
	sed -i "/^BINLOG_BACKUP_DIR=/cBINLOG_BACKUP_DIR=${BINLOGBACKUP_DIR}" ${RESTORE_BINLOG_SCRIPT}

	echo_color info "开始binlog恢复"
	echo_color info "sh ${RESTORE_BINLOG_SCRIPT} \"${TIME_POINT_BINLOG_BEGIN}\" \"${TIME_POINT_BINLOG_END}\""
	sh ${RESTORE_BINLOG_SCRIPT} "${TIME_POINT_BINLOG_BEGIN}" "${TIME_POINT_BINLOG_END}"
	echo_color info "binlog恢复完成"

}



init_AND_check_
set_backup_xtra
set_backup_binlog
#help_this
