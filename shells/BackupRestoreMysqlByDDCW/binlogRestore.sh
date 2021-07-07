#!/bin/env bash
#write by ddcw at 2021.07.02
#通过binlog恢复,  sh binlogRestore.sh starttime endtime


#授权推荐命令
#create user "backup"@"%" identified WITH 'mysql_native_password' by "backup";
#grant RELOAD,PROCESS,REPLICATION CLIENT on *.* to "backup"@"%";
#flush privileges;

#SOCKET="/data/3306/prod/mysql.sock"
USER=restore
PASSWORD=restore
PORT=3366
HOST="127.0.0.1"
DEFAULTS_FILE="/data/3366/conf/my_3366.cnf"


#binlog的备份目录， 默认当前
BINLOG_BACKUP_DIR=/data/backup/binlog


RESTORE_TIME_BEGIN=$1
RESTORE_TIME_END=$2

STOP_MYSQL_COMMAND="service mysqld_3366 stop"
START_MYSQL_COMMAND="service mysqld_3366 start"

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
	echo_color error "恢复失败,gg (谁让你kill的???)"
        exit 2
}


#初始化的, 我也不知道要初始化啥
function init_() {
	#which innobackupex >/dev/null 2>&1 || exits "env has no command innobackupex"
	which mysql >/dev/null 2>&1 || exits "env has no command mysql"
	mysql -s -h${HOST}  -u${USER} -p${PASSWORD} -P${PORT} -e "show variables like 'log_bin_basename';" 2>/dev/null > /tmp/._msyqlRestorBinlogtmpbyddcw.tmp || exits "cant login mysql:  mysql -s -h${HOST} -u${USER} -p${PASSWORD} -P${PORT}"
	if [[ ! -z ${BINLOG_BACKUP_DIR} ]]; then
		[[ -d ${BINLOG_BACKUP_DIR} ]] || exits "BINLOG_BACKUP_DIR does not exists."
	fi
	[[ -z ${BINLOG_BACKUP_DIR} ]] && export BINLOG_BACKUP_DIR=$(pwd)
	export LOG_BIN_BASENAME=$(awk '{print $2}' /tmp/._msyqlRestorBinlogtmpbyddcw.tmp)
	export LOG_BIN_BASENAME=${LOG_BIN_BASENAME##*/}

}

function help_this() {
	echo_color info  "You need to select the following time range (within the range)"
	for i in $(find ${BINLOG_BACKUP_DIR} -type f -name "${LOG_BIN_BASENAME}.[0-9][0-9][0-9][0-9][0-9][0-9]" | sort)
	do
		begin_t_1=$(mysqlbinlog $i | grep "#[0-9][0-9][0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]" | head -3 | tail -1 | awk '{print "20"$1}' | sed 's/#//' | awk -F '' '{print $1$2$3$4"-"$5$6"-"$7$8}')
		begin_t_2=$(mysqlbinlog $i | grep "#[0-9][0-9][0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]" | head -3 | tail -1 | awk '{print $2}')
		end_t_1=$(mysqlbinlog $i | grep "#[0-9][0-9][0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]" | tail -1 | awk '{print "20"$1}' | sed 's/#//' | awk -F '' '{print $1$2$3$4"-"$5$6"-"$7$8}')
		end_t_2=$(mysqlbinlog $i | grep "#[0-9][0-9][0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]" | tail -1 | awk '{print $2}')
		echo -e "$i \t'${begin_t_1} ${begin_t_2}'\t\t'${end_t_1} ${end_t_2}'"
	done
	exit 1
}

function restore_check_() {

	export THIS_IS_LIST=0
	[[ ${RESTORE_TIME_END} > "1996-07-02 11:11:11" ]] >/dev/null 2>&1 || export THIS_IS_LIST=1
	[[ ${RESTORE_TIME_BEGIN} > "1996-07-02 11:11:11" ]] >/dev/null 2>&1 || export THIS_IS_LIST=1
	[[ ${RESTORE_TIME_END} < "9999-12-12 11:11:11" ]] >/dev/null 2>&1 || export THIS_IS_LIST=1
	[[ ${RESTORE_TIME_BEGIN} < "9999-12-12 11:11:11" ]] >/dev/null 2>&1 || export THIS_IS_LIST=1
	[[ -d ${BINLOG_BACKUP_DIR} ]] || exits "no binlog backup dir"
	[[ ${THIS_IS_LIST} -eq 1 ]] && help_this

	
}

function set_global_gtid() {
	need_state=$1
	for i in $(echo "OFF OFF_PERMISSIVE ON_PERMISSIVE ON ON_PERMISSIVE OFF_PERMISSIVE OFF")
	do
		#echo $i +++++  mysql -s -h${HOST}  -u${USER} -p${PASSWORD} -P${PORT} -e \"set @@GLOBAL.GTID_MODE=$i\"
		mysql -s -h${HOST}  -u${USER} -p${PASSWORD} -P${PORT} -e "set @@GLOBAL.GTID_MODE=$i"  >/dev/null 2>&1
		current_state=$(mysql -s -h${HOST}  -u${USER} -p${PASSWORD} -P${PORT} -e "select @@GLOBAL.GTID_MODE;" 2>/dev/null)
		current_state=$(echo ${current_state} | awk '{print $NF}')
		[[ ${current_state} == ${need_state} ]] >/dev/null 2>&1 && break
	done
	
}

function restore() {
	export dtbegin=$(date +%s)
	restorelog_detail=/tmp/.binlogrestore${dtbegin}.log
	#save_gtid_stat=$(mysql -s -h${HOST}  -u${USER} -p${PASSWORD} -P${PORT} -e "select @@GLOBAL.GTID_MODE;" 2>/dev/null)
	#save_gtid_stat=$(echo ${save_gtid_stat} | awk '{print $NF}')
	#set_global_gtid OFF_PERMISSIVE
	for binlog in $(find ${BINLOG_BACKUP_DIR} -type f -name "${LOG_BIN_BASENAME}.[0-9][0-9][0-9][0-9][0-9][0-9]" | sort)
	do
		mysqlbinlog ${binlog} --skip-gtids=true  --start-datetime="${RESTORE_TIME_BEGIN}" --stop-datetime="${RESTORE_TIME_END}" | mysql -h${HOST}  -u${USER} -p${PASSWORD} -P${PORT} >/dev/null 2>&1 || exits "failed to run :\n mysqlbinlog ${binlog} --start-datetime=\"${RESTORE_TIME_BEGIN}\" --stop-datetime=\"${RESTORE_TIME_END}\""
		#mysqlbinlog ${binlog} --start-datetime="${RESTORE_TIME_BEGIN}" --stop-datetime="${RESTORE_TIME_END}" 
		#echo "mysqlbinlog ${binlog} --start-datetime='${RESTORE_TIME_BEGIN}' --stop-datetime='${RESTORE_TIME_END}' | mysql -h${HOST}  -u${USER} -p${PASSWORD} -P${PORT} >/dev/null 2>&1"
	done
	#set_global_gtid ${save_gtid_stat}
}

init_
restore_check_
restore
