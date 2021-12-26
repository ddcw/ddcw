#!/usr/bin/env bash
#write by ddcw at 2021.12.26 登录显示主机部分信息
hostname=$(cat /proc/sys/kernel/hostname)
platform=$(uname -m)
kernel=$(uname -r)
osname=$(grep NAME= /etc/os-release | head -1 | awk -F \" '{print $2}')
osversion=$(grep VERSION= /etc/os-release | head -1 | awk -F \" '{print $2}')
if [ $(which lscpu) ]; then
	cpusock=$(lscpu | grep 'Socket(s)' | awk '{print $NF}')
	cpucore=$(lscpu | grep 'Core(s)' | awk '{print $NF}')
	cputhread=$(lscpu | grep 'Thread(s)' | awk '{print $NF}')
	cputotal=$[ ${cpusock} * ${cpucore} * ${cputhread} ]
fi

if [ $(which lspci) ];then  
	vga=$(lspci | grep -i ' vga ')
fi

#计算当前CPU使用率, 间隔取的0.1秒, 空闲时,误差较大
cpu_1=$(head -1 /proc/stat | awk '{print $2+$3+$4+$5+$6+$7+$8+$9+$(10),$5}')
sleep 0.1
cpu_2=$(head -1 /proc/stat | awk '{print $2+$3+$4+$5+$6+$7+$8+$9+$(10),$5}')
cpu_total=$[ $(echo ${cpu_2} | awk '{print $1}') - $(echo ${cpu_1} | awk '{print $1}') ]
cpu_idle=$[ $(echo ${cpu_2} | awk '{print $2}') - $(echo ${cpu_1} | awk '{print $2}') ]
cpu_PERSENT=$[ (${cpu_total} - ${cpu_idle}) * 100 / ${cpu_total} ]

#CPU总利用率 从开机开始算
cpu_uptime=$(cat /proc/uptime)
cpu_uptime_1=$(echo ${cpu_uptime} | awk '{print $1}' | awk -F . '{print $1}')
cpu_uptime_2=$(echo ${cpu_uptime} | awk '{print $2}' | awk -F . '{print $1}')
cpu_p_total=$[ ( ${cpu_uptime_1} * ${cputotal} - ${cpu_uptime_2} ) * 100 / ${cpu_uptime_1} ] #所有CPU的利用率之和, 会超过100%
cpu_TOTAL_PERSENT=$[ ${cpu_p_total} / ${cputotal} ]  #除以总的CPU数量后就是 利用率了


memtotalKB=$(grep 'MemTotal' /proc/meminfo | awk '{print $2}')
memtotalMB=$[ ${memtotalKB} / 1024 ]
memavailableKB=$(grep 'MemAvailable' /proc/meminfo | awk '{print $2}')
memavailableMB=$[ ${memavailableKB} / 1024 ]
memusedKB=$[ ${memtotalKB} - ${memavailableKB} ]
memusedMB=$[ ${memusedKB} / 1024 ]
mem_USE_PERCENT=$[ ${memusedKB} * 100 / ${memtotalKB} ]

swaptotalKB=$(grep 'SwapTotal' /proc/meminfo | awk '{print $2}')
swaptotalMB=$[ ${swaptotalKB} / 1024 ]
swapcacheKB=$(grep 'SwapCached' /proc/meminfo | awk '{print $2}')
swapcacheMB=$[ ${swapcacheKB} / 1024 ]
swap_USE_PERCENT=$[ ${swapcacheKB} * 100 / ${swaptotalKB} ]
swappiness=$(cat /proc/sys/vm/swappiness)

echo -e "\nHOSTNAME: ${hostname}"
#echo -e "PLATFORM: ${platform}"
echo -e "KERNEL  : ${kernel}"
echo -e "OS TYPE : ${osname} ${osversion} ${platform}"
echo -e "CPU     : ${cpusock} * ${cpucore} * ${cputhread} = ${cputotal}  (${cpu_PERSENT}%) (${cpu_TOTAL_PERSENT}%)"
#echo -e "CPU USED: ${cpu_PERSENT}%"
echo -e "VGA     : ${vga}"
echo -e "MEMARY  : ${mem_USE_PERCENT}% (${memusedMB}MB/${memtotalMB}MB)"
echo -e "SWAP    : ${swap_USE_PERCENT}% (${swapcacheMB}MB/${swaptotalMB}MB) (swappiness=${swappiness})"

echo -e "\n\n\n"
