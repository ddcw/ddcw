#!/bin/env
#write by ddcw at 20200820

#20200821 modifid by ddcw : finish it.
#20200821 11:01 modifid by ddcw : add sed packages..

#sh SCRIPT [min_rate]

#run this function and exit with $2
function exits(){
  echo -e "[`date +%Y%m%d-%H:%M:%S`] \033[31;40m$1\033[0m"
  [ -z $2 ] && exit $2
  exit 1
}

#format echo with color
function echo_color() {
  case $1 in
    green)
      echo -e "\033[32;40m$2\033[0m"
      ;;
    red)
      echo -e "\033[31;40m$2\033[0m"
      ;;
    error|erro|ERROR|E|e)
      echo -e "[\033[1;5;41;33mERROR\033[0m `date +%Y%m%d-%H:%M:%S`] \033[1;41;33m$2\033[0m"
      ;;
    redflicker)
      echo -e "\033[1;5;41;33m$2\033[0m"
      ;;
    info|INFO|IF|I|i)
      echo -e "[\033[32;40mINFO\033[0m `date +%Y%m%d-%H:%M:%S`] \033[32;40m$2\033[0m"
      ;;
    highlightbold)
      echo -e "\033[1;41;33m$2\033[0m"
      ;;
    warn|w|W|WARN|warning)
      echo -e "[\033[31;40mWARNNING\033[0m `date +%Y%m%d-%H:%M:%S`] \033[31;40m$2\033[0m"
      ;;
    *)
      echo "INTERNAL ERROR: echo_color KEY VALUE"
      ;;
  esac
}

#time interval, default is 1. 
time_internal=1

#set min rate
[[ $1 -eq $1 ]] 2>/dev/null && export min_rate=$1
[[ -z ${min_rate} ]] && export min_rate=40
echo_color warn "if net rate great ${min_rate} bytes, only it will display."

#this is useless,
function get_net() {
	while [[ 1 -eq 1 ]]
	do
		export current_net=$(ifconfig -a | grep RUNNING | awk -F : '{print $1}')
		sleep 600
	done
}

#get current net 
export current_net=$(ifconfig -a | grep RUNNING | awk -F : '{print $1}')
for i in ${current_net}
do
	eval export ${i}_rate1=$(ifconfig $i | grep 'RX packets' | awk '{print $5}')
	eval export ${i}_rate2=$(ifconfig $i | grep 'TX packets' | awk '{print $5}')
#	eval echo \$${i}_rate1 ----------- 
done

#main get rate for all net
function print_rate() {
	while true
	do
	sleep ${time_internal}
		echo_color info  "\tRecive(in)\t\t\t\tSend(out)"
		rate1=0
		rate2=0
		rates_rev=0
		rates_sen=0
		for i in ${current_net}
		do
			rate1=$(eval echo \$${i}_rate1)
			rate2=$(ifconfig $i | grep 'RX packets' | awk '{print $5}')
			rate3=$(eval echo \$${i}_rate2)
			rate4=$(ifconfig $i | grep 'TX packets' | awk '{print $5}')
			eval export ${i}_rate1=${rate2}
			rates_rev=$[ ${rate2} - ${rate1} ]
			rates_sen=$[ ${rate2} - ${rate1} ]
			[[ ${rates_rev} -lt ${min_rate} ]] && continue
			echo  -e "$i \t ${rates_rev} bytes/s \t \033[31;40m $[ ${rates_rev} / 1024 ]\033[0m KB/s \t $[ ${rates_rev} / 1024 /1024 ] MB/s \t\t${rates_sen}  bytes/s \t \033[31;40m $[ ${rates_sen} / 1024 ]\033[0m KB/s \t $[ ${rates_sen} / 1024 /1024 ] MB/s"
		done
		echo ''
		echo ''
	#break
	done
}
print_rate

