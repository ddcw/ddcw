#!/bin/env bash
#write by ddcw at 20200717 first
#offical url https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/index.html
#this script only install oracle after complete Check_ENV_ORACLE.
#scriptName: oracle19c_install.sh

#define variable
begintime=`date +%s`
dt=$(date +%Y%m%d-%H%M%S)
thiscript=$0
log_detail=.${thiscript}_${dt}.log
PARAM=$@
current_pwd=`pwd`
exit_flag=99
ORACLE_BASE=${ORACLE_BASE%*/}
ORACLE_HOME=${ORACLE_HOME%*/}
CURRENT_USER=$(id | awk -F uid= '{print $2}' | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
CURRENT_USER_GROUP=$(id | awk -F gid= '{print $2}' | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')

#pga_size MB
pga_aggregate_target=`cat /proc/meminfo | grep MemTotal | awk '{print $2/1024/5*2/4}' | awk -F . '{print $1}'`
#sga_size MB
sga_target=`cat /proc/meminfo | grep MemTotal | awk '{print $2/1024/5*2/4*3}' | awk -F . '{print $1}'`


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
      echo "Example: echo_color red string"
      ;;
  esac
}

#bak file function, but abandonmented
function bak_file() {
  [ -d /root/bak_file ] || mkdir /root/bak_file
  filename=`echo $1 |sed 's/\//_/g'`
  cp -f $1 /root/bak_file/${filename}_${dt}
}


#init user set params
function init_parameter() {
	echo abc
}

#check env for install oracle, such as space,kernel params,software....
function check_env() {
	echo check
}

#config dbinstall.rsp
function init_db_install_rsp() {
	echo db install
}

#config netca.rsp
function init_netca_rsp() {
	echo netca
}

#config dbca.rsp
function init_dbca_rsp() {
	echo dbca
}

#install oracle software only
function install_db_software() {
	echo install dbinstall
}

#install netca
function install_netca() {
	echo install netca
}

#install dbca
function install_dbca() {
	echo dbca
}
