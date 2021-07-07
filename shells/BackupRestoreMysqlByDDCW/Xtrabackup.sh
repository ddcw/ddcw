#!/bin/env bash
#write by ddcw at 2021.07.01
#自动备份脚本, 采用xtrabackup备份, 支持增量备份和全量备份, 不支持备份恢复.不支持压缩
#不支持远程备份, 远程备份可以参考xbstream

#授权推荐命令
#create user "backup"@"%" identified WITH 'mysql_native_password' by "backup";
#grant RELOAD,PROCESS,REPLICATION CLIENT on *.* to "backup"@"%";
#flush privileges;

SOCKET=/data/3366/prod/mysql.sock
USER=backup
PASSWORD=backup
PORT=3366
DEFAULTS_FILE=/data/3366/conf/my_3366.cnf
PARALLEL=2

BACKUP_DIR=/data/backup

#备份目录, 以下为默认设置, 也可以手动设置
#FULLBACKUP=${BACKUP_DIR%/#}/FULLBACKUP
#INCREMENTALBACKUP=${BACKUP_DIR%/#}/INCREMENT_BACKUP

#0表示全备, 1表示增量备份
INCREMENTAL=0
[[ -z $1 ]] || export INCREMENTAL=$1




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
	echo_color error "bakcup be killed, and it will be exit.  this backup cost $( $[ $(date +%s) - ${dtbegin} ] ) secconds."
	[[ -f ${FULLBACKUP%/#}/fullbackup${dtbegin}.log ]] && echo "you can visit ${FULLBACKUP%/#}/fullbackup${dtbegin}.log to known more"
	[[ -f ${INCREMENTALBACKUP%/#}/incrementbackup${dtbegin}.log ]] && echo "you can visit ${INCREMENTALBACKUP%/#}/incrementbackup${dtbegin}.log to known more"
        exit 2
}


#初始化的, 我也不知道要初始化啥
function init_() {
	which innobackupex >/dev/null 2>&1 || exits "env has no command innobackupex"
	which mysql >/dev/null 2>&1 || exits "env has no command mysql"
	[[ ${PARALLEL} -eq ${PARALLEL} ]] >/dev/null || exits "PARALLEL must be int"
	[[ -S ${SOCKET} ]] || exits "no socket file ${SOCKET}"
	mysql -s -S ${SOCKET} -u${USER} -p${PASSWORD} -P${PORT} -e "show databases;" >/dev/null 2>&1 || exits "cant login mysql:  mysql -s -S ${SOCKET} -u${USER} -p${PASSWORD} -P${PORT}"
	[[ -z ${FULLBACKUP} ]] && export FULLBACKUP=${BACKUP_DIR%/#}/FULLBACKUP
	[[ -z ${INCREMENTALBACKUP} ]] && export INCREMENTALBACKUP=${BACKUP_DIR%/#}/INCREMENT_BACKUP
	mkdir -p ${BACKUP_DIR} ${FULLBACKUP} ${INCREMENTALBACKUP} >/dev/null 2>&1
	[[ -d ${BACKUP_DIR} ]] || exits "no dir ${BACKUP_DIR}"
	[[ -d ${FULLBACKUP} ]] || exits "no dir ${FULLBACKUP}"
	[[ -d ${INCREMENTALBACKUP} ]] || exits "no dir ${INCREMENTALBACKUP}" 

	#判断最新的备份, 因为增量备份的时候要用最新的备份(节约点空间), 最新的备份可能是增量备份也可能是全量备份. 所以都要判断
	LAST_FULLBACKUP=${FULLBACKUP%/#}/$(ls ${FULLBACKUP} | grep -E "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" | sort | tail -1)
	LAST_INCREMENTALBACKUP=${INCREMENTALBACKUP%/#}/$(ls ${INCREMENTALBACKUP} | grep -E "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" | sort | tail -1)
	[[ ${LAST_FULLBACKUP#${FULLBACKUP%/#}/*} < ${LAST_INCREMENTALBACKUP#${INCREMENTALBACKUP%/#}/*} ]] && export LAST_BACKUP=${LAST_INCREMENTALBACKUP} || export LAST_BACKUP=${LAST_FULLBACKUP}
}

function backup() {
	export dtbegin=$(date +%s)
	if [[ ${INCREMENTAL} -eq 0 ]]; then
		echo_color info "begin full backup: you can visit ${FULLBACKUP}/fullbackup${dtbegin}.log"
		innobackupex --defaults-file=${DEFAULTS_FILE} --user=${USER} --password=${PASSWORD} --socket=${SOCKET} --parallel=${PARALLEL} ${FULLBACKUP}  2> ${FULLBACKUP}/fullbackup${dtbegin}.log
		backupfinish="full"
		echo_color info "full backup dir:  ${FULLBACKUP}/$(ls ${FULLBACKUP} | grep -E "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" | sort | tail -1)"
		echo_color info "full backup size: $(du -sh ${FULLBACKUP}/$(ls ${FULLBACKUP} | grep -E "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" | sort | tail -1) | awk '{print $1}')"
		echo_color info "full backup log:  ${FULLBACKUP}/fullbackup${dtbegin}.log"

	elif [[ ${INCREMENTAL} -eq 1 ]]; then
		echo_color info "begin increment backup: you can visit ${INCREMENTALBACKUP}/incrementbackup${dtbegin}.log"
		innobackupex --defaults-file=${DEFAULTS_FILE} --user=${USER} --password=${PASSWORD} --socket=${SOCKET} --parallel=${PARALLEL} --incremental ${INCREMENTALBACKUP} --incremental-basedir=${LAST_BACKUP} 2> ${INCREMENTALBACKUP}/incrementbackup${dtbegin}.log
		backupfinish="increment"
		echo_color info "its basedir ${LAST_BACKUP}"
		echo_color info "increment backup dir: ${INCREMENTALBACKUP}/$(ls ${INCREMENTALBACKUP} | grep -E "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" | sort | tail -1)"
		echo_color info "increment backup size: $(du -sh ${INCREMENTALBACKUP}/$(ls ${INCREMENTALBACKUP} | grep -E "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" | sort | tail -1) | awk '{print $1}')"
		echo_color info "increment backup log: ${INCREMENTALBACKUP}/incrementbackup${dtbegin}.log"

	else
		exits "INCREMENTAL must be 1 or 0 \n 0 is full backup, 1 is increment backup"
	fi
	#sleep 130
	dtend=$(date +%s)
	dtcost=$[ ${dtend} - ${dtbegin} ]
	if [[ ${dtcost} -le 120 ]];then
		echo_color info  "${backupfinish} backup finishd, its cos ${dtcost} secconds"
	else
		echo_color info  "${backupfinish} backup finishd, its cos about  $[ ${dtcost} / 60 ]  minutes"
	fi

}

init_
backup
