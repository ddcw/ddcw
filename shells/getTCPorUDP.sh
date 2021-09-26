#!/usr/bin/env bash
#write by ddcw at 2021.09.08
type1="tcp"
[[ ${1,,} == "udp" ]] >/dev/null 2>&1 && type1="udp"
[[ ${1,,} -eq 2 ]] >/dev/null 2>&1 && type1="udp"
echo -e "LOCAL_HOST \t LOCAL_PORT \t\t REM_HOST \t\t REM_PORT \t\t INODE "
FIRST_LINE=1
while read line
do
	[[ ${FIRST_LINE} -eq 1 ]] && FIRST_LINE=2 && continue
	src=$(echo ${line} | awk '{print $2}')
	src_host=${src%:*}
	src_port=${src##*:}
	dst=$(echo ${line} | awk '{print $3}')
	dst_host=${dst%:*}
	dst_port=${dst##*:}
	inode=$(echo ${line} | awk '{print $(10)}')
	echo -e "$((0x${src_host:6:2})).$((0x${src_host:4:2})).$((0x${src_host:2:2})).$((0x${src_host:0:2})) \t $((0x${src_port})) \t\t\t $((0x${dst_host:6:2})).$((0x${dst_host:4:2})).$((0x${dst_host:2:2})).$((0x${dst_host:0:2})) \t\t $((0x${dst_port})) \t\t\t ${inode}"
done < /proc/net/${type1}


