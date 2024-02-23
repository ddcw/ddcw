#!/usr/bin/env bash
#write by ddcw @https://github.com/ddcw
#跟进mysql导入进程打印其进度
# $1 = `pidof mysqld`
export LANG="en_US.UTF-8"

jindutiao(){
	percentage=$1
	msg=$2
	filled_length=$[ ${percentage} / 2 ]
	bar=$(printf "%-50s" "$(printf '#%.0s' $(seq 1 $filled_length))")
	echo -ne "\r[$bar] $percentage% ${msg}"
}

MYSQL_PID=$1
FILENAME=""
#检查mysql进程号是否存在
if [ "$1" == "" ];then
	MYSQL_PID=`pidof mysql | awk '{print $1}'`
	if [ "${MYSQL_PID}" == "" ];then
		echo -e "no mysql pid\n sh $0 mysql_pid"
		exit 3
	fi
elif [ ! -f "/proc/$1/io" ];then
	echo "${PID} is not exists. Please check by yourself"
	exit 1
fi
FILENAME=`ls -l /proc/${MYSQL_PID}/fd/0 | awk '{print $NF}'`

#检查文件是否存在
if [ ! -f ${FILENAME} ];then
	echo "${FILENAME} is not exists. Please check by yourself!"
	exit 2
fi

SLEEP_INTER=1
LAST_SIZE=1
TOTAL_SIZE=`stat -c '%s' ${FILENAME}`
IS_RUN=0
while [ 1 -eq 1 ];do
	CURRENT_SIZE=`awk '{ if ($1=="rchar:") print $2}' /proc/${MYSQL_PID}/io 2>/dev/null`
	if [ "${CURRENT_SIZE}" == "" ];then
		#不存在了. 也就是导完了
		if [ ${IS_RUN} -eq 1 ];then
			jindutiao "100"
		fi
		break 1
	elif [ ${CURRENT_SIZE} -lt ${TOTAL_SIZE} ];then
		#打印进度
		REST_SIZE=$[ ${TOTAL_SIZE} - ${CURRENT_SIZE} ]
		RATE=$[ (${CURRENT_SIZE} - ${LAST_SIZE}) / ${SLEEP_INTER} ]
		if [ ${RATE} -gt 0 ];then #如果速度大于0, 就计算剩余的时间
			REST_TIME=$[ ${REST_SIZE} / ${RATE} ]
			#时间格式化
			if [ $[ ${REST_TIME} / 60 / 60 / 24 ] -ge 1 ];then
				REST_TIME=$[ ${REST_TIME} / 60 / 60 / 24 ]" days"
			elif [ $[ ${REST_TIME} / 60 / 60 ] -ge 1 ];then
				REST_TIME=$[ ${REST_TIME} / 60 / 60 ]" hours"
			elif [ $[ ${REST_TIME} / 60 ] -ge 1 ];then
				REST_TIME=$[ ${REST_TIME} / 60 ]" minutes"
			else
				REST_TIME="${REST_TIME} seconds"
			fi

			#速度格式化
			if [ $[ ${RATE} / 1024 / 1024 / 1024 ] -ge 1 ];then
				RATEH=$[ ${RATE} / 1024 / 1024 / 1024 ]" GB/s"
			elif [ $[ ${RATE} / 1024 / 1024 ] -ge 1 ];then
				RATEH=$[ ${RATE} / 1024 / 1024 ]" MB/s"
			elif [ $[ ${RATE} / 1024 ] -ge 1 ];then
				RATEH=$[ ${RATE} / 1024 ]" KB/s"
			else
				RATEH="{RATE} B/s"
			fi
		else
			REST_TIME=""
			RATEH=${RATE}
		fi
		jindutiao "$[ ${CURRENT_SIZE} * 100 / ${TOTAL_SIZE} ]" " Time Remaining: ${REST_TIME} Rate: ${RATEH}"
	elif [ ${CURRENT_SIZE} -ge ${TOTAL_SIZE} ];then
		jindutiao "100"
		break
	fi
	LAST_SIZE=${CURRENT_SIZE}
	IS_RUN=1
	sleep ${SLEEP_INTER}
done
echo ""
