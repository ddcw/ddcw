#!/bin/env bash
#write by ddcw at 2021.07.02
#恢复脚本, 只支持XtraBackup.sh备份的恢复. 其它的自个摸索
#恢复涉及到启停mysql.  默认用service mysqld_port start|stop 来管理. 不是的,自个写


#授权推荐命令
#create user "backup"@"%" identified WITH 'mysql_native_password' by "backup";
#grant RELOAD,PROCESS,REPLICATION CLIENT on *.* to "backup"@"%";
#flush privileges;

#SOCKET="/data/3306/prod/mysql.sock"
USER=restore
PASSWORD=restore
PORT=3366
DEFAULTS_FILE=/data/3366/conf/my_3366.cnf
PARALLEL=2

BACKUP_DIR=/data/backup

#备份目录, 以下为默认设置, 也可以手动设置
#FULLBACKUP=${BACKUP_DIR%/#}/FULLBACKUP
#INCREMENTALBACKUP=${BACKUP_DIR%/#}/INCREMENT_BACKUP

#0表示全备, 1表示增量备份
#INCREMENTAL=0
#[[ -z $1 ]] || export INCREMENTAL=$1

RESTORE_TIME_END=$1

STOP_MYSQL_COMMAND='service mysqld_3366 stop'
START_MYSQL_COMMAND='service mysqld_3366 start'

[[ -z $2 ]] || export IGNORE_INTERACTIVE=1
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
	which innobackupex >/dev/null 2>&1 || exits "env has no command innobackupex"
	#which mysql >/dev/null 2>&1 || exits "env has no command mysql"
	[[ ${PARALLEL} -eq ${PARALLEL} ]] >/dev/null || exits "PARALLEL must be int"
	#[[ -S ${SOCKET} ]] || exits "no socket file ${SOCKET}"
	#mysql -s  -u${USER} -p${PASSWORD} -P${PORT} -e "show databases;" >/dev/null 2>&1 || exits "cant login mysql:  mysql -s  -u${USER} -p${PASSWORD} -P${PORT}"
	[[ -z ${FULLBACKUP} ]] && export FULLBACKUP=${BACKUP_DIR%/#}/FULLBACKUP
	[[ -z ${INCREMENTALBACKUP} ]] && export INCREMENTALBACKUP=${BACKUP_DIR%/#}/INCREMENT_BACKUP
	[[ -d ${BACKUP_DIR} ]] || exits "no dir ${BACKUP_DIR}"
	[[ -d ${FULLBACKUP} ]] || exits "no dir ${FULLBACKUP}"
	[[ -d ${INCREMENTALBACKUP} ]] || exits "no dir ${INCREMENTALBACKUP}" 

}

function help_this() {
	echo_color info  "You can choose to restore to the following point in time"
	echo "$( find ${FULLBACKUP} ${INCREMENTALBACKUP} -type d -name [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | awk -F / '{print $NF}' | sort)"
	exit 0
}

function restore_check_() {

	export THIS_IS_LIST=0
	[[ ${RESTORE_TIME_END} > "1996-07-02_11-11-11" ]] >/dev/null 2>&1 || export THIS_IS_LIST=1
	[[ ${RESTORE_TIME_END} < "9999-12-12_11-11-11" ]] >/dev/null 2>&1 || export THIS_IS_LIST=1
	[[ -d ${FULLBACKUP}/${RESTORE_TIME_END} ]] && export FULL_RESTORE_ONLY="${FULLBACKUP}/${RESTORE_TIME_END}"
	[[ -d ${INCREMENTALBACKUP}/${RESTORE_TIME_END} ]] && export INCREMENT_RESTORE="${INCREMENTALBACKUP}/${RESTORE_TIME_END}"
	[[ ${THIS_IS_LIST} -eq 1 ]] && help_this
	if [[ -z ${FULL_RESTORE_ONLY} ]] && [[ -z ${INCREMENT_RESTORE}  ]]; then
		export THIS_IS_LIST=1
		[[ ${THIS_IS_LIST} -eq 1 ]] && help_this
	elif [[ ! -z ${FULL_RESTORE_ONLY} ]] && [[ ! -z ${INCREMENT_RESTORE} ]]; then
		exits "RESTORE_TIME_END exists on ${FULLBACKUP} and ${INCREMENTALBACKUP}"
	fi

	
	export DATADIR=$(grep "^datadir" ${DEFAULTS_FILE} | awk -F = '{print $2}')
	export REDOLOGDIR=$(grep "^innodb_log_group_home_dir" ${DEFAULTS_FILE} | awk -F = '{print $2}')
	export INNODBDATA_HOME_DIR=$(grep "^innodb_data_home_dir" ${DEFAULTS_FILE} | awk -F = '{print $2}')
	export DATADIR=${DATADIR%*/}
	export REDOLOGDIR=${REDOLOGDIR%*/}
	export INNODBDATA_HOME_DIR=${INNODBDATA_HOME_DIR%*/}

	export MYSQL_USER_OS=$(grep "^user=" ${DEFAULTS_FILE} | awk -F user= '{print $2}')
	[[ -z ${MYSQL_USER_OS} ]] && export MYSQL_USER_OS="mysql"

	[[ -d ${DATADIR} ]] || exits "${DEFAULTS_FILE} not exists datadir parameter"
	[[ -z ${STOP_MYSQL_COMMAND} ]] && exits "STOP_MYSQL_COMMAND is null"
	[[ -z ${START_MYSQL_COMMAND} ]] && exits "START_MYSQL_COMMAND is null"

}

function restore() {
	export dtbegin=$(date +%s)
	restorelog_detail=/tmp/.restore${dtbegin}.log
	if [[ -d ${FULL_RESTORE_ONLY} ]]; then
		echo_color info "you choose FULL BACKUP RESTORE...."
		echo_color info "you can visit ${restorelog_detail} to known more:  tail -100f ${restorelog_detail}"
		echo_color info "ready apply-log"
		innobackupex --apply-log ${FULL_RESTORE_ONLY} >> ${restorelog_detail}   2>&1 || exits "apply-log fialed"
		echo_color info "stop mysql with ${STOP_MYSQL_COMMAND}"
		bash ${STOP_MYSQL_COMMAND} 
		echo $(ssh 127.0.0.1 -p ${PORT} -o ConnectTimeout=1 -o BatchMode=yes -o StrictHostKeyChecking=yes 2>&1 ) | grep refused >/dev/null 2>&1 || exits "stop mysql failed"
		[[ -d ${REDOLOGDIR} ]] && mv ${REDOLOGDIR} ${REDOLOGDIR%/*}/redolog.backup${dtbegin}
		#这个地方很神奇, 只能单中括号, 双中括号判断不了, 不知道为啥
		[ -d ${INNODBDATA_HOME_DIR} ] && mv ${INNODBDATA_HOME_DIR} ${INNODBDATA_HOME_DIR%/*}/innodblog.backup${dtbegin}
		[[ -d ${DATADIR} ]] && mv ${DATADIR} ${DATADIR%/*}/data.backup${dtbegin}

		echo_color info "begin recover redolog and innodb_data and data "
		innobackupex --defaults-file=${DEFAULTS_FILE} --copy-back --rsync ${FULL_RESTORE_ONLY} >> ${restorelog_detail} 2>&1 || exits "copy-backup failed"
		chown ${MYSQL_USER_OS}:${MYSQL_USER_OS} ${REDOLOGDIR} ${INNODBDATA_HOME_DIR} ${DATADIR} -R
		echo_color info "start mysql with ${START_MYSQL_COMMAND}"
		bash ${START_MYSQL_COMMAND}
		#mysql -s  -u${USER} -p${PASSWORD} -P${PORT} -e "show databases;" >/dev/null 2>&1 || exits "start mysql filed"
		echo $(ssh 127.0.0.1 -p ${PORT} -o ConnectTimeout=1 -o BatchMode=yes -o StrictHostKeyChecking=yes 2>&1 ) | grep refused >/dev/null 2>&1 && exits "start mysql failed"
		echo_color info "restore to ${RESTORE_TIME_END} completed"
	elif [[ -d ${INCREMENTALBACKUP} ]]; then
		echo_color info "you choose FULL BACKUP RESTORE AND INCREMENT RESTORE...."
		echo_color info "you can visit ${restorelog_detail} to known more:  tail -100f ${restorelog_detail}"
		echo_color info "ready apply-log"
		#innobackupex --apply-log ${FULL_RESTORE_ONLY} >> ${restorelog_detail}   2>&1 || exits "apply-log fialed"
		FULL_LIST=$(find ${FULLBACKUP} -type d -name [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | awk -F / '{print $NF}' | sort)
		INCR_LIST=$(find ${INCREMENTALBACKUP} -type d -name [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | awk -F / '{print $NF}' | sort)
		for i in ${FULL_LIST}
		do
			if [[ ${i} < ${RESTORE_TIME_END} ]] || [[ ${i} = ${RESTORE_TIME_END} ]] ;then
				export NEED_RESTORE_FULL=${i}
			else
				break
			fi
		done
		export NEED_RESTORE_INCR=""
		#export NEED_INCR_TOTAL=0

		for j in ${INCR_LIST}
		do
			if [[ ${j} < ${RESTORE_TIME_END} ]] && [[ ${j} > ${NEED_RESTORE_FULL} ]]; then
				export NEED_RESTORE_INCR="${NEED_RESTORE_INCR} ${j}"
				#export NEED_INCR_TOTAL=$[ ${NEED_INCR_TOTAL} + 1 ]
			else
				continue
			fi
		done

		echo "FULL: ${NEED_RESTORE_FULL}"
		echo "INCR: ${NEED_RESTORE_INCR} ${RESTORE_TIME_END}"

		echo "innobackupex --apply-log --redo-only ${FULLBACKUP}/${NEED_RESTORE_FULL}"
		innobackupex --apply-log --redo-only ${FULLBACKUP}/${NEED_RESTORE_FULL} >> ${restorelog_detail}   2>&1 || exits "apply-log fialed"
		#echo "innobackupex --apply-log --redo-only ${FULLBACKUP}/${NEED_RESTORE_FULL} >> ${restorelog_detail}   2>&1"


		for k in ${NEED_RESTORE_INCR} 
		do
			echo "innobackupex --apply-log --redo-only ${FULLBACKUP}/${NEED_RESTORE_FULL} --incremental-dir=${INCREMENTALBACKUP}/${k}"
			innobackupex --apply-log  --redo-only ${FULLBACKUP}/${NEED_RESTORE_FULL} --incremental-dir=${INCREMENTALBACKUP}/${k} >> ${restorelog_detail}   2>&1 # || exits "apply-log fialed"
			#echo "innobackupex --apply-log --redo-only ${FULLBACKUP}${NEED_RESTORE_FULL} --incremental-dir=${INCREMENTALBACKUP}/${k}"
		done

		echo "innobackupex --apply-log ${FULLBACKUP}/${NEED_RESTORE_FULL} --incremental-dir=${INCREMENTALBACKUP}/${RESTORE_TIME_END}"
		innobackupex --apply-log ${FULLBACKUP}/${NEED_RESTORE_FULL} --incremental-dir=${INCREMENTALBACKUP}/${RESTORE_TIME_END} >> ${restorelog_detail}   2>&1 || exits "apply-log fialed"
		#echo "innobackupex --apply-log ${FULLBACKUP}/${NEED_RESTORE_FULL} --incremental-dir=${INCREMENTALBACKUP}/${RESTORE_TIME_END} >> ${restorelog_detail}"

		echo_color info "stop mysql with ${STOP_MYSQL_COMMAND}"
		bash ${STOP_MYSQL_COMMAND} 
		echo $(ssh 127.0.0.1 -p ${PORT} -o ConnectTimeout=1 -o BatchMode=yes -o StrictHostKeyChecking=yes 2>&1 ) | grep refused >/dev/null 2>&1 || exits "stop mysql failed"
		[[ -d ${REDOLOGDIR} ]] && mv ${REDOLOGDIR} ${REDOLOGDIR%/*}/redolog.backup${dtbegin}
		#这个地方很神奇, 只能单中括号, 双中括号判断不了, 不知道为啥
		[ -d ${INNODBDATA_HOME_DIR} ] && mv ${INNODBDATA_HOME_DIR} ${INNODBDATA_HOME_DIR%/*}/innodblog.backup${dtbegin}
		[[ -d ${DATADIR} ]] && mv ${DATADIR} ${DATADIR%/*}/data.backup${dtbegin}

		echo_color info "begin recover redolog and innodb_data and data "
		innobackupex --defaults-file=${DEFAULTS_FILE} --copy-back --rsync ${FULLBACKUP}/${NEED_RESTORE_FULL} >> ${restorelog_detail} 2>&1 || exits "copy-backup failed"
		chown ${MYSQL_USER_OS}:${MYSQL_USER_OS} ${REDOLOGDIR} ${INNODBDATA_HOME_DIR} ${DATADIR} -R
		echo_color info "start mysql with ${START_MYSQL_COMMAND}"
		bash ${START_MYSQL_COMMAND}
		#mysql -s  -u${USER} -p${PASSWORD} -P${PORT} -e "show databases;" >/dev/null 2>&1 || exits "start mysql filed"
		echo $(ssh 127.0.0.1 -p ${PORT} -o ConnectTimeout=1 -o BatchMode=yes -o StrictHostKeyChecking=yes 2>&1 ) | grep refused >/dev/null 2>&1 && exits "start mysql failed"
		echo_color info "restore to ${RESTORE_TIME_END} completed"
	fi
}

init_
restore_check_
restore
