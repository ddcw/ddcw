#!/bin/env bash
#modified by ddcw at 20200708
dtbegin=`date +%s`
params=($@)
localip=1
listparams=$(eval echo {0..$[ $# - 1]} )
[[ $# -gt 0 ]] &&  for i in ${listparams}
do
	[[ $[ $i % 2 ] -eq 1 ]] && continue;
	case ${params[$i]} in 
		ip|IP|Ip|iP|ipv4|IPV4|ipV4)
			export ip=${params[$i + 1]};;
		port|Port|PORT)
			export port=${params[$i + 1]};;
		time|time_interval)
			export time_interval=${params[$i + 1]};;
		*)
			echo -e "[\033[1;5;41;33mUSAGE\033[0m `date +%Y%m%d-%H:%M:%S`] \033[1;41;33m scanportDDCW [ ip IPADDR ] [ port PORT ] [ time TIME_INTERVAL ] \033[0m"
			exit 1;;
	esac
done
[ -z ${port} ] && unset time_interval
[ -z ${ip} ] && export ip=0.0.0.0 && export localip=0
#[ -z ${port} ] && export port=$( echo {1..65535} )


if ping -c 1 ${ip} >/dev/null ;then
        echo -e "IP|HOSTNAME \tTCP PORT \tSTATUS \tProgram name"
else
        echo -e "\033[31;40mDONT't KNOWN ${ip} OR NET UNREACHABLE\033[0m"
        exit 2
fi

ifconfig | grep ${ip} >/dev/null && export localip=0
[[ "${ip}" == "$(hostname)" ]]

cur_user=$(whoami)
[[ ${localip} -eq 0 ]] && [[ "${cur_user}" == "root" ]]  && service_name=$(netstat -natp | grep :${j} | grep -v - | head -1 | awk '{print $7}' | awk -F / '{print $2}' | awk -F : '{print $1}')

if [ -z ${port} ];then
	for j in {1..65535}
	do
		if echo &>/dev/null > /dev/tcp/${ip}/${j} ;then
			echo -e "${ip}\t\t\033[31;40m${j}\t\033[0m  is \033[32;40mOPEN\033[0m \t${service_name}"
		fi
	done
else
	for k in ${port}
	do
		if echo &>/dev/null > /dev/tcp/${ip}/${k} ;then
			#[[ ${localip} -eq 0 ]] && [[ "${cur_user}" == "root" ]]  && service_name=$(netstat -natp | grep :${j} | grep -v - | head -1 | awk '{print $7}' | awk -F / '{print $2}' | awk -F : '{print $1}')
			echo -e "${ip}\t\033[31;40m${k}\t\033[0m  is \033[32;40mOPEN\033[0m \t${service_name}"
		else
			 echo -e "${ip}\t\033[31;40m${k}\t\033[0m  is \033[31;40mCLOSE\033[0m"
		fi
	done
	flag_quit="NO"
	[[ -z ${time_interval} ]] || while [[ ! "${flag_quit}" == "q" ]]
	do
		read -t ${time_interval} -n 1 flag_quit
		for k in ${port}
		do
			if echo &>/dev/null > /dev/tcp/${ip}/${k} ;then
				echo -e "${ip}\t\033[31;40m${k}\t\033[0m  is \033[32;40mOPEN\033[0m \t${service_name} \t$(date +%Y%m%d-%H:%M:%S)"
			else
				 echo -e "${ip}\t\033[31;40m${k}\t\033[0m  is \033[31;40mCLOSE\033[0m \t$(date +%Y%m%d-%H:%M:%S)"
			fi
		done
		
	done
fi
dtend=`date +%s`
echo -e "this script cost time: \033[32;40m`expr ${dtend} - ${dtbegin}`\033[0m second"

