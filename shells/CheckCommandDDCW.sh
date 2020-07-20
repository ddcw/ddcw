#!/bin/env bash
#write by ddcw
#https://cloud.tencent.com/developer/column/6121
#scriptname:CheckCommDDCW.sh
begintime=`date +%s`
file_name=~/.UserCheckCom.txt
new_comm_n=0
change_comm_n=0
new_comm=""
change_comm=""
[ -f ${file_name} ] || touch ${file_name}
for i in $(compgen -c)
do
	if which $i >/dev/null  2>&1 
	then
		md5_n=$(md5sum $(which $i) | awk '{print $1}')
		if  cat ${file_name} | grep "\#$i\#" >/dev/null  2>&1 
		then
		#	echo $(cat ${file_name} | grep "\#$i\#")
			md5_o=$(cat ${file_name} | grep "\#$i\#" | tail -1 | awk '{print $NF}')
			if [ "${md5_n}" != "${md5_o}" ]
			then
				#echo -e "COMMD \033[1;41;33m $i \033[0m may be Changed: old_MD5: ${md5_o}    new_MD5: ${md5_n}"
				[ -z $1 ] || echo -e "#${i}# \t $(date +%Y%m%d-%H:%M:%SOURCE) \t ${md5_n}" >> ${file_name}
				change_comm_n=$[ ${change_comm_n} + 1]
				change_comm="${change_comm}  ${i}"
			fi
		else
			if [ "${i}" != '[' ]
			then
				new_comm_n=$[ ${new_comm_n} + 1]
				new_comm="${new_comm}  ${i}"
				#echo -e "\033[32;40m$i \033[0m"
				echo -e "#${i}# \t $(date +%Y%m%d-%H:%M:%SOURCE) \t ${md5_n}" >> ${file_name}
			fi
		fi
	fi	
done
echo ""
if [ ${new_comm_n} -gt 0 ]
then
	echo -e "\033[31;40m Total Add  ${new_comm_n} commd \033[0m"
	echo "${new_comm}"
else
	echo -e "\033[32;40m No Command  Added ,It's Seccurity!\033[0m\n"
fi
if [ ${change_comm_n} -gt 0 ]
then
	echo -e "\033[31;40m Total Changed  ${change_comm_n} commd \033[0m"
	echo "${change_comm}"
else
	echo -e "\033[32;40m No Command Changed  ,It's Seccurity!\033[0m"
fi
endtime=`date +%s`
costm=`echo ${begintime} ${endtime} | awk '{print ($2-$1)/60}'`
echo -e "\n\033[32;40m `date +%Y%m%d-%H:%M:%SOURCE` cost ${costm} minutes\033[0m"
