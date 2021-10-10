#!/usr/bin/env bash
#write by ddcw at 2021.10.10

#统计部分文件虚大的.
#用法: sh dulsdiffddcw.sh dir

jindutiao(){
	jindutiaoflag=""
	jindutiaoflagn="0"
	max=100
	current=$[ ${1} * 100 / ${2} ] 
	baifenbi=$[ ${current} * 100 / ${max}  ]
	while [[  ${jindutiaoflagn} -lt ${baifenbi} ]];	do jindutiaoflagn=$[ ${jindutiaoflagn} + 1 ] jindutiaoflag="${jindutiaoflag}\033[32;40m#\033" ;done
	while [[ ${jindutiaoflagn} -lt ${max} ]]; do jindutiaoflagn=$[ ${jindutiaoflagn} + 1 ] jindutiaoflag="${jindutiaoflag}\033[31;40m.\033[0m"; done
	echo -ne "\r${baifenbi}% [${jindutiaoflag}] $1/$2"
}


#du -b 统计的和ls看到的一样, 故采用du -k
wuchazhi=$2
[[ ${wuchazhi} -eq ${wuchazhi} ]] 2>/dev/null || wuchazhi=$(getconf PAGESIZE)
[[ -z ${wuchazhi} ]] && wuchazhi=$(getconf PAGESIZE)
if [[ -d $1 ]];then
	echo "开始查找 $1 目录下文件占用大小和记录大小不一致的文件. 记录在 /tmp/.abcdefg.txt  (可能存在误差$(getconf PAGESIZE))"
	cat /dev/null > /tmp/.abcdefg.txt
	files_cout=$(find $1 -type f | wc -l)
	flag_n=0
	for i in $(find $1 -type f)
	do
		flag_n=$[ ${flag_n} + 1 ]
		jindutiao ${flag_n} ${files_cout}
		du_k=$(du -sk $i 2>/dev/null | awk '{print $1}')
		ls_k=$(ls -l $i 2>/dev/null | awk '{print $5/1024}')
		[[ -z ${ls_k} ]] && [[ -z ${du_k} ]] && continue
		chazhi=$[ ${ls_k%.*} - ${du_k} ]
		if [[ ${chazhi} -ge ${wuchazhi} ]];then
			echo "$i 实际大小(du -k)为: ${du_k} KB     统计大小(ls -l)为: ${ls_k} KB   误差为: ${chazhi} KB" >> /tmp/.abcdefg.txt
		fi
	done
else
	echo "$1 不是目录"
	echo "用法: sh $0 $(pwd)"
fi
echo -n ""
echo -e "\r"
