#!/usr/bin/env bash
#write by ddcw @https://github.com/ddcw


#可以修改的参数
CONCURRENCY=4                #并发数量
SLEEP_INTERNAL="0.01"        #每隔 SLEEP_INTERNAL 秒, 检查一次 是否有导入完成的进程
IGNORE_GTID_CHECK="1"        #如果为1, 表示不检查GTID是否存在
IGNORE_FUCNTION_CREATOR="1"  #如果为1, 表示不检查log_bin_trust_function_creators是否为1
IGNORE_DISABLE_ENGINE="0"    #如果为1, 表示不检查disabled_storage_engines是否含MyISAM
LOGFILE="import.log"         #导入日志. 和控制台输出的内容一样
DIRNAME=$1                   #已经拆分了的 mysqldump 导出的SQL文件目录

#MYSQL连接信息
MYSQL_COM="mysql -h127.0.0.1 -p123456 -P3314 -uroot "


touch ${LOGFILE}
#不可修改参数
MYSQL_VERSION=()            #MYSQL SERVER版本信息
export LANG="en_US.UTF-8"   #设置LANG
POSTMSG=""                  #结尾时打印的信息, 先保存起来
APP_TABLE_TIME_COUNT="0"    #导入业务表的时间
DB_COUNT=0                  #导入的库计数, 不含系统库
FILES_COUNT=0               #导入的文件计数. 只考虑业务表
FAIL_COUNT_1=`grep ' FAILED$' ${LOGFILE} | wc -l` #记录之前日志的报错信息
ERROR_COUNT=0               #error计数

exit1(){
	echo "`date "+%Y-%m-%d %H:%M:%S"` ${@}"
	exit 1
}
[ "${DIRNAME}" == "" ] && exit1 "sh $0 splitByddcw_XXXXXX"
[ -d ${DIRNAME} ] || exit1 "${DIRNAME} is not exists"
DIRNAME=${DIRNAME%/}  #格式化目录变量, 去掉结尾的/  方便目录拼接

log(){
	_msg="$(date '+%Y-%m-%d %H:%M:%S') $@"
	echo -e ${_msg} # | tee -a ${LOGFILE}
	echo -e ${_msg} >> ${LOGFILE}
	
}

import_sql(){
	file=$1
	ts=`date +%s`
	log "IMPORT ${file} BEGIN..."
	#${MYSQL_COM} < $file >>${LOGFILE} 2>&1 && log "IMPORT ${file} SUCCESS." || log "IMPORT ${file} FAILED"
	if ${MYSQL_COM} < $file >>${LOGFILE} 2>&1;then
		log "IMPORT ${file} SUCCESS."
	else
		log "IMPORT ${file} FAILED"
		((ERROR_COUNT++))
		return 1
	fi
	te=`date +%s`
	log "IMPORT ${file} FINISH. cost $[ ${te} - ${ts} ] seconds"
	return 0
}

CHECK_CONN(){
	if ${MYSQL_COM} -e "select 1+1" >>${LOGFILE} 2>&1; then
		log "CONNCT SUCCESS."
	else
		exit1 "CONNCT FAILD. Please read log (${LOGFILE}) FAILED!"
	fi
	log "CHECK_CONN OK"
}

CHECK_GTID(){
	current_gtid=`${MYSQL_COM} -NB -e "select @@GLOBAL.GTID_EXECUTED" 2>>${LOGFILE}`
	if [ "${current_gtid}" != "" ] && [ "${IGNORE_GTID_CHECK}" != "1" ];then
		exit1 "CURRENT GTID: ${current_gtid} FAILED!"
	fi
	log "CHECK_GTID OK"
}

CHECK_VERSION(){
	IFS='.' read -r -a MYSQL_VERSION <<< `${MYSQL_COM} -NB -e "select @@version" 2>>${LOGFILE}`
	if [ "${MYSQL_VERSION[0]}" == "5" ] || [ "${MYSQL_VERSION[0]}" == "8" ]  ;then
		log "MYSQL VERSION: ${MYSQL_VERSION[@]}"
	else
		exit1 "ONLY FOR MYSQL 5/8, CURRENT MYSQL VERSION:${MYSQL_VERSION[@]} FAILED!"
	fi
	log "CHECK_VERSION OK"
}

CHECK_VARIABELS(){
	disabled_storage_engines=`${MYSQL_COM} -NB -e "select @@disabled_storage_engines" 2>>${LOGFILE}`
	if echo "${disabled_storage_engines}" | grep -i "MyISAM" >/dev/null;then
		if [ "${IGNORE_DISABLE_ENGINE}" != "1" ];then
			exit1 "disabled_storage_engines=${disabled_storage_engines} FAILED"
		fi
	else
		log "disabled_storage_engines=${disabled_storage_engines} OK"
	fi

	log_bin_trust_function_creators=`${MYSQL_COM} -NB -e "select @@log_bin_trust_function_creators" 2>>${LOGFILE}`
	if [ "${log_bin_trust_function_creators}" == "0" ] && [ "${IGNORE_FUCNTION_CREATOR}" != "1" ];then
		exit1 "log_bin_trust_function_creators=${log_bin_trust_function_creators} FAILED"
	else
		log "log_bin_trust_function_creators=${log_bin_trust_function_creators} OK"
	fi
	log "CHECK_VARIABELS OK"
}


IMPORT_CHANGE_MASTER(){
	echo ""
}


IMPORT_GTID(){
	if [ -f ${DIRNAME}/dbs/gtid.sql ];then
		log "\n\n#################### IMPORT GTID #####################"
	else
		log "SKIP IMPORT GTID"
		return 1
	fi
	import_sql ${DIRNAME}/dbs/gtid.sql || POSTMSG="${POSTMSG}\n ${DIRNAME}/dbs/gtid.sql IMPORT FAILED"
}


IMPORT_DATABASE_DDL(){
	if [ -f ${DIRNAME}/dbs/create.sql ];then
		log "\n\n#################### IMPORT CREATE DATABASE DDL #####################"
	else
		log "SKIP IMPORT DATABASE DDL"
		return 1
	fi
	import_sql ${DIRNAME}/dbs/create.sql || POSTMSG="${POSTMSG}\n ${DIRNAME}/dbs/create.sql IMPORT FAILED"
}


IMPORT_MYSQL_DATABASE(){
	if [ -d ${DIRNAME}/dbs/mysql ];then
		log "\n\n#################### IMPORT MYSQL DB #####################"
	else
		log "SKIP IMPORT mysql DATABASE"
		return 1
	fi
	for filename in ${DIRNAME}/dbs/mysql/*.sql; do
		import_sql ${filename} || POSTMSG="${POSTMSG}\n ${filename} IMPORT FAILED"
	done
}

IMPORT_MYSQL_STATICS(){
	if [ -f ${DIRNAME}/dbs/special.sql ];then
		log "\n\n#################### IMPORT MYSQL DB STATICS (ONLY FOR mysql 8.x) #####################"
	else
		log "SKIP IMPORT mysql statics. MYSQL_VERSION: ${MYSQL_VERSION[@]}"
		return 1
	fi
	import_sql ${DIRNAME}/dbs/special.sql || POSTMSG="${POSTMSG}\n ${DIRNAME}/dbs/special.sql IMPORT FAILED"
}

#并发导入业务表
IMPORT_APP_TABLE(){
	log "\n\n#################### IMPORT APP TABLE&DATA #####################"
	T_START=`date +%s`
	PIDS=()
	for dirname in `find ${DIRNAME}/dbs -type d`;do
		postname=`echo ${dirname} | awk -F '/' '{print $NF}'`
		if [ "${postname}" == "mysql" ] || [ "${postname}" == "" ] || [ "${DIRNAME}/dbs" == "${dirname}" ];then
			continue #跳过mysql库
		fi
		log "IMPORT DATABSE FOR ${postname} BEGIN"
		#PIDS=()
		db_start_time=`date +%s`
		for filename in `find ${dirname} -name '*.sql'`;do
			while [ ${#PIDS[@]} -ge ${CONCURRENCY} ];do
				sleep ${SLEEP_INTERNAL}
				for i in "${!PIDS[@]}";do
					if ! kill -0 "${PIDS[$i]}" 2>/dev/null;then
						unset 'PIDS[i]' #这个导入进程跑完了. 就从数组里面移除
					fi
				done
				PIDS=("${PIDS[@]}") #重新初始化一下PIDS
			done
			import_sql "${filename}" & #放后台导入, 也就是开并发
			PIDS+=($!)
			((FILES_COUNT++))
		done
		#wait #等待这个库的所有表导完. 不然进程数可能超过设置的大小. 也就是去掉之后性能能提升一部分
		db_stop_time=`date +%s`
		((DB_COUNT++))
		log "IMPORT DATABSE FOR ${postname} FINISH.  COST_TIME: $[ ${db_stop_time} - ${db_start_time} ] SECONDS."
	done
	wait #等待所有后台进程跑完
	T_STOP=`date +%s`
	APP_TABLE_TIME_COUNT="$[ ${T_STOP} - ${T_START} ]"
}


IMPORT_APP_EVENT(){
	log "\n\n#################### IMPORT APP EVENTS #####################"
	for filename in `find ${DIRNAME}/events -name '*.sql'`;do
		import_sql ${filename}
	done
}

IMPORT_APP_ROUTINE(){
	log "\n\n#################### IMPORT APP ROUTINES #####################"
	for filename in `find ${DIRNAME}/routines -name '*.sql'`;do
		import_sql ${filename}
	done
}

IMPORT_APP_VIEW(){
	log "\n\n#################### IMPORT APP VIEWS #####################"
	for filename in `find ${DIRNAME}/views -name '*.sql'`;do
		import_sql ${filename}
	done
}



_START_DT=`date +%s`

echo -e "\n\n********** BEGIN CHECK **************"
#检查能否连接
CHECK_CONN

#检查GTID是否存在
CHECK_GTID

#检查版本
CHECK_VERSION

#检查变量disabled_storage_engines log_bin_trust_function_creators
CHECK_VARIABELS
echo "********** CHECK FINISH **************\n\n"




#数据导入
echo "\n\n********** BEGIN IMPORT DATA **************"

#导入change master语句. 默认注释, 需要人工启用
IMPORT_CHANGE_MASTER

#导入GTID(8.0.x)
if [ "${MYSQL_VERSION[0]}" == "8" ];then
	IMPORT_GTID
fi

#导入数据库DDL
IMPORT_DATABASE_DDL

#导入系统库表
IMPORT_MYSQL_DATABASE

#导入统计信息
IMPORT_MYSQL_STATICS

#业务表(并发)(可能含触发器)
IMPORT_APP_TABLE


#导入EVENT
IMPORT_APP_EVENT

#业务存储过程和函数
IMPORT_APP_ROUTINE

#业务视图
IMPORT_APP_VIEW

#导入GTID(5.7.x)
if [ "${MYSQL_VERSION[0]}" == "5" ];then
	IMPORT_GTID
fi

_STOP_DT=`date +%s`
FAIL_COUNT_2=`grep ' FAILED$' ${LOGFILE} | wc -l`
log "APP DATABASE COUNT: ${DB_COUNT}    APP TABLE COUNT: ${FILES_COUNT}    APP DATA IMPORT COST_TIME: ${APP_TABLE_TIME_COUNT} SECONDS."
log "IMPORT ALL FINISH. TOTAL COST TIME $[ ${_STOP_DT} - ${_START_DT} ] SECONDS.  FAILED COUNT: $[ ${FAIL_COUNT_2} - ${FAIL_COUNT_1} ]"
log "ERROR COUNT: ${ERROR_COUNT}"
if [ "${POSTMSG}" != "" ];then
	log "${POSTMSG}"
fi

#统计信息导入失败
if echo "${POST}" | grep -E "innodb_index_stats.sql|innodb_table_stats.sql" >/dev/null 2>&1 ;then
	log "统计信息导入失败, 原因可能为 5.7 --> 8.0 建议如下:\n\t 1. 手动 导入统计信息表(删除DROP TABLE和CREATE TABLE之后在导入)\n\t 2. 手动使用 ANALYZE TABLE 去收集统计信息"
fi
