#!/bin/env bash
#write by ddcw at 2021.07.06
#设置备份的, 包括备份目录, 备份账号, 保留时间等
#文件和目录都写绝对路径, 我不想去判断

#备份目录
XTRABACKUP_DIR=/data/backup
BINLOGBACKUP_DIR=/data/backup/binlog

#备份保留时间, 每次备份完之后, 就find 找这个时间之前的
XTRABACKUP_SAVE_DAYS="7"
BINLOGBACKUP_SAVE_DAYS="7"

#备份周期
#多久一次全备份, 默认周3和周六
XTRABACKUP_FULL_WEEKS="3,6"
#多久一次增量备份, 默认每天都增量备份
XTRABACKUP_INCR_WEEKS="0,1,2,3,4,5,6"
#binlog默认实时备份, 不能设置


#备份时间
XTRABACKUP_FULL_TIME="01:00"
XTRABACKUP_INCR_TIME="04:00"
#binlog默认实时备份,不能设置

#备份命令,有时候备份命令不在环境变量里面 
XTRABACKUP_COMMAND=/usr/bin/xtrabackup
BINLOGBACKUP_COMMAND=/usr/bin/mysqlbinlog
MYSQL_COMMAND=/usr/bin/mysql


#服务器信息
BACKUP_HOST=192.168.101.151
BACKUP_PORT=3366
BACKUP_USER=backup
BACKUP_PASSWORD=backup
BACKUP_SOCKET=/data/3366/prod/mysql.sock
DEFAULT_CONFIG_FILES=/data/3366/conf/my_3366.cnf

#xtrabackup备份的并行度
PARALLEL=2


#备份到HDFS或者FTP服务器上, 目前暂不支持, 感兴趣的可以自己写.

#创建备份用户和授权建议
# -- create user "backup"@"%" identified WITH 'mysql_native_password' by "backup";
# -- grant RELOAD, PROCESS, REPLICATION CLIENT, REPLICATION SLAVE on *.* to "backup"@"%";
# -- flush privileges;

#xtrabackup备份脚本和binlog备份脚本
BACKUP_BINLOG_SCRIPT="syncbinlog.sh"
BACKUP_XTRABACKUP_SCRIPT="Xtrabackup.sh"

#启用物理备份
ENABLE_XTRA=1

#启用增量备份
ENABLE_BINLOG=1


CONFIG_RESTORE=1

#############################################################################################
#设置RestoreXtraAndBinlog.sh的参数
RESTORE_USER="restore"
RESTORE_PASSWORD="restore"
START_MYSQL_COMMAND="service mysqld_3366 start"
STOP_MYSQL_COMMAND="service mysqld_3366 stop"
RESTORE_XTRABACKUP_SCRIPT="XtraRestore.sh"
RESTORE_BINLOG_SCRIPT="binlogRestore.sh"
RESTORE_PARALLEL=2
RESTORE_SCRIPT="RestoreXtraAndBinlog.sh"

#############################################################################################



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
	echo_color error "备份设置脚本意外终止..., 不过没啥影响, 执行N次的效果是一样的"
        exit 2
}


function init_AND_check_() {
	echo_color info "初始化变量"
	DIRS="XTRABACKUP_DIR  BINLOGBACKUP_DIR "
	FILES="XTRABACKUP_COMMAND  BINLOGBACKUP_COMMAND  MYSQL_COMMAND  DEFAULT_CONFIG_FILES BACKUP_XTRABACKUP_SCRIPT BACKUP_BINLOG_SCRIPT"
	SOCKETS="BACKUP_SOCKET"
	VARS="BACKUP_HOST BACKUP_USER  BACKUP_PASSWORD "
	NUMS="XTRABACKUP_SAVE_DAYS  BINLOGBACKUP_SAVE_DAYS  BACKUP_PORT  PARALLEL"
	TIME_HOUR_MIN="XTRABACKUP_FULL_TIME  XTRABACKUP_INCR_TIME"
	
	#创建目录并判断目录是否存在
	for dir in ${DIRS}
	do
		eval mkdir -p \$${dir}
		eval [[ -d \$${dir} ]] || exits "directory ${dir} \$${dir} not exists"
		eval export ${dir}=\`realpath \${$dir}\`
	done

	#判断脚本涉及到的文件是否存在
	for file in ${FILES}
	do
		eval [[ -f \$${file} ]] || exits "file ${file} \$${file} not exist"
		eval export ${file}=\`realpath \${$file}\`
	done

	#判断socket是否存在
	for socket in ${SOCKETS}
	do
		eval [[ -S \$${socket} ]] || exits "socket ${socket} \$${socket} not exits"
	done

	#判断字符串是否为空
	for var in ${VARS}
	do
		eval [[ -z \$${var} ]] && exits "var ${var} \$${var} is zero"
	done

	#判断数字是否是数字
	for num in ${NUMS}
	do
		eval [[ \$${num} -eq \$${num} ]] >/dev/null 2>&1 || exits "number ${num} \$${num} must be number"
	done

	#判断时间格式的 小时和分钟是不是对
	export hour1=$(echo ${XTRABACKUP_FULL_TIME} | awk -F : '{print $1}')
	export min1=$(echo ${XTRABACKUP_FULL_TIME} | awk -F : '{print $2}')
	export hour2=$(echo ${XTRABACKUP_INCR_TIME} | awk -F : '{print $1}')
	export min2=$(echo ${XTRABACKUP_INCR_TIME} | awk -F : '{print $2}')
	#echo ${hour1} ${min1}  ${hour2}  ${min2}
	[[ ${hour1} -le 23 ]] >/dev/null 2>&1 || exits "XTRABACKUP_FULL_TIME 的小时必须小于24"
	[[ ${hour2} -le 23 ]] >/dev/null 2>&1 || exits "XTRABACKUP_INCR_TIME 的小时必须小于24"
	[[ ${min1} -le 59 ]] >/dev/null 2>&1 || exits "XTRABACKUP_FULL_TIME 的分钟数必须小于60"
	[[ ${min2} -le 59 ]] >/dev/null 2>&1 || exits "XTRABACKUP_INCR_TIME 的分钟数必须小于60"

	#判读备份周期是否正确(就是范围对不对)
	for xf in $(echo ${XTRABACKUP_FULL_WEEKS} | sed 's/,/ /g')
	do
		[[ ${xf} -le 6 ]] >/dev/null 2>&1 || exits "${XTRABACKUP_FULL_WEEKS} 的 ${xf} 必须是0-6范围内"
	done
	
	for xi in $(echo ${XTRABACKUP_INCR_WEEKS} | sed 's/,/ /g')
	do
		[[ ${xi} -le 6 ]] >/dev/null 2>&1 || exits "${XTRABACKUP_INCR_WEEKS} 的 ${xi} 必须是0-6范围内"
	done
	#exit 1
}

function set_backup_xtra() {
	echo_color info "配置xtra备份脚本对应参数"
	sed -i "/^SOCKET=/cSOCKET=${BACKUP_SOCKET}" ${BACKUP_XTRABACKUP_SCRIPT}
	sed -i "/^USER=/cUSER=${BACKUP_USER}" ${BACKUP_XTRABACKUP_SCRIPT}
	sed -i "/^PASSWORD=/cPASSWORD=${BACKUP_PASSWORD}" ${BACKUP_XTRABACKUP_SCRIPT}
	sed -i "/^PORT=/cPORT=${BACKUP_PORT}" ${BACKUP_XTRABACKUP_SCRIPT}
	sed -i "/^DEFAULTS_FILE=/cDEFAULTS_FILE=${DEFAULT_CONFIG_FILES}" ${BACKUP_XTRABACKUP_SCRIPT}
	sed -i "/^PARALLEL=/cPARALLEL=${PARALLEL}" ${BACKUP_XTRABACKUP_SCRIPT}
	sed -i "/^BACKUP_DIR=/cBACKUP_DIR=${XTRABACKUP_DIR}" ${BACKUP_XTRABACKUP_SCRIPT}


	echo_color info "设置全量备份和增量备份的定时任务"
	crontab_command_xtra_full="${min1} ${hour1} * * ${XTRABACKUP_FULL_WEEKS} $(whoami) (sh ${BACKUP_XTRABACKUP_SCRIPT} 0 ${XTRABACKUP_SAVE_DAYS} flag=${BACKUP_HOST}_${BACKUP_PORT})"
	crontab_command_xtra_incr="${min2} ${hour2} * * ${XTRABACKUP_INCR_WEEKS} $(whoami) (sh ${BACKUP_XTRABACKUP_SCRIPT} 1 ${XTRABACKUP_SAVE_DAYS} flag=${BACKUP_HOST}_${BACKUP_PORT})"

	grep  "${crontab_command_xtra_full}" /etc/crontab >/dev/null 2>&1 && echo_color info "全备定时任务已经设置了" || echo "${crontab_command_xtra_full}" >>  /etc/crontab
	grep  "${crontab_command_xtra_incr}" /etc/crontab >/dev/null 2>&1 && echo_color info "增备定时任务已经设置了" || echo "${crontab_command_xtra_incr}" >>  /etc/crontab
}

function set_backup_binlog() {
	echo_color info "配置binlog备份脚本"
	sed -i "/^REMOTE_HOST=/cREMOTE_HOST=${BACKUP_HOST}" ${BACKUP_BINLOG_SCRIPT}
	sed -i "/^REMOTE_PORT=/cREMOTE_PORT=${BACKUP_PORT}" ${BACKUP_BINLOG_SCRIPT}
	sed -i "/^REMOTE_USER=/cREMOTE_USER=${BACKUP_USER}" ${BACKUP_BINLOG_SCRIPT}
	sed -i "/^REMOTE_PASSWORD=/cREMOTE_PASSWORD=${BACKUP_PASSWORD}" ${BACKUP_BINLOG_SCRIPT}
	sed -i "/^LOCAL_PRENAME=/cLOCAL_PRENAME=${BINLOGBACKUP_DIR}/" ${BACKUP_BINLOG_SCRIPT}
	echo_color info "设置binlog备份的定时任务"
	crontab_command_binlog_backup_check="*/1 * * * * $(whoami) ( [[ -f /proc/\$(cat /run/mysqlBinlogSYNCbyDDCW_${BACKUP_HOST}_${BACKUP_PORT}.pid)/comm ]] >/dev/null 2>&1 || cd /tmp; nohup sh ${BACKUP_BINLOG_SCRIPT} FLAG=BINLOG_CHECK_BY_DDCW_${BACKUP_HOST}_${BACKUP_PORT} &)"
	crontab_command_binlog_backup_clear="1 * * * * $(whoami) (find ${BINLOGBACKUP_DIR} -mtime +${BINLOGBACKUP_SAVE_DAYS} -type f -name *.[0-9][0-9][0-9][0-9][0-9][0-9] | xargs -t -i rm -rf {} && echo 'clean successd. FLAG=BINLOG_CLEAN_BY_DDCW_${BACKUP_HOST}_${BACKUP_PORT}')"
	#grep "${crontab_command_binlog_backup_check}" /etc/crontab >/dev/null 2>&1 && echo_color info "binlog备份任务已经设置" || echo "${crontab_command_binlog_backup_check}" >> /etc/crontab
	#grep "${crontab_command_binlog_backup_clear}" /etc/crontab >/dev/null 2>&1 && echo_color info "binlog清理任务已经设置" || echo "${crontab_command_binlog_backup_clear}" >> /etc/crontab
	grep "FLAG=BINLOG_CHECK_BY_DDCW_${BACKUP_HOST}_${BACKUP_PORT}" /etc/crontab >/dev/null 2>&1 && echo_color info "binlog备份任务已经设置" || echo "${crontab_command_binlog_backup_check}" >> /etc/crontab
	grep "FLAG=BINLOG_CLEAN_BY_DDCW_${BACKUP_HOST}_${BACKUP_PORT}" /etc/crontab >/dev/null 2>&1 && echo_color info "binlog清理任务已经设置" || echo "${crontab_command_binlog_backup_clear}" >> /etc/crontab
	#echo "grep \"${crontab_command_binlog_backup_check}\" /etc/crontab >/dev/null 2>&1 && echo_color info \"binlog备份任务已经设置\" || echo \"${crontab_command_binlog_backup_check}\" >> /etc/crontab"
	#echo "grep \"${crontab_command_binlog_backup_clear}\" /etc/crontab >/dev/null 2>&1 && echo_color info \"binlog清理任务已经设置\" || echo \"${crontab_command_binlog_backup_clear}\" >> /etc/crontab"

}

function set_RestoreXtraAndBinlog_env() {
	echo_color info "设置恢复脚本需要的参数(恢复脚本需要dba权限的用户)"
	sed -i "/^XTRABACKUP_DIR=/cXTRABACKUP_DIR=${XTRABACKUP_DIR}"  ${RESTORE_SCRIPT}
	sed -i "/^BINLOGBACKUP_DIR=/cBINLOGBACKUP_DIR=${BINLOGBACKUP_DIR}" ${RESTORE_SCRIPT}
	sed -i "/^XTRABACKUP_COMMAND=/cXTRABACKUP_COMMAND=${XTRABACKUP_COMMAND}" ${RESTORE_SCRIPT}
	sed -i "/^BINLOGBACKUP_COMMAND=/cBINLOGBACKUP_COMMAND=${BINLOGBACKUP_COMMAND}" ${RESTORE_SCRIPT}
	sed -i "/^MYSQL_COMMAND=/cMYSQL_COMMAND=${MYSQL_COMMAND}" ${RESTORE_SCRIPT}
	sed -i "/^BACKUP_HOST=/cBACKUP_HOST=${BACKUP_HOST}" ${RESTORE_SCRIPT}
	sed -i "/^BACKUP_PORT=/cBACKUP_PORT=${BACKUP_PORT}" ${RESTORE_SCRIPT}
	sed -i "/^BACKUP_USER=/cBACKUP_USER=${RESTORE_USER}" ${RESTORE_SCRIPT}
	sed -i "/^BACKUP_PASSWORD=/cBACKUP_PASSWORD=${RESTORE_PASSWORD}" ${RESTORE_SCRIPT}
	sed -i "/^BACKUP_SOCKET=/cBACKUP_SOCKET=${BACKUP_SOCKET}" ${RESTORE_SCRIPT}
	sed -i "/^DEFAULT_CONFIG_FILES=/cDEFAULT_CONFIG_FILES=${DEFAULT_CONFIG_FILES}" ${RESTORE_SCRIPT}
	sed -i "/^STOP_MYSQL_COMMAND=/cSTOP_MYSQL_COMMAND='${STOP_MYSQL_COMMAND}'" ${RESTORE_SCRIPT}
	sed -i "/^START_MYSQL_COMMAND=/cSTART_MYSQL_COMMAND='${START_MYSQL_COMMAND}'" ${RESTORE_SCRIPT}
	sed -i "/^RESTORE_XTRABACKUP_SCRIPT=/cRESTORE_XTRABACKUP_SCRIPT=${RESTORE_XTRABACKUP_SCRIPT}" ${RESTORE_SCRIPT}
	sed -i "/^RESTORE_BINLOG_SCRIPT=/cRESTORE_BINLOG_SCRIPT=${RESTORE_BINLOG_SCRIPT}" ${RESTORE_SCRIPT}
	sed -i "/^PARALLEL=/cPARALLEL=${RESTORE_PARALLEL}" ${RESTORE_SCRIPT}
}

function set_clean_backup_xtra() {
	echo "清理xtra备份过期的备份"
}

function set_clean_backup_binlog() {
	echo "清理binlog过期的备份"
}

init_AND_check_
set_backup_xtra
set_backup_binlog
[[ ${CONFIG_RESTORE} -eq 1 ]] >/dev/null 2>&1 && set_RestoreXtraAndBinlog_env
#set_clean_backup_xtra
#set_clean_backup_binlog
