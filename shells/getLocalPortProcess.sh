#!/bin/env bash
#write by ddcw at 2021.07.21
echo -e "PID \t PORT \t OPEN_FILEs \t cmdline"
for procnum in /proc/[0-9]*
do
	for inodes in $(ls -l ${procnum}/fd | grep  socket: | awk -F [ '{print $2}' | awk -F ] '{print $1}')
	do
		PORT=$(awk -v inode2="${inodes}" '{if ($10 == inode2) print $2}' /proc/net/tcp | awk -F : '{print $2}')
		PORT=$((0x${PORT}))
		if [[ ${PORT} -gt 0 ]];then
			echo -e "${procnum##*/} \t ${PORT} \t $(ls ${procnum}/fd | wc -l) \t\t $(cat ${procnum}/cmdline)"
		fi
	done
done
