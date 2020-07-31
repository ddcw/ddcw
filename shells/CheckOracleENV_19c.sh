#!/bin/env bash
#write by ddcw at 20191223
#modified by ddcw at 20200106
#offical url https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/index.html

#change log
#this script write 20191223, but it's for oracle 11g and 12c 
#now this version only for 19c on Linux >= 7.4
#20200731 first write by ddcw, fix some BUGS

#thes code is like dog shit..... 


#run this function and exit with $2
function exits(){
  echo -e "[`date +%Y%m%d-%H:%M:%S`] \033[31;40m$1\033[0m"
  [ -z $2 ] && exit $2
  exit 1
}

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



TEMP="/tmp"
logfile="${TEMP}/.`date +%Y%m%d-%H%M%S`.log"
os_v=""
fixup_ddcw="/tmp/$0/fixup_by_ddcw.sh"
mkdir -p /tmp/$0
[ -f ${fixup_ddcw} ] && mv ${fixup_ddcw} /tmp/.fixup${dt}
[ -f ${fixup_ddcw} ] || touch ${fixup_ddcw}
get_Framework_value=""
get_cpu_number_value_physical=""
get_cpu_number_value_processor=""
get_cpu_type_value=""
get_mem_value1=""
get_mem_value2=""
get_mem_value_pagesize=""
get_mem_value_swaptotal=""
get_mem_value_swapfree=""
export os_v="6"
systemctl -h >/dev/null 2>&1 && export os_v="7"
function get_Framework() {
	get_Framework_value=`uname -i`
}
function get_cpu_number() {
	get_cpu_number_value_physical=`cat /proc/cpuinfo | grep physical | grep id | sort | uniq |  wc -l`
	get_cpu_number_value_processor=`cat /proc/cpuinfo | grep processor | wc -l`
}
function get_cpu_type() {
	get_cpu_type_value=`cat /proc/cpuinfo | grep model | grep name | head -1 | awk -F : '{print $2}'`
}
function get_mem() {
	get_mem_value1=`cat /proc/meminfo | grep -i MemAvailable | awk -F : '{print $2}' | awk '{print $1}'`
	get_mem_value1="$[ $(echo ${get_mem_value1}) / 1024  ] MB"
	get_mem_value2=`cat /proc/meminfo | grep MemTotal | awk -F : '{print $2}' | awk '{print $1}'`
	get_mem_value2="$[ $(echo ${get_mem_value2}) / 1024 ] MB"
	get_mem_value_pagesize=`getconf PAGESIZE`
	get_mem_value_swaptotal=`cat /proc/meminfo | grep -i SwapTotal | awk -F : '{print $2}' | awk '{print $1}'`
	get_mem_value_swaptotal="$[ $(echo ${get_mem_value_swaptotal}) /1024 ] MB"
	get_mem_value_swapfree=`cat /proc/meminfo | grep -i SwapFree | awk -F : '{print $2}' | awk '{print $1}'`
	get_mem_value_swapfree="$[ $(echo ${get_mem_value_swapfree}) / 1024 ] MB"
}
function get_pack_need(){
	#this is for 11g 12c
	#packs="bc binutils compat-libcap1 compat-libstdc++-33 gcc glibc glibc-devel ksh libaio libaio-devel libX11 libXau libXi libXtst libgcc libstdc++ libstdc++-devel libxcb make nfs-utils net-tools smartmontools sysstat expect libXrender "

	#this is for 19c only
	packs="unzip bc binutils compat-libcap1 compat-libstdc++-33 glibc glibc-devel ksh libaio libaio-devel libX11 libXau libXi libXtst libXrender libXrender-devel libgcc libstdc++ libxcb make smartmontools sysstat"	

	for i in ${packs}
	do
		if ! rpm -q $i >/dev/null 2>&1
		then
			echo_color warn "$i is not install"
			echo "yum -y install $i || echo '--------- [ ERROR ] this os has not pack $i  ---------'" >> ${fixup_ddcw}
		fi
	done
}
function get_service_stat() {
	services7="firewalld avahi-daemon"
	services6="NetworkManager bluetooth avahi-daemon cups ip6tables iptables netfs nfs nfslock"
	if [ "${os_v}" -eq "7" ]
	then
		for i in ${services7}
		do
			if systemctl status $i >/dev/null 2>&1
			then
				echo_color warn "service $i is running"
				echo "systemctl stop $i" >> ${fixup_ddcw}
				echo "systemctl disable $i" >> ${fixup_ddcw}
			fi
		done
	else
		for i in ${services6}
		do
			if service $i status  >/dev/null 2>&1
			then
				echo_color warn "service $i is running"
				echo "service $i stop" >> ${fixup_ddcw}
				echo "chkconfig --del $i" >> ${fixup_ddcw}
			fi
		done
	fi

}
function judge_user_oracle() {
	if grep oracle /etc/passwd >/dev/null 2>&1
	then
		groups="dba oper  backupdba dgdba kmdba racdba"
		echo_color info "this script staring..."
		if ! id oracle | grep \(oinstall\) >/dev/null 2>&1
		then
			echo_color warn "oracle main group is not $i"
			echo "usermod -g oinstall oracle" >> ${fixup_ddcw}
		fi
		for i in ${groups}
		do
			if ! id oracle | grep \(${i}\) >/dev/null 2>&1
			then
				echo_color warn "oracle GROUPS has not $i"
				echo "usermod -aG $i oracle"  >> ${fixup_ddcw}
			fi
		done
	else
		echo_color error "this os has not user oracle"
		echo "useradd -g oinstall -G dba -G oper -G  backupdba -G dgdba -G  kmdba -G racdba oracle" >> ${fixup_ddcw}
		check_post 2
	fi
}

function judge_groups() {
	groups="oinstall dba oper  backupdba dgdba kmdba racdba"
	for i in ${groups}
	do
		if ! grep $i /etc/group >/dev/null 2>&1
		then
			echo_color warn "group $i is not create"
			echo "groupadd $i" >> ${fixup_ddcw}
		fi
	done
}

function core_shmmni() {
	if [ "`/sbin/sysctl -a 2>/dev/null | grep shmmni | awk '{print $3}'`" -lt "4096" ]
	then
		echo_color warn "shmmni must  great 4096"
		echo "echo 'kernel.shmmni = 4096' >> /etc/sysctl.conf" >> ${fixup_ddcw}
	fi
}
function core_shmmax() {
	mem_half=`cat /proc/meminfo | grep MemTotal | awk '{print $2/2}' | awk -F "." '{print $1}'`
	shmmax=`/sbin/sysctl -a 2>/dev/null | grep shmmax | awk '{print $3}'`
	if [ "`echo ${shmmax} | wc -L`" -lt "20" ]  && [ "${shmmax}" -lt "${mem_half}" ]
	then
		echo_color warn "shmmax must greate half memmery ${mem_half}"
		echo "echo 'kernel.shmmni = ${mem_half}' >> /etc/sysctl.conf" >> ${fixup_ddcw}
	fi
}
function core_sem() {
	semmsl=`/sbin/sysctl -a 2>/dev/null | grep sem |head -1 | awk '{print $3}'`
	semmns=`/sbin/sysctl -a 2>/dev/null | grep sem |head -1 | awk '{print $4}'`
	semopm=`/sbin/sysctl -a 2>/dev/null | grep sem |head -1 | awk '{print $5}'`
	semmni=`/sbin/sysctl -a 2>/dev/null | grep sem |head -1 | awk '{print $6}'`
	if [ "${semmsl}" -lt "250" ]  || [ "${semmns}" -lt "32000" ] || [ "${semopm}" -lt "100" ] || [ "${semmni}" -lt "128" ]
	then
		echo_color warn "semmsl semmns semopm semmni must be greate 250 32000 100 128"
		echo "echo 'kernel.sem = 250	32000	100	128' >> /etc/sysctl.conf " >> ${fixup_ddcw}
	fi
}
function core_ilpr() {
	ilpr_min=`/sbin/sysctl -a 2>/dev/null | grep ip_local_port_range | awk '{print $3}'`
	ilpr_max=`/sbin/sysctl -a 2>/dev/null | grep ip_local_port_range | awk '{print $4}'`
	if [ "${ilpr_min}" -lt "9000" ] || [ "${ilpr_max}" -gt "65500"  ] 
	then
		echo_color warn "ip_local_port_range must less 65500 and greate 9000"
		echo "echo 'net.ipv4.ip_local_port_range = 9000 65500' >> /etc/sysctl.conf" >> ${fixup_ddcw}
	fi
}
function core_shmall() {
	mem_2_5=`cat /proc/meminfo | grep MemTotal | awk '{print $2/5*2}' | awk -F "." '{print $1}'`
	shmall=`/sbin/sysctl -a 2>/dev/null | grep shmall | awk '{print $3}'`
	if [ "`echo ${shmall} | wc -L`" -lt "20" ]  && [ "${shmall}" -lt "${mem_2_5}" ]
	then
		echo_color warn "shmmax must greate ${mem_2_5}"
		echo "echo 'kernel.shmmax = ${mem_2_5}' >> /etc/sysctl.conf" >> ${fixup_ddcw}
	fi
#	[ "`/sbin/sysctl -a 2>/dev/null | grep shmmax | awk '{print $3}'`" -lt "4398046511104" ] && echo "kernel.shmmax = 4398046511104" >> /etc/sysctl.conf
#	guan fang tui jian zhi:kernel.shmall = 1073741824       kernel.shmmax = 4398046511104      kernel.shmmni = 4096    ( shmmni*shmall=shmmax )
}
function core_file_max() {
	if [ "`/sbin/sysctl -a 2>/dev/null | grep file-max | awk '{print $3}'`" -lt "6815744" ] 
	then
		echo_color warn "file-max must greate 6815744"
		echo "echo 'fs.file-max = 6815744' >> /etc/sysctl.conf" >> ${fixup_ddcw}
	fi
}
function core_rmem_default() {
	if [ "`/sbin/sysctl -a 2>/dev/null | grep rmem_default | awk '{print $3}'`" -lt "262144" ]
	then
		echo_color warn "rmem-default must greate 262144"
		echo "echo 'net.core.rmem_default = 262144' >> /etc/sysctl.conf" >> ${fixup_ddcw}
	fi
}
function core_rmem_max() {
	if [ "`/sbin/sysctl -a 2>/dev/null | grep rmem_max | awk '{print $3}'`" -lt "4194304" ]
	then
		echo_color warn "rmem-max must greate 4194304"
		echo "echo 'net.core.rmem_max = 4194304' >> /etc/sysctl.conf" >> ${fixup_ddcw}
	fi
}
function core_wmem_default() {
	if [ "`/sbin/sysctl -a 2>/dev/null | grep wmem_default | awk '{print $3}'`" -lt "262144" ]
	then
		echo_color warn "wmem-default must greate 262144"
		echo "echo 'net.core.wmem_default = 262144' >> /etc/sysctl.conf" >> ${fixup_ddcw}
	fi
}
function core_wmem_max() {
	if [ "`/sbin/sysctl -a 2>/dev/null | grep wmem_max | awk '{print $3}'`" -lt "1048576" ]
	then
		echo_color warn "wmem-max must greate 1048576"
		echo "echo 'net.core.wmem_max = 1048576' >> /etc/sysctl.conf" >> ${fixup_ddcw}
	fi
}
function core_aio_max_nr() {
	if [ "`/sbin/sysctl -a 2>/dev/null | grep aio-max-nr | awk '{print $3}'`" -lt "1048576" ]
	then
		echo_color warn "aio-max-nr must greate 1048576"
		echo "echo 'fs.aio-max-nr = 1048576' >> /etc/sysctl.conf" >> ${fixup_ddcw}
	fi
}
function core_panic_on_oops() {
	if [ "${os_v}" -eq "7" ] && [ "`/sbin/sysctl -a 2>/dev/null | grep panic_on_oops | awk '{print $3}'`" -ne "1" ]
	then
		echo_color warn "panic-on-oops must equal 1"
		echo "echo 'kernel.panic_on_oops = 1' >> /etc/sysctl.conf" >> ${fixup_ddcw}
	fi
}
function core_suid_dumpable() {
	if [ "`/sbin/sysctl -a 2>/dev/null | grep suid_dumpable | awk '{print $3}'`" -ne "1" ]
	then
		echo_color warn "suid_dumpable must equal 1"
		echo "echo 'fs.suid_dumpable = 1' >> /etc/sysctl.conf" >> ${fixup_ddcw}
	fi
}
function RAC_core_NOZEROCONF() {
	if ! grep -E "^NOZEROCONF=yes" /etc/sysconfig/network >/dev/null 2>&1
	then
		echo_color warn "NOZEROCONF=yes must be set in RAC for grid"
		echo "echo 'NOZEROCONF=yes' >> /etc/sysconfig/network" >> ${fixup_ddcw}
	fi
}
function tphp() {
	if ! grep 'ever]' /sys/kernel/mm/*transparent_hugepage/enabled >/dev/null 2>&1
	then
		echo_color warn "transparent_hugepage is enabled: $(cat /sys/kernel/mm/*transparent_hugepage/enabled)"	
		trans_set_values="
	[ -f /sys/kernel/mm/transparent_hugepage/enabled ] &&  echo never > /sys/kernel/mm/transparent_hugepage/enabled\n
        [ -f /sys/kernel/mm/redhat_transparent_hugepage/enabled ] && echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled\n
        grep transparent_hugepage /etc/rc.d/rc.local 1>/dev/null || echo '[ -f /sys/kernel/mm/transparent_hugepage/enabled ] &&  echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.local\n
        grep redhat_transparent_hugepage /etc/rc.d/rc.local 1>/dev/null || echo '[ -f /sys/kernel/mm/redhat_transparent_hugepage/enabled ] && echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled' >> /etc/rc.local\n
        [ -x /etc/rc.d/rc.local ] || chmod +x /etc/rc.d/rc.local"
		echo -e "${trans_set_values}" >> ${fixup_ddcw}
	fi

}
function set_selinux() {
	if ! [ "`grep -E "^SELINUX=" /etc/selinux/config | awk -F "=" '{print $2}'`" == "disabled" ]
	then
		echo_color warn "selinux has open,and its must be disabled"
		echo "sed -i '/^SELINUX=/cSELINUX=disabled' /etc/selinux/config" >> ${fixup_ddcw}
	fi
}
function set_core_all() {
	core_shmmni
	core_shmmax
	core_sem
	core_ilpr
	core_shmall
	core_file_max
	core_rmem_default
	core_rmem_max
	core_wmem_default
	core_wmem_max
	core_aio_max_nr
	core_panic_on_oops
	core_suid_dumpable
	tphp
}
function judge_ENV() {
	source /home/oracle/.bash_profile
#	var_env="ORACLE_HOME ORACLE_SID ORACLE_HOSTNAME ORACLE_BASE LD_LIBRARY_PATH CLASSPATH ORACLE_UNQNAME"
#	for i in ${var_env}
#	do
#		if ! grep $i= /home/oracle/.bash_profile >/dev/null 2>&1
#		then
#			echo_color warn "user oracle's env  $i has not set\033[0m"
#			echo "echo '#[`date +%Y%m%d-%H:%M:%S`] set 12cENV by ddcw' >> ${oracle_bash_profile}" >> ${fixup_ddcw}
#			echo "" >> ${fixup_ddcw}
#		fi
#	done

	#xia mian zhe duan dai ma zei la ji, hou mian you kong le cong xin xie guo. yi qian de dai ma bu ren zhi shi a.

	if ! env |grep ORACLE_HOME >/dev/null 2>&1	
	then
		if [ "${os_v}" -eq "6" ]
		then
			echo_color warn "user oracle has not set ENV ORACLE_HOME"
			echo "echo 'export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1' >> /home/oracle/.bash_profile" >> ${fixup_ddcw}
		else
			echo_color warn "user oracle has not set ENV ORACLE_HOME"
			echo "echo 'export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1' >> /home/oracle/.bash_profile" >> ${fixup_ddcw}
			echo "mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1" >> ${fixup_ddcw}
		fi
	else
		#f_d_o_b="/$(echo ${ORACLE_HOME} | awk -F / '{print $2}')"
		f_d_o_b=${ORACLE_HOME}
		if [[ ! -d ${ORACLE_HOME} ]]  
		then
			echo_color warn "ORACLE_HOME ${ORACLE_HOME} does not exists"
			echo "mkdir -p ${ORACLE_HOME}" >> ${fixup_ddcw}
		fi
		size_of_o_b=$(df -P ${f_d_o_b} 2>/dev/null | tail -1 | awk '{print $(NF-2)}')
                [[ -d ${ORACLE_HOME} ]] && if [[ "${size_of_o_b:0:10}" -lt "8000000" ]]
                then
                        echo_color error "ORACLE_HOME ${ORACLE_HOME} size must greate 8 GB"
                fi
	fi
	if ! env | grep ORACLE_BASE >/dev/null 2>&1
	then
		echo_color warn "user oracle has not set ENV ORACLE_BASE"
		echo "echo 'export ORACLE_BASE=/u01/app/oracle' >> /home/oracle/.bash_profile" >> ${fixup_ddcw}
		echo "mkdir -p /u01/app/oracle" >> ${fixup_ddcw}
	else
		f_d_o_b="/$(echo ${ORACLE_BASE} | awk -F / '{print $2}')"
		f_d_o_b=${ORACLE_BASE}
		if [[ ! -d ${ORACLE_BASE} ]]
		then
			echo_color warn "ORACLE_BASE ${ORACLE_BASE} has not existed"
			echo "mkdir -p ${ORACLE_BASE}" >> ${fixup_ddcw}
		fi
		size_of_o_b=$(df -P ${f_d_o_b} 2>/dev/null | tail -1 | awk '{print $(NF-2)}')
		[[ -d ${ORACLE_BASE} ]] && if [[ "${size_of_o_b:0:10}" -lt "8000000" ]]
		then
			echo_color error "ORACLE_BASE ${ORACLE_BASE} size must greate 8 GB"
		fi
	fi
	if ! env | grep ORACLE_HOSTNAME >/dev/null 2>&1
	then
		echo_color warn "user oracle has not set ENV ORACLE_HOSTNAME"
		echo "echo 'export ORACLE_HOSTNAME=$(hostname)' >> /home/oracle/.bash_profile" >> ${fixup_ddcw}
	fi
	if ! env | grep ORACLE_SID >/dev/null 2>&1
	then
		echo_color warn "user oracle has not set ENV ORACLE_SID"
		echo "echo 'export ORACLE_SID=$(hostname)' >> /home/oracle/.bash_profile" >> ${fixup_ddcw}
	fi
	if ! env | grep ORACLE_UNQNAME >/dev/null 2>&1
	then
		echo_color warn "user oracle has not set ENV ORACLE_UNQNAME"
		echo "echo 'export ORACLE_UNQNAME=$(hostname)' >> /home/oracle/.bash_profile" >> ${fixup_ddcw}
	fi
	if ! env | grep LD_LIBRARY_PATH >/dev/null 2>&1
	then
		echo_color warn "user oracle has not set ENV LD_LIBRARY_PATH"
		echo "echo 'export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$ORACLE_HOME/rdbms/lib:\$ORACLE_HOME/network/lib:/usr/lib:/lib:/usr/dt/lib' >> /home/oracle/.bash_profile" >> ${fixup_ddcw}
	fi
	if ! env | grep LIBPATH >/dev/null 2>&1
	then
		echo_color warn "user oracle has not set ENV LIBPATH"
		echo "echo 'export LIBPATH=\$ORACLE_HOME/lib:\$ORACLE_HOME/rdbms/lib:\$ORACLE_HOME/network/lib:/usr/lib:/lib:/usr/dt/lib' >> /home/oracle/.bash_profile" >> ${fixup_ddcw}
	fi
	if ! env | grep CLASSPATH >/dev/null 2>&1
	then
		echo_color warn "user oracle has not set ENV CLASSPATH"
		echo "echo 'export CLASSPATH=\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib:\$ORACLE_HOME/network/jlib' >> /home/oracle/.bash_profile" >> ${fixup_ddcw}
	fi
	if ! env | cat /home/oracle/.bash_profile |  grep ORACLE | grep PATH  |grep local >/dev/null 2>&1
	then
		echo_color warn "user oracle has not set ENV ORALE_HOME PATH"
		echo "echo 'export PATH=\$ORACLE_HOME/bin:/usr/local/bin:\$PATH' >> /home/oracle/.bash_profile" >> ${fixup_ddcw}
	fi
}
function judge_hosts() {
	if ! ping -c 2 $(hostname) > /dev/null 2>&1
	then
		echo_color warn "this os cant known $(hostname) (this is can be ingore)"
		echo "echo '127.0.0.1 $(hostname)' >> /etc/hosts" >> ${fixup_ddcw}
	fi
}

function check_post() {
	ef=$1
	[ -z ${ef} ] && ef="0"
	if [ "$(cat ${fixup_ddcw} | wc -l)" -ge "1" ]
	then
		echo "/sbin/sysctl --system 1>/dev/null" >> ${fixup_ddcw}
		echo_color info "#you can run : sh ${fixup_ddcw}"
		echo ""
		exit ${ef}
	else
		rm -rf ${fixup_ddcw}
		exit ${ef}
	fi
}
function judge_source_limits() {
	#https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/checking-resource-limits-for-oracle-software-installation-users.html#GUID-293874BD-8069-470F-BEBF-A77C06618D5A
	#if ! grep oinstall /etc/security/limits.conf | grep soft | grep  nofile | grep 2048 | grep -v "#" >/dev/null 2>&1
	if [ "$(su - oracle -c "ulimit -a" | grep open | grep files | awk '{print $NF}')" -lt "1024" ]
	then
		echo_color warn  "you should set soft max number of open file descriptors nofile 1024" 
		echo "echo '@oinstall    soft    nofile  1024' >> /etc/security/limits.conf " >> ${fixup_ddcw}
	fi
	#if ! grep oinstall /etc/security/limits.conf | grep hard | grep  nofile | grep 65536  | grep -v "#" >/dev/null 2>&1
	if [ "$(su - oracle -c "ulimit -aH" | grep open | grep files | awk '{print $NF}')" -lt "65536" ]
	then
		echo_color warn  "you should hard soft max number of open file descriptors nofile 65536" 
		echo "echo '@oinstall    hard    nofile  65536' >> /etc/security/limits.conf " >> ${fixup_ddcw}
	fi
	#if ! grep oinstall /etc/security/limits.conf | grep soft | grep  stack | grep 10240 | grep -v "#"  >/dev/null 2>&1
	if [ "$(su - oracle -c "ulimit -a" | grep stack | grep size | awk '{print $NF}')" -lt "10240" ]
	then
		echo_color warn  "you should set  max stack size 65536"
		echo "echo '@oinstall    soft    stack   10240' >> /etc/security/limits.conf " >> ${fixup_ddcw}
	fi
       if [ "${os_v}" -eq "7" ]
       then
                #if ! grep oinstall /etc/security/limits.conf | grep soft | grep  nproc | grep 16384 | grep -v "#" >/dev/null 2>&1
		if [ "$(su - oracle -c "ulimit -a" | grep max | grep user | grep processes | awk '{print $NF}')" -lt "2047" ]
		then
			echo_color warn  "you should set max number of processes nproc  2047"
			echo "echo '@oinstall    soft    nproc    2047' >> /etc/security/limits.conf " >> ${fixup_ddcw}
		fi
       fi
}
function judge_login_pam() {
	if ! grep session /etc/pam.d/login | grep required | grep pam_limits.so | grep -v "#" >/dev/null 2>&1
	then
		echo -e "[`date +%Y%m%d-%H:%M:%S`] \033[31;40m[Waring]: you sholud set session limits in /etc/pam.d/login\033[0m"
		echo_color warn  "you should set  session limits in /etc/pam.d/login"
		echo "echo 'session    required     pam_limits.so' >> /etc/pam.d/login" >> ${fixup_ddcw}
	fi
}

function Integrate201910151601() {
	judge_groups
	judge_user_oracle
	get_pack_need
	get_service_stat
	set_core_all
	judge_ENV
	judge_hosts
	judge_source_limits
	judge_login_pam
	echo_color info "[OS INFO]:                `cat /etc/system-release`"
	get_Framework
	echo_color info "[Framework INFO]:         ${get_Framework_value}"
	get_cpu_number
	get_cpu_type
	echo_color info "[CPU INFO]:               pyhsical:${get_cpu_number_value_physical}\tprocessor:${get_cpu_number_value_processor}\ttype:${get_cpu_type_value}"
	get_mem
	echo_color info "[MEM INFO]:               MemTota:${get_mem_value2}\t\tMemAvailable:${get_mem_value1}"
	echo_color info "[MEM0-SWAP INFO]:         swapTota:${get_mem_value_swaptotal}\t\tswapfree:${get_mem_value_swapfree} "
	echo_color info "[MEM-PAGESIZE INFO]:      ${get_mem_value_pagesize}"
	if [ "`whoami`" == "root" ] 
	then
		vmstat=`virt-what`
		if [ -z ${vmstat:0:1} ] 
		then
			echo_color info "[MACHINE INFO]:           this os running at \033[0m \033[32;40m PYHSICAL MACHINE"
		else
			echo_color info "[MACHINE INFO]:           this os running in virtual platform: ${vmstat}"
		fi
	fi
	echo ""
	check_post
}
Integrate201910151601

