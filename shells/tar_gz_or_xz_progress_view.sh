#!/usr/bin/env bash
#write by ddcw @https://github.com/ddcw
# tar.gz/tar.xz 解压进度查看脚本

export LANG="en_US.UTF-8"
SLEEP_INTERNAL=0.1

jindutiao2(){
	PID=$1
	lineno=$2
	PRONAME=`cat /proc/${PID}/comm`
	FILENAME=`ls -l /proc/${PID}/fd/0 | awk '{print $NF}'`
	SOURCE_SIZE=`stat -c "%s" ${FILENAME} | awk '{size = $1; if (size < 1024) { printf "%.2f B\n", size } else if (size < 1024 * 1024) { printf "%.2f KiB\n", size / 1024 } else if (size < 1024 * 1024 * 1024) { printf "%.2f MiB\n", size / 1024 / 1024 } else { printf "%.2f GiB\n", size / 1024 / 1024 / 1024 } }'`
	if [ "${PRONAME}" == "xz" ];then
		DEST_SIZE="`xz -l ${FILENAME} | tail -1 | awk '{print $5,$6}'`"
	elif [ "${PRONAME}" == "gzip" ];then
		DEST_SIZE="`gzip -l ${FILENAME} | tail -1 | awk '{print $2}' | awk '{size = $1; if (size < 1024) { printf "%.2f B\n", size } else if (size < 1024 * 1024) { printf "%.2f KiB\n", size / 1024 } else if (size < 1024 * 1024 * 1024) { printf "%.2f MiB\n", size / 1024 / 1024 } else { printf "%.2f GiB\n", size / 1024 / 1024 / 1024 } }'`"
	else
		break
	fi
	TOTAL_SIZE=`stat -c '%s' ${FILENAME}`
	CURRENT_SIZE=0
	OLD_SIZE=`awk '{ if ($1=="rchar:") print $2}' /proc/${PID}/io 2>/dev/null`
	START_TIME=`date +%s`
	CURRENT_RATE="0 B/s"
	#不使用 kill -0 pid , 怕审计不过...
	while [ ${CURRENT_SIZE} -lt ${TOTAL_SIZE} ] && [ -d /proc/${PID} ];do
		CURRENT_SIZE=`awk '{ if ($1=="rchar:") print $2}' /proc/${PID}/io 2>/dev/null`
		TIME_DIFF="$[ $(date +%s) - ${START_TIME}  ]"
		if [ "${CURRENT_SIZE}" == "" ];then
			break
		fi
		if [ ${TIME_DIFF} -gt 0 ];then
			CURRENT_RATE=`echo "${OLD_SIZE} ${CURRENT_SIZE} ${TIME_DIFF}" | awk '{print ($2-$1)/$3}' | awk '{size = $1; if (size < 1024) { printf "%.2f B/s\n", size } else if (size < 1024 * 1024) { printf "%.2f KiB/s\n", size / 1024 } else if (size < 1024 * 1024 * 1024) { printf "%.2f MiB/s\n", size / 1024 / 1024 } else { printf "%.2f GiB/s\n", size / 1024 / 1024 / 1024 } }'`
			REST_TIME=`echo "${TOTAL_SIZE} ${CURRENT_SIZE} ${TIME_DIFF} ${OLD_SIZE}" | awk '{print ($1-$2)/(($2-$4)/$3)}' | awk '{printf "%.2f seconds\n",$1}'`
		else
			CURRENT_RATE="0 B/s"
			REST_TIME="0"
		fi
		filled_len=$((CURRENT_SIZE * 50 / ${TOTAL_SIZE}))
		bar=$(printf "%-${filled_len}s" "#" | sed 's/ /#/g')
		spaces=$(printf "%-$((50-filled_len))s" "")
		echo -ne "\033[${lineno};0H${PID}: |$bar$spaces| $[ ${CURRENT_SIZE} * 100 / ${TOTAL_SIZE} ]% RATE:${CURRENT_RATE} THE_REST_TIME:${REST_TIME} "
		sleep ${SLEEP_INTERNAL}
	done
	echo -e "\033[${lineno};0H${PID}: Done               ${FILENAME} RATE:${CURRENT_RATE} COMM:${PRONAME}  ${SOURCE_SIZE} --> ${DEST_SIZE}"
}


PIDS=(`pidof gzip`)
PIDS+=(`pidof xz`)
if [ -z ${PIDS}  ];then
	echo "NO gzip or xz is Running. "
	exit 1
fi
current_no=0
clear
for pid in ${PIDS[@]};do
	((current_no++))
	jindutiao2 ${pid} ${current_no} &
done
wait
exit 0
