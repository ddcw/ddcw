#!/usr/bin/env bash
#write by ddcw at 20220601

source /etc/profile

#定义全局变量, 相当于配置文件, 只是懒得去整.

export LANG=en_US.UTF-8
export THIS_PID=$$
umask 0022 #EulerOS之类的默认umask可能不是0022, 会有目录权限问题
stty erase ^H

#数据库信息
MYSQL_HOST='127.0.0.1'
MYSQL_PORT='3308'
MYSQL_USER='root'
MYSQL_PASSWORD='123456'
MYSQL_SOCKET='/data/mysql_3308/run/mysql.sock' #暂不支持


#SLOW_LOG
#SLOW_LOG_FILE='/data/mysql_3308/mysqllog/dblogs/slow3308.log'  #为空的话, 就自动查询, 优先使用手动配置的
SLOW_LOG_MAX_SIZE='52428800' #慢日志最大的大小, 超过之后就切换日志, 并归档
SLOW_LOG_TAR_EXPIRE_DAYS='60' #切换之后的日志过期时间, 超过之后就删除
SLOW_LOG_TAR_DIR='' #切换之后的日志的保存目录, 为空的时候,表示原来的路径

#ERROR LOG
#ERROR_LOG_FILE='/data/mysql_3308/mysqllog/dblogs/mysql3308.err' #为空的话, 就自动查询
ERROR_LOG_MAX_SIZE='52428800' #错误日志大小, 超过就切换并归档
ERROR_LOG_TAR_EXPIRE_DAYS='60' #归档的错误日志的最大保存时间, 过期就删除
ERROR_LOG_TAR_DIR='' #切换之后的日志的保存目录

#GENERAL LOG
#GENERAL_LOG_FILE='/data/mysql_3308/mysqllog/dblogs/general3308.log' #为空就自动查询
GENERAL_LOG_MAX_SIZE='524288000' #500MB
GENERAL_LOG_TAR_EXPIRE_DAYS='60'
GENERAL_LOG_TAR_DIR=''


#BINLOG  不支持, 就系统自动清理就行, 也可以参考,
#PURGE BINARY LOGS TO 'mysql-bin.010';
#PURGE BINARY LOGS BEFORE '2022-04-02 22:46:26';

MYSQL1="mysql --host=${MYSQL_HOST} --port=${MYSQL_PORT} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD}"
MYSQL2="mysql --socket=${MYSQL_SOCKET} --password=${MYSQL_PASSWORD}"

echo_color(){
	echo "[$1][$(date +'%Y%m%d %H:%M:%S')] $2"
}

clear_error_log(){
	if [ "${ERROR_LOG_FILE}" == "" ];then
		echo_color "INFO" "error log (var:ERROR_LOG_FILE) is null, will auto get"
		ERROR_LOG_VAR=`echo $(${MYSQL1} -e "show global variables like 'log_error';" 2>/dev/null) | awk '{print $NF}'`
		if [ "${ERROR_LOG_VAR:0:1}" == "/" ];then
			ERROR_LOG_FILE=${ERROR_LOG_VAR}
		else
			ERROR_LOG_FILE=${MYSQL_DATA_DIR}${ERROR_LOG_VAR}
		fi
	fi

	if [ -f ${ERROR_LOG_FILE} ];then
		if $(${MYSQL1} -e "FLUSH ERROR LOGS;" 2>/dev/null);then
			if [ "${ERROR_LOG_TAR_DIR}" == "" ];then ERROR_LOG_TAR_DIR=${ERROR_LOG_FILE%/*};fi
			ERROR_LOG_FILE_NAME=${ERROR_LOG_FILE##*/}$(date +'%Y%m%d_%H%M%S')"_WILL_BE_DELETE"
			if [ $(du -sb ${ERROR_LOG_FILE} | awk '{print $1}') -gt ${ERROR_LOG_MAX_SIZE} ];then
				if mv ${ERROR_LOG_FILE} ${ERROR_LOG_TAR_DIR}/${ERROR_LOG_FILE_NAME};then
					${MYSQL1} -e "FLUSH ERROR LOGS;" 2>/dev/null || echo_color "ERROR" "maybe flush error log failed."
					old_tmp_dir=$(pwd)
					cd ${ERROR_LOG_TAR_DIR}
					tar -zcf ${ERROR_LOG_FILE_NAME}.tar.gz --remove-files ${ERROR_LOG_FILE_NAME} || echo_color "INFO" "tar -zcvf ${ERROR_LOG_TAR_DIR}/${ERROR_LOG_FILE_NAME}.tar.gz --remove-files ${ERROR_LOG_TAR_DIR}/${ERROR_LOG_FILE_NAME} failed. will be skip"
					cd ${old_tmp_dir}
					echo_color "INFO" "Rotation error log success"
					#tar成功之后, 清除过期的备份日志
					for need_remove_file in `find ${ERROR_LOG_TAR_DIR} -mtime +${ERROR_LOG_TAR_EXPIRE_DAYS} -name "*_WILL_BE_DELETE.tar.gz"`
					do
						if [ -f ${need_remove_file} ];then
							rm -rf ${need_remove_file} && echo_color "INFO" "delete error log ${need_remove_file} success"
						fi
					done
				else
					echo_color "ERROR" "mv ${ERROR_LOG_FILE} ${ERROR_LOG_TAR_DIR}/${ERROR_LOG_FILE_NAME} failed, will skip error log"
				fi
			else
				echo_color "INFO" "error log (${ERROR_LOG_FILE}) less than ${ERROR_LOG_MAX_SIZE}, will skip"
			fi
		else
			echo_color "ERROR" "Maybe Access denied; you need (at least one of) the RELOAD privilege(s) for this operation"
		fi
	else
		echo_color "INFO" "error log ${ERROR_LOG_FILE} not exist, will skip"
	fi
}

clear_slow_log(){
	if [ "${SLOW_LOG_FILE}" == "" ];then
		echo_color "INFO" "slow log (var:SLOW_LOG_FILE) is null, will auto get"
		SLOW_LOG_VAR=`echo $(${MYSQL1} -e "show global variables like 'slow_query_log_file';" 2>/dev/null) | awk '{print $NF}'`
		if [ "${SLOW_LOG_VAR:0:1}" == "/" ];then
			SLOW_LOG_FILE=${SLOW_LOG_VAR}
		else
			SLOW_LOG_FILE=${MYSQL_DATA_DIR}${SLOW_LOG_VAR}
		fi
	fi

	if [ -f ${SLOW_LOG_FILE} ];then
		if $(${MYSQL1} -e "FLUSH SLOW LOGS;" 2>/dev/null);then
			if [ "${SLOW_LOG_TAR_DIR}" == "" ];then SLOW_LOG_TAR_DIR=${SLOW_LOG_FILE%/*};fi
			SLOW_LOG_FILE_NAME=${SLOW_LOG_FILE##*/}$(date +'%Y%m%d_%H%M%S')"_WILL_BE_DELETE"
			if [ $(du -sb ${SLOW_LOG_FILE} | awk '{print $1}') -gt ${SLOW_LOG_MAX_SIZE} ];then
				if mv ${SLOW_LOG_FILE} ${SLOW_LOG_TAR_DIR}/${SLOW_LOG_FILE_NAME};then
					${MYSQL1} -e "FLUSH SLOW LOGS;" 2>/dev/null || echo_color "ERROR" "maybe flush slow log failed."
					old_tmp_dir=$(pwd)
					cd ${SLOW_LOG_TAR_DIR}
					tar -zcf ${SLOW_LOG_FILE_NAME}.tar.gz --remove-files ${SLOW_LOG_FILE_NAME} || echo_color "INFO" "tar -zcvf ${SLOW_LOG_TAR_DIR}/${SLOW_LOG_FILE_NAME}.tar.gz --remove-files ${SLOW_LOG_TAR_DIR}/${SLOW_LOG_FILE_NAME} failed. will be skip"
					cd ${old_tmp_dir}
					echo_color "INFO" "Rotation slow log success"
					#tar成功之后, 清除过期的备份日志
					for need_remove_file in `find ${SLOW_LOG_TAR_DIR} -mtime +${SLOW_LOG_TAR_EXPIRE_DAYS} -name "*_WILL_BE_DELETE.tar.gz"`
					do
						if [ -f ${need_remove_file} ];then
							rm -rf ${need_remove_file} && echo_color "INFO" "delete slow log ${need_remove_file} success"
						fi
					done
				else
					echo_color "ERROR" "mv ${SLOW_LOG_FILE} ${SLOW_LOG_TAR_DIR}/${SLOW_LOG_FILE_NAME} failed, will skip slow log"
				fi
			else
				echo_color "INFO" "slow log (${SLOW_LOG_FILE}) less than ${SLOW_LOG_MAX_SIZE}, will skip"
			fi
		else
			echo_color "ERROR" "Maybe Access denied; you need (at least one of) the RELOAD privilege(s) for this operation"
		fi
	else
		echo_color "INFO" "slow log ${SLOW_LOG_FILE} not exist, will skip"
	fi
}

clear_general_log(){
	if [ "${GENERAL_LOG_FILE}" == "" ];then
		echo_color "INFO" "GENERAL log (var:GENERAL_LOG_FILE) is null, will auto get"
		GENERAL_LOG_VAR=`echo $(${MYSQL1} -e "show global variables like 'general_log_file';" 2>/dev/null) | awk '{print $NF}'`
		if [ "${GENERAL_LOG_VAR:0:1}" == "/" ];then
			GENERAL_LOG_FILE=${GENERAL_LOG_VAR}
		else
			GENERAL_LOG_FILE=${MYSQL_DATA_DIR}${GENERAL_LOG_VAR}
		fi
	fi

	if [ -f ${GENERAL_LOG_FILE} ];then
		if $(${MYSQL1} -e "FLUSH GENERAL LOGS;" 2>/dev/null);then
			if [ "${GENERAL_LOG_TAR_DIR}" == "" ];then GENERAL_LOG_TAR_DIR=${GENERAL_LOG_FILE%/*};fi
			GENERAL_LOG_FILE_NAME=${GENERAL_LOG_FILE##*/}$(date +'%Y%m%d_%H%M%S')"_WILL_BE_DELETE"
			if [ $(du -sb ${GENERAL_LOG_FILE} | awk '{print $1}') -gt ${GENERAL_LOG_MAX_SIZE} ];then
				if mv ${GENERAL_LOG_FILE} ${GENERAL_LOG_TAR_DIR}/${GENERAL_LOG_FILE_NAME};then
					${MYSQL1} -e "FLUSH GENERAL LOGS;" 2>/dev/null || echo_color "ERROR" "maybe flush GENERAL log failed."
					old_tmp_dir=$(pwd)
					cd ${GENERAL_LOG_TAR_DIR}
					tar -zcf ${GENERAL_LOG_FILE_NAME}.tar.gz --remove-files ${GENERAL_LOG_FILE_NAME} || echo_color "INFO" "tar -zcvf ${GENERAL_LOG_TAR_DIR}/${GENERAL_LOG_FILE_NAME}.tar.gz --remove-files ${GENERAL_LOG_TAR_DIR}/${GENERAL_LOG_FILE_NAME} failed. will be skip"
					cd ${old_tmp_dir}
					echo_color "INFO" "Rotation GENERAL log success"
					#tar成功之后, 清除过期的备份日志
					for need_remove_file in `find ${GENERAL_LOG_TAR_DIR} -mtime +${GENERAL_LOG_TAR_EXPIRE_DAYS} -name "*_WILL_BE_DELETE.tar.gz"`
					do
						if [ -f ${need_remove_file} ];then
							rm -rf ${need_remove_file} && echo_color "INFO" "delete GENERAL log ${need_remove_file} success"
						fi
					done
				else
					echo_color "ERROR" "mv ${GENERAL_LOG_FILE} ${GENERAL_LOG_TAR_DIR}/${GENERAL_LOG_FILE_NAME} failed, will skip GENERAL log"
				fi
			else
				echo_color "INFO" "GENERAL log (${GENERAL_LOG_FILE}) less than ${GENERAL_LOG_MAX_SIZE}, will skip"
			fi
		else
			echo_color "ERROR" "Maybe Access denied; you need (at least one of) the RELOAD privilege(s) for this operation"
		fi
	else
		echo_color "INFO" "GENERAL log ${GENERAL_LOG_FILE} not exist, will skip"
	fi
}

if ${MYSQL1} -e "select @@version;" 1>/dev/null 2>&1 ;then
	export MYSQL_DATA_DIR=`echo $(${MYSQL1} -e "show global variables like 'datadir';" 2>/dev/null) | awk '{print $NF}'`
	clear_error_log
	clear_slow_log
	clear_general_log
else
	echo_color "ERROR" "connect failed, please check host:port or user/password"
fi
