#!/bin/env bash
#write by ddcw at 20200710 first
#this  is install scripts , only for install ./shell/* , just copy file and define DIECTORIES.

#change log
#at 20200713 ,add main 

#define variable
installdir=/tmp/ddcw/install_$(date +%Y%m%d-%H:%M:%S)  	#for install only
ddcwdir="/usr/local/ddcw" 		#ddcw install dir
rollbackdir=${ddcwdir}/rollback 		#ddcw save old release after remove or update, only 2 releases
confdir=/etc/ddcw/conf           		#ddcw config dir
mandir=/usr/share/man      		#default man dir 
completion=/etc/bash_completion.d  	#default completion dir
install_shells=${ddcwdir}/install_shells	#for install_shells only

ddcw_conf=ddcw.conf    			#ddcw current config file
default_conf=default.conf 		#ddcw default dir, this file is dead where release is make sure


#define variable  for Install_Sctipts only
BASE_INSTALL_DIR="/usr/local"		#for install_scripts default install dir
BASE_LOG="/logs"			#for install_scripts default log dir , such as /logs/nginx/error.log . 
SYSTEM_ENABLED=1  			#use systemctl or service for manage software 
ONBOOT=1  		#enable  start on boot
SCRIPT_DIR_CONFIG=${confdir}/script_dir_config		#for every install_script to save them config, just like script_dir_config/nginx/nginx.conf.



function init() {
	current_user=$(whoami)
	if [[ ! "${current_user}" == "root" ]] ; then
		echo -e "[\033[31;40mWARNNING\033[0m `date +%Y%m%d-%H:%M:%S`] \033[31;40m current user is ${current_user}, you must run install.sh as ROOT .\033[0m"
		exit 1
	fi
	mkdir -p ${installdir} ${ddcwdir} ${rollbackdir} ${confdir} ${mandir} ${completion} ${SCRIPT_DIR_CONFIG} ${rollbackdir}/conf/ ${install_shells}
}

function install_shells() {
	for i in ./shells/*
	do
		shell_name=$(echo $i | sed 's/.sh$//' | awk -F / '{print $NF}' )
		[[ -f /usr/bin/${shell_name} ]] && mv /usr/bin/${shell_name} ${installdir} && echo -e "[\033[32;40mINFO\033[0m `date +%Y%m%d-%H:%M:%S`] \033[32;40m backup /usr/bin/${shell_name} to ${installdir}. \033[0m"
		cp ${i} /usr/bin/${shell_name} && echo -e "[\033[32;40mINFO\033[0m `date +%Y%m%d-%H:%M:%S`] \033[32;40m cp ${i} finishd. \033[0m" || echo -e "[\033[1;5;41;33mERROR\033[0m `date +%Y%m%d-%H:%M:%S`] \033[1;41;33m copy ${i} FAILED \033[0m"
		chmod +x /usr/bin/${shell_name}
	done

}

function install_man() {
	for i in ./man/*
	do
		[[ -f ${mandir}/man1/${i} ]] && mv ${mandir}/man1/${i} ${installdir}/${i}.man
		cp $i ${mandir}/man1 
	done

}

function install_completion() {
	for i in ./completion/*
	do
		[[ -f ${completion}/$i ]] && mv ${completion}/$i ${installdir}/${i}.completion
		cp $i ${completion}
	done
}

function install_conf() {
	for i in ./conf/*
	do
		file_name=$(echo $i | awk -F / '{print $NF}' )
		[[ -f ${confdir}/${file_name} ]] && mv ${confdir}/${file_name} ${rollbackdir}/conf/${file_name}$(date +%Y%m%d-%H:%M:%S)
		cp $i ${confdir}
	done
}

function install_install_shells() {
	for i in ./install_shells/*
	do
		script_name=$(echo $i | awk -F / '{print $NF}' )
		[[ -f ${install_shells}/${script_name} ]] && mv ${install_shells}/${script_name} ${rollbackdir}/conf/${script_name}$(date +%Y%m%d-%H:%M:%S)
		cp $i ${install_shells}
	done
}

init
install_shells
install_man
install_completion
install_conf
install_install_shells
