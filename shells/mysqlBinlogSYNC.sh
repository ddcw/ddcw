#!/bin/env bash
#write by ddcw at 2021.06.29
#不支持备份到远处, 你可以在要保存的服务器上运行本脚本
#mysqlbinlog和mysql命令需要配置在环境变量里

REMOTE_HOST="172.17.0.10"
REMOTE_PORT="3311"
REMOTE_USER="repuser"
REMOTE_PASSWORD="repuser"

#为空的话, 会先在LOCAL_PRENAME下找最新的binlog, 然后从那个Binlog开始同步. 
#如果该目录下没得的话, 就从当前登录查询到的lsn开始
#指定的话, 会从指定的Binlog开始, 不校验名字是否对之类的
BEGIN_BINLOG=""

#也就是保存binlog的目录前缀, 比如
#/data/bin1 的话, 就是 /data/bin1binlog.000002 这种, 很丑, 所有目录的话要加上/结尾,  此变量不格式化,  设置啥就是啥
#/data/bin1/  这样的话就是  /data/bin1/binlog.000002
#默认空的话, 就是当前目录
LOCAL_PRENAME=""

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

LOCAL_CURRENT_BINLOG=${BEGIN_BINLOG}

#判断ctrl+c
trap 'WhenCtrlC' INT
function WhenCtrlC () {
	binlog_file=$(ls ${LOCAL_PRENAME}${MASTER_BINLOG_PRE}* 2>/dev/null | grep -v \.index | sort | tail -1)
	lsn=$(mysqlbinlog ${binlog_file} | grep end_log_pos | grep server | grep CRC32 | awk -F end_log_pos '{print $2}' | awk '{print $1}' | tail -1)
	echo_color info "本程序被kill了, 当前最新的binlog是:${binlog_file}   lsn: ${lsn}"
	echo_color info "下次启动将自动开始同步(前提是你莫删掉最新的binlog, 也别移开)"
	exit 1
}

function init_() {
	#检查有没得mysql和mysqlbinlog命令
	which mysql >/dev/null 2>&1 || exits "no command mysql in env"
	which mysqlbinlog >/dev/null 2>&1 || exits "no command mysqlbinlog in env"
	#检查能否正常连接上去
	cat /dev/null > /tmp/.${0}_msyqltmpbyddcw.tmp
	mysql -s -h ${REMOTE_HOST} -P ${REMOTE_PORT} -u ${REMOTE_USER} -p${REMOTE_PASSWORD} -e "show master status;" 2>/dev/null  > /tmp/.${0}_msyqltmpbyddcw.tmp || exits "connect failed or exec 'show master status;' failed"
	#echo "/tmp/.${0}_msyqltmpbyddcw.tmp"
	export MASTER_CURRENT_BINLOG=$(awk '{print $1}' /tmp/.${0}_msyqltmpbyddcw.tmp)
	export MASTER_CURRENT_LSN=$(awk '{print $2}' /tmp/.${0}_msyqltmpbyddcw.tmp)
	export MASTER_BINLOG_PRE=$(echo ${MASTER_CURRENT_BINLOG} | awk -F \. '{print $1}')
	[[ -z ${LOCAL_CURRENT_BINLOG} ]] && LOCAL_CURRENT_BINLOG=$(ls ${LOCAL_PRENAME}${MASTER_BINLOG_PRE}* 2>/dev/null | grep -v \.index | sort | tail -1)
	[[ -z ${LOCAL_CURRENT_BINLOG} ]] && export LOCAL_CURRENT_BINLOG=${MASTER_CURRENT_BINLOG}	
	[[ -z ${LOCAL_CURRENT_BINLOG} ]] && exits "请设置起使的binlog, 自动获取失败"
	[[ -f ${LOCAL_PRENAME}${LOCAL_CURRENT_BINLOG} ]] && export LOCAL_LSN=$(mysqlbinlog ${LOCAL_PRENAME}${LOCAL_CURRENT_BINLOG} | grep end_log_pos | grep server | grep CRC32 | awk -F end_log_pos '{print $2}' | awk '{print $1}' | tail -1)
	[[ -z ${LOCAL_LSN} ]] && export LOCAL_LSN=${MASTER_CURRENT_LSN}
}

function main_() {
	echo_color info "开始同步binlog"
	echo_color info "当前的binlog: ${LOCAL_CURRENT_BINLOG}    LSN: ${LOCAL_LSN}"
	if [[ -z ${LOCAL_PRENAME} ]];then
		while :
		do
			mysqlbinlog --read-from-remote-server --raw --host=${REMOTE_HOST} --port=${REMOTE_PORT} --user=${REMOTE_USER} --password=${REMOTE_PASSWORD} --stop-never ${LOCAL_CURRENT_BINLOG} 2>/dev/null
			echo_color warn "mysqlbinlog stopd with some error, and begin after 10s"
			sleep 10
		done
	else
		while :
		do
			mysqlbinlog --read-from-remote-server --raw --host=${REMOTE_HOST} --port=${REMOTE_PORT} --user=${REMOTE_USER} --password=${REMOTE_PASSWORD} --stop-never ${LOCAL_CURRENT_BINLOG} --result-file=${LOCAL_PRENAME} 2>/dev/null
			echo_color warn "mysqlbinlog stopd with some error, and begin after 10s"
			sleep 10
		done
	fi
	
}

init_
main_
