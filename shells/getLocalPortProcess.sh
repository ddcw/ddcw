#!/usr/bin/env bash
#write by ddcw at 2021.07.21
#modified by ddcw at 2021.08.26
#modified by ddcw at 2021.09.08 添加显示本地IP的功能,
echo -e "HOST \t\t PORT \t PID \t OPEN_FILES \t COMMAND"
for procnum in /proc/[0-9]*
do
	for inodes in $(ls -l ${procnum}/fd 2>/dev/null | grep  socket: | awk -F [ '{print $2}' | awk -F ] '{print $1}')
	do
		PORT=$(awk -v inode2="${inodes}" '{if ($10 == inode2) print $2}' /proc/net/tcp | awk -F : '{print $2}')
		HOST=$(awk -v inode2="${inodes}" '{if ($10 == inode2) print $2}' /proc/net/tcp | awk -F : '{print $1}')
		PORT=$((0x${PORT}))
		HOST1=$((0x${HOST:6:2}))
		HOST2=$((0x${HOST:4:2}))
		HOST3=$((0x${HOST:2:2}))
		HOST4=$((0x${HOST:0:2}))
		if [[ ${PORT} -gt 0 ]];then
			echo -e "${HOST1}.${HOST2}.${HOST3}.${HOST4} \t ${PORT} \t ${procnum##*/} \t $(ls ${procnum}/fd 2>/dev/null | wc -l) \t\t $(cat ${procnum}/comm)"
		fi
	done
done
