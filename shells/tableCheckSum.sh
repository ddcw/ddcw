#!/bin/env bash
#write by ddcw at 2021.06.26 
#检查mysql的表数据是否一致， 只检查行数量
#用法， sh $0.sh  src_user/src_passowrd@src_ip:src_port[/database_name]  dst_user/dst_passowrd@dst_ip:dst_port[/database_name]

PARAMS=$@
SRC_PARAM=$1
DST_PARAM=$2
dt=$(date +%s)
same_tbale="/tmp/.same_table_${dt}.same"
no_same_tbale="/tmp/.same_table_${dt}.nosame"

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

function env_check(){
	which mysql >/dev/null 2>&1 || exits "you should install mysql client first, tips: yum install mysql -y"
}

function init_param() {
	#这是上一个版本的写法, 新版本变成了KV形式
	#export SRC_USER=$(echo $SRC_PARAM | awk -F / '{print $1}')	
	#export SRC_PASSWORD=$(echo $SRC_PARAM | awk -F / '{print $2}' | awk -F @ '{print $1}')	
	#export SRC_IP=$(echo $SRC_PARAM | awk -F @ '{print $2}' | awk -F : '{print $1}')	
	#export SRC_PORT=$(echo $SRC_PARAM | awk -F : '{print $2}' | awk -F / '{print $1}' )	
	#export SRC_DBNAME=$(echo $SRC_PARAM | awk -F : '{print $2}' | awk -F / '{print $2}' )	
        #export DST_USER=$(echo $DST_PARAM | awk -F / '{print $1}')
        #export DST_PASSWORD=$(echo $DST_PARAM | awk -F / '{print $2}' | awk -F @ '{print $1}')
        #export DST_IP=$(echo $DST_PARAM | awk -F @ '{print $2}' | awk -F : '{print $1}')
        #export DST_PORT=$(echo $DST_PARAM | awk -F : '{print $2}' | awk -F / '{print $1}' )
        #export DST_DBNAME=$(echo $DST_PARAM | awk -F : '{print $2}' | awk -F / '{print $2}' )
	for kv in ${PARAMS}
	do
		param=$(echo ${kv} | awk -F "=" '{print $1}')
		param=${param,,}
		value=$(echo ${kv} | awk -F "=" '{print $2}')
		case ${param} in
			src_user)
				export SRC_USER=${value}
				;;
			src_password)
				export SRC_PASSWORD=${value}
				;;
			src_ip|src_host|src)
				export SRC_IP=${value}
				;;
			src_port)
				export SRC_PORT=${value}
				;;
			src_dbname|src_database)
				export SRC_DBNAME=${value}
				;;
			dst_user)
				export DST_USER=${value}
				;;
			dst_password)
				export DST_PASSWORD=${value}
				;;
			dst_ip|dst_host|dst)
				export DST_IP=${value}
				;;
			dst_port)
				export DST_PORT=${value}
				;;
			dst_dbname|dst_database)
				export DST_DBNAME=${value}
				;;
			parallelism|p|parallel)
				export PARALLEL=${value}
				;;
			conversion)
				export CONVERSION=${value}
				;;
			table_file)
				export TABLE_FILE=${value}
				;;
			*)
				export print_flag=1
				;;
		esac
	done
}

function help_this() {
	echo ""
	echo -e "SRC_IP=${SRC_IP}"
	echo -e "SRC_USER=${SRC_USER}"
	echo -e "SRC_PASSWORD=${SRC_PASSWORD}"
	[[ -z ${SRC_DBNAME} ]] ||  echo -e "SRC_DBNAME${SRC_DBNAME} #目前只支持单库"
	echo -e "DST_IP=${DST_IP}"
	echo -e "DST_USER${DST_USER}"
	echo -e "DST_PASSWORD${DST_PASSWORD}"
	[[ -z ${DST_DBNAME} ]] ||  echo -e "DST_DBNAME${DST_DBNAME} #目前只支持单库"
	echo -e "PARALLEL= ${PARALLEL}"
	[[ -z ${NO_TEST_PORT} ]] || echo -e "NO_TEST_PORT=1  #不使用ssh测试断开连通性, 没啥用, 所以我也就不写了..."
	[[ -z ${CONVERSION} ]] || echo -e "CONVERSION=${CONVERSION} #我也不知道这玩意怎么用, 还没想好..."
	#[[ -z ${TABLE_FILE} ]] || echo -e "TABLE_FILE=${TABLE_FILE}"
	echo -e "TABLE_FILE=${TABLE_FILE}"
	echo ""
	exit 1
}

function check_param() {
	[[ -z ${PARALLEL} ]] && export PARALLEL=$[ $(lscpu  | grep CPU\(s\): | grep -v node | awk '{print $2}') * 2 ]
	[[ ${PARALLEL} -eq ${PARALLEL} ]] 2>/dev/null || exits "PARALLEL 是并行度的意思, 只能是数字"
	[[ ${print_flag} -eq 1 ]] && help_this
	ping -c 1 -W 1 ${SRC_IP} >/dev/null 2>&1 || exits "$SRC_IP 源端网络不可达"
	ping -c 1 -W 1 ${DST_IP} >/dev/null 2>&1 || exits "$DST_IP 目标端网络不可达"
	echo $(ssh ${SRC_IP} -p ${SRC_PORT} -o ConnectTimeout=1 -o BatchMode=yes -o StrictHostKeyChecking=yes 2>&1 ) | grep refused >/dev/null 2>&1 && exits "$SRC_IP:$SRC_PORT 端口不通"
	echo $(ssh ${DST_IP} -p ${DST_PORT} -o ConnectTimeout=1 -o BatchMode=yes -o StrictHostKeyChecking=yes 2>&1 ) | grep refused >/dev/null 2>&1 && exits "$DST_IP:$DST_PORT 端口不通"
	mysql -h ${SRC_IP} -P ${SRC_PORT} -u $SRC_USER -p${SRC_PASSWORD} -e "show databases;" >/dev/null 2>&1 || exits "$SRC_IP:$SRC_PORT  源端用户名或者密码错误"
	mysql -h ${DST_IP} -P ${DST_PORT} -u $DST_USER -p${DST_PASSWORD} -e "show databases;" >/dev/null 2>&1 || exits "$DST_IP:$DST_PORT  目标端用户名或者密码错误"

}

function init_database_info() {
	#目前只支持全库比较(排除information_schema mysql performance_schema sys)
	DB_INFO=$(mysql -h ${SRC_IP} -P ${SRC_PORT} -u $SRC_USER -p${SRC_PASSWORD} -e "show databases;" 2>/dev/null)
	DB_INFO=$(echo ${DB_INFO} | sed 's/Database//g;s/information_schema//g;s/mysql//g;s/performance_schema//g;s/sys//g')
	[[ -z ${DB_INFO} ]] && exits "源库$SRC_IP:$SRC_PORT  无数据库"
}

function compare_table() {
	echo -e "TABLE_NAME \t $SRC_IP:$SRC_PORT \t $DST_IP:$DST_PORT \t status"
	cat /dev/null >${same_tbale}
	cat /dev/null >${no_same_tbale}
	dtbegin=`date +%s`
	if [[ -z ${SRC_DBNAME} ]] && [[ ! -f ${TABLE_FILE} ]]; then
		mysql -s -h ${SRC_IP} -P ${SRC_PORT} -u $SRC_USER -p${SRC_PASSWORD} -e 'select concat(table_schema,".",table_name) from INFORMATION_SCHEMA.TABLES where table_schema not in ("information_schema", "mysql", "performance_schema", "sys");' 2>/dev/null > /tmp/.mysqlalltbale${dtbegin}.txt
	elif [[ ! -f ${TABLE_FILE} ]]; then
		mysql -s -h ${SRC_IP} -P ${SRC_PORT} -u $SRC_USER -p${SRC_PASSWORD} -e "select concat(table_schema,\".\",table_name) from INFORMATION_SCHEMA.TABLES where table_schema=\"${SRC_DBNAME,,}\";" 2>/dev/null > /tmp/.mysqlalltbale${dtbegin}.txt
	fi
	[[ -f /tmp/.mysqlalltbale${dtbegin}.txt ]] && table_file="/tmp/.mysqlalltbale${dtbegin}.txt" || table_file=${TABLE_FILE}
	tempfifo=$$.fifo
	trap "exec 666>&-;exec 666<&-;exit 0" 2
	mkfifo $tempfifo
	exec 666<>$tempfifo
	rm -rf $tempfifo
	#threads=$[ $(lscpu  | grep CPU\(s\): | grep -v node | awk '{print $2}') * 2 ]
	for ((i=1; i<=${PARALLEL}; i++))
	do
	    echo >&666
	done
	while read table_name
	do
		read -u666
		{
		src_table_name=$(echo ${table_name} | awk '{print $1}')
		dst_table_name=$(echo ${table_name} | awk '{print $2}')
		[[ -z ${dst_table_name} ]] && dst_table_name=${src_table_name}
		srv_count=$(mysql -s -h ${SRC_IP} -P ${SRC_PORT} -u $SRC_USER -p${SRC_PASSWORD} -D${SRC_DBNAME} -e "select count(*) from ${src_table_name};" 2>/dev/null | grep -E "\d*" )
		[[ ! -f ${TABLE_NAME} ]] && [[ ! -z ${SRC_DBNAME} ]] && [[ ! -z ${DST_DBNAME} ]] && dst_table_name=${table_name/$SRC_DBNAME/$DST_DBNAME} #就是数据库名转换
		dst_count=$(mysql -s -h ${DST_IP} -P ${DST_PORT} -u $DST_USER -p${DST_PASSWORD} -D${DST_DBNAME} -e "select count(*) from ${dst_table_name};" 2>/dev/null | grep -E "\d*" )
		[[ -z ${dst_count} ]] && dst_count=-2
		[[ -z ${srv_count} ]] && srv_count=-1
		if [[ ${srv_count} -eq ${dst_count} ]]; then
			echo -e "${table_name} \t\t ${srv_count} \t\t ${dst_count} \t\t \033[32;40m 一致 \033[0m"
			echo "${src_table_name} ${dst_table_name}" >> ${same_tbale}
		else
			echo -e "${table_name} \t\t ${srv_count} \t\t ${dst_count} \t\t \033[31;40m 不一致 \033[0m"
			echo "${src_table_name} ${dst_table_name}" >> ${no_same_tbale}
		fi
		echo >&666
		} &
	
	done < ${table_file}
	wait
	dtend=`date +%s`
	echo -e "this script cost time: \033[32;40m`expr ${dtend} - ${dtbegin}`\033[0m second"
	echo -e "源和目标一致的表的数量: $(wc -l ${same_tbale} | awk '{print $1}') \t 源和目标不一致的表的数量: \033[31;40m$(wc -l ${no_same_tbale} | awk '{print $1}')\033[0m"
	echo -e "一致的表: ${same_tbale} \t 不一致的表: ${no_same_tbale}"
}

init_param
#	echo $SRC_USER
#	echo $SRC_PASSWORD
#	echo  $SRC_IP
#	echo  $SRC_PORT
#	echo $SRC_DBNAME
#echo ------------
#        echo $DST_USER
#        echo $DST_PASSWORD
#        echo  $DST_IP
#        echo  $DST_PORT
#        echo $DST_DBNAME
check_param
init_database_info
compare_table
