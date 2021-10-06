#!/usr/bin/env bash
#write by ddcw at 2021.10.05 
#计划支持环境: x86/aarch64架构下 rhel/centos/oel  ubuntu/debian suse kylin uos

#功能/要求如下
#ctrl+c无法停止脚本,  kill -12可以 , 为了防止误操作
#/tmp/ddcw/mysql_port.lock  ddcw_ei_install_mysql__port.pid 记录安装过程的, 安装完之后删除, 防止安装都一半之后, 脚本挂了, 后面可以继续安装
#支持mysql5.6 5.7 8.0官方版本, 或者自己编译make package的包
#仅支持mysql二进制包.  包格式为:mysql-${MYSQL_VERSION}.*-linux-${PLATFORM}.tar.gz  比如:mysql-8.0.26-linux-aarch64.tar.gz
#openssl要求为 libssl.so.10 
#本脚本不支持远程安装, 若要远程安装, 请使用其它脚本调用这个脚本

#测试通过的系统如下(mysql5.7和mysql8.0均通过):
#x86_64环境:  centos7 ubuntu-18.04.4-tls
#aarch64环境: centos8 EulerOS-2.8

#x86_64下载地址
#mysql-5.7.35下载地址: https://mirror.tuna.tsinghua.edu.cn/mysql/downloads/MySQL-5.7/mysql-5.7.35-linux-glibc2.12-x86_64.tar.gz 
#mysql-8.0.26下载地址: https://mirror.tuna.tsinghua.edu.cn/mysql/downloads/MySQL-8.0/mysql-8.0.26-linux-glibc2.12-x86_64.tar.xz

#aarch64环境的二进制包请自行编译: 
#官方教程: https://dev.mysql.com/doc/refman/5.7/en/installing-source-distribution.html
#个人视频教程: https://www.bilibili.com/video/BV1bL4y1h7Fi



stty erase ^H
#基本参数设置
export LANG="en_US.UTF-8"
export PARAMS=$@
export THIS_PID=$$
export exitflag=0
export HELP_FLAG=0
export AUTO="YES"
export dt=$(date +%s)
umask 0022 #EulerOS之类的默认umask可能不是0022, 会有目录权限问题
export LOCAL_MOST_IP16=$(cat /proc/net/tcp | awk '{print $2}' | tail -n +2 | awk -F : '{print $1}' | grep -v 00000000 | sort | uniq -c | sort -n -r | head -1 |awk '{print $2}')

#系统信息
[[ -z ${CPU_TYPE} ]] && CPU_TYPE=$(lscpu | grep -i 'Model name' | awk -F : '{print $2}' | awk '{print $1}')
[[ -z ${PLATFORM} ]] && PLATFORM=$(uname -m)
[[ -z ${OS_TYPE} ]] && OS_TYPE=$(cat /proc/sys/kernel/ostype)
[[ -z ${KERNEL_VERSION} ]] && KERNEL_VERSION=$(uname -r)
[[ -z ${OS_ID} ]] && OS_ID=$(grep "^ID=" /etc/os-release  | awk -F =  '{print $2}' | sed 's/\"//g')
[[ -z ${OS_ID_LIKE} ]] && OS_ID_LIKE=$(grep "^ID_LIKE=" /etc/os-release  | awk -F =  '{print $2}' | sed 's/\"//g')
[[ -z ${OS_ID_LIKE_1} ]] && OS_ID_LIKE_1=$(grep "^ID_LIKE=" /etc/os-release  | awk -F =  '{print $2}' | sed 's/\"//g' | awk '{print $1}')
[[ -z ${OS_NAME} ]] && OS_NAME=$(grep "^NAME=" /etc/os-release  | awk -F = '{print $2}' | sed 's/\"//g')
[[ -z ${OS_VERSION} ]] && OS_VERSION=$(grep "^VERSION_ID=" /etc/os-release  | awk -F = '{print $2}' | sed 's/\"//g')
[[ -z ${OS_ID_LIKE} ]] && OS_ID_LIKE=$(grep "^ID=" /etc/os-release  | awk -F =  '{print $2}' | sed 's/\"//g')
[[ -z ${OS_ID_LIKE_1} ]] && OS_ID_LIKE_1=$(grep "^ID=" /etc/os-release  | awk -F =  '{print $2}' | sed 's/\"//g' | awk '{print $1}')
 
#CPU信息
cpu_socket=$(lscpu  | grep 'Socket(s)' | awk '{print $NF}') #CPU物理数量(颗)
cpu_cores=$(lscpu  | grep 'Core(s)' | awk '{print $NF}')    #每颗CPU多少核
cpu_thread=$(lscpu  | grep 'Thread(s)' | awk '{print $NF}') #每核多小线程


#内存信息(单位KB) 不考虑swap 大页 共享内存等
mem_total=$(grep 'MemTotal' /proc/meminfo  | awk '{print $2}')  #总内存
mem_free=$(grep 'MemFree' /proc/meminfo  | awk '{print $2}')    #未使用过的内存
mem_available=$(grep 'MemAvailable' /proc/meminfo  | awk '{print $2}') #可用内存(包括buffer)
mem_pagesize=$(getconf PAGESIZE)

#glibc
glibc_version=$(getconf -a | grep GNU_LIBC_VERSION | awk '{print $NF}')

#捕捉信号量
#trap 'WhenCtrlC' SIGINT
trap ""  SIGINT
#trap 'WhenKILL9' 9
trap 'WhenUSR2' 12

#run this function and exit with $2
exits(){
  echo -e "[`date +%Y%m%d-%H:%M:%S`] \033[31;40m$1\033[0m"
  [ -z $2 ] || exit $2
  exit 1
}

echo_color() {
  detaillog1=$3
  [[ -z ${detaillog1} ]] && detaillog1=${details}
  case $1 in
    green)
      echo -e "\033[32;40m$2\033[0m"
      ;;
    red)
      echo -e "\033[31;40m$2\033[0m"
      ;;
    error|err|erro|ERROR|E|e)
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
    detail|d|det)
      echo -e "[\033[32;40mINFO\033[0m `date +%Y%m%d-%H:%M:%S`] \033[32;40m$2\033[0m"
      echo "[`date +%Y%m%d-%H:%M:%S`] $2" >> ${detaillog1}
      ;;
    n|null)
      echo -e "$2"
      ;;
    *)
      echo "INTERNAL ERROR: echo_color KEY VALUE"
      ;;
  esac
}

	

WhenCtrlC() {
	echo_color info "当前的参数为: ${PARAMS}"
	echo_color warn "CTRL+C 被禁止了(防止误操作). 你可以使用如下命令杀死本脚本进程\n\t kill -12 ${THIS_PID} "
}

WhenKILL9() {
	echo_color info "当前的参数为: ${PARAMS}"
	echo_color warn "kill -9 被禁止了(防止误操作). 你可以使用如下命令杀死本脚本进程\n\t kill -12 ${THIS_PID} "
}

WhenUSR2() {
	echo_color info "当前的参数为: ${PARAMS}"
	echo_color warn "等待当前子进程执行完毕." 
	for i in `cat /proc/${${THIS_PID}}/task/${THIS_PID}/children`; do cat /proc/$i/cmdline; echo ""; done
	[ -f ${PID_FILE} ] && rm -rf ${PID_FILE} >/dev/null 2>&1
	exit 12
}

init_user_params() {
	for param_value in ${PARAMS}
	do
		param="${param_value%=*}" #取最后一个=前面的内容
		param="${param/--/}" #去掉-- 如果有的话
		param="${param,,}" #全部变成小写
		value="${param_value##*=}" #取最后一个=后面的内容
		
		case ${param} in
			mysql_tar_dir)
				export MYSQL_TAR_DIR=${value}
				;;
			mysql_tar)
				export MYSQL_TAR=${value}
				;;
			mysql_user|mysqluser)
				export MYSQL_USER=${value}
				;;
			mysql_group)
				export MYSQL_GROUP=${value}
				;;
			mysql_root_password)
				export MYSQL_ROOT_PASSWORD=${value}
				;;
			mysql_cnf|mysql_config|mysql_cnf_file)
				export MYSQL_CNF=${value}
				;;
			mysql_bind_address|mysql_bind)
				export MYSQL_BIND_ADDRESS=${value}
				;;
			mysql_port|port)
				export MYSQL_PORT=${value}
				;;
			mysql_base_dir|mysql_base)
				export MYSQL_BASE_DIR=${value}
				;;
			mysql_data_dir|mysql_data)
				export MYSQL_DATA_DIR=${value}
				;;
			mysql_log_dir|mysql_log)
				export MYSQL_LOG_DIR=${value}
				;;
			mysql_socket)
				export MYSQL_SOCKET=${value}
				;;
			mysql_pid)
				export MYSQL_PID=${value}
				;;
			mysql_tmp_dir)
				export MYSQL_TMP_DIR=${value}
				;;
			mysql_error)
				export MYSQL_ERROR=${value}
				;;
			mysql_slow_query_log)
				export MYSQL_SLOW_QUERY_LOG=${value}
				;;
			mysql_slow_query)
				export MYSQL_SLOW_QUERY=${value}
				;;
			mysql_general_log_file)
				export MYSQL_GENERAL_LOG_FILE=${value}
				;;
			mysql_general_log)
				export MYSQL_GENERAL_LOG=${value}
				;;
			mysql_long_query)
				export MYSQL_LONG_QUERY=${value}
				;;
			mysql_binlog_format)
				export MYSQL_BINLOG_FORMAT=${value}
				;;
			mysql_binlog_basename)
				export MYSQL_BINLOG_BASENAME=${value}
				;;
			mysql_binlog)
				export MYSQL_BINLOG=${value}
				;;
			mysql_sync_binlog)
				export MYSQL_SYNC_BINLOG=${value}
				;;
			mysql_innodb_log_dir)
				export MYSQL_INNODB_LOG_DIR=${value}
				;;
			mysql_innodb_log_file_size)
				export MYSQL_INNODB_LOG_SIZE=${value}
				;;
			mysql_innodb_log_files)
				export MYSQL_INNODB_LOG_FILES=${value} #redo数量
				;;
			mysql_innodb_log_buffer_size)
				export MYSQL_INNODB_LOG_BUFFER_SIZE=${value} #innodb缓存大小
				;;
			mysql_innodb_data_dir)
				export MYSQL_INNODB_DATA_DIR=${value}  #innodb系统表空间的数据文件目录
				;;
			mysql_innodb_tmp_max_size)
				export MYSQL_INNODB_TMP_MAX_SIZE=${value}  #innodb临时表空间最大值. 默认30G
				;;
			mysql_innodb_open_files)
				export MYSQL_INNODB_OPEN_FILES=${value}  #它指定MySQL 一次可以保持打开的最大.ibd 文件数
				;;
			mysql_innodb_page_size)
				export MYSQL_INNODB_PAGE_SIZE=${value}
				;;
			mysql_innodb_default_row_format)
				export MYSQL_INNODB_DEFAULT_ROW_FORMAT=${value}
				;;
			mysql_innodb_buffer_pool_size)
				export MYSQL_INNODB_BUFFER_POOL_SIZE=${value}  #innodb buffer pool size
				;;
			mysql_innodb_buffer_pool_instances)
				export MYSQL_INNODB_BUFFER_POOL_INSTANCES=${value}  #缓冲池划分的数量  MYSQL_INNODB_BUFFER_POOL_SIZE*MYSQL_INNODB_BUFFER_POOL_INSTANCES 就是innodb使用的总的内存
				;;
			mysql_innodb_doublewrite)
				export MYSQL_INNODB_DOUBLEWRITE=${value} #是否开启双写, 默认ON
				;;
			mysql_innodb_fill_factor)
				export MYSQL_INNODB_FILL_FACTOR=${value}
				;;
			mysql_innodb_lru_scan_depth)
				export MYSQL_INNODB_LRU_SCAN_DEPTH=${value}
				;;
			mysql_transaction_isolation)
				export MYSQL_TRANSACTION_ISOLATION=${value}  #事务隔离级别, 默认rr
				;;
			mysql_tx_read_only)
				export MYSQL_TX_READ_ONLY=${value}
				;;
			mysql_innodb_flush_log_at_trx_commit)
				export MYSQL_INNODB_FLUSH_LOG_AT_TRX_COMMIT=${value}  #多少个事务刷盘(redo) ,建议1   和sync_binlog=1 合称双1
				;;
			mysql_innodb_flush_log_at_timeout)
				export MYSQL_INNODB_FLUSH_LOG_AT_TIMEOUT=${value} #多久刷一次盘, 
				;;
			mysql_relay_log_file)
				export MYSQL_RELAY_LOG_FILE=${value}
				;;
			mysql_relay_log_info_repository)
				export MYSQL_RELAY_LOG_INFO_REPOSITORY=${value}
				;;
			mysql_relay_log_purge)
				export MYSQL_RELAY_LOG_PURGE=${value}  #禁用或启用在不再需要中继日志文件时自动清除它们 默认ON
				;;
			mysql_gtid_mode)
				export MYSQL_GTID_MODE=${value}
				;;
			mysql_gtid_next)
				export MYSQL_GTID_NEXT=${value}
				;;
			mysql_performance_schema)
				export MYSQL_PERFORMANCE_SCHEMA=${value}
				;;
			mysql_character_set)
				export MYSQL_CHARACTER_SET=${value}
				;;
			mysql_default_storage_engine)
				export MYSQL_DEFAULT_STORAGE_ENGINE=${value}
				;;
			mysql_disabled_storage_engine)
				export MYSQL_DISABLED_STORAGE_ENGINE=${value}
				;;
			mysql_max_allowed_packet)
				export MYSQL_MAX_ALLOWED_PACKET=${value}
				;;
			mysql_max_connections)
				export MYSQL_MAX_CONNECTIONS=${value}
				;;
			mysql_table_open_cache)
				export MYSQL_TABLE_OPEN_CACHE=${value}  
				;;
			mysql_skip_name_resolve)
				export MYSQL_SKIP_NAME_RESOLVE=${value}
				;;
			mysql_binlog_expire_logs_days)
				export MYSQL_BINLOG_EXPIRE_LOGS_DAYS=${value}
				;;
			h|help|-h)
				export HELP_FLAG=1
				export exitflag=$[ ${exitflag} + 1 ]
				;;
			mysql_server_id)
				export MYSQL_SERVER_ID=${value}
				;;
			*)
				echo_color warn "无法识别参数 ${param}"
				export exitflag=$[ ${exitflag} + 1 ]
				;;
		esac
	done

}

init_auto_params() {
	[[ -z ${MYSQL_TAR_DIR} ]] && export MYSQL_TAR_DIR="."
	[[ -z ${MYSQL_USER} ]] && export MYSQL_USER="mysql"
	[[ -z ${MYSQL_GROUP} ]] && export MYSQL_GROUP="mysql"
	[[ -z ${MYSQL_BIND_ADDRESS} ]] && export MYSQL_BIND_ADDRESS="0.0.0.0"
	if [[ -z ${MYSQL_PORT} ]]; then
		mysql_current_max_port=`grep -ri 'port' /etc/ddcw/mysql_*.conf 2>/dev/null | grep -v "#" | awk -F = '{print $2}' | sed 's/"//g' | awk '{print $1}' | sort -n  | tail -1`
		if [[ ! -z ${mysql_current_max_port} ]]; then
			export MYSQL_PORT=$[ ${mysql_current_max_port} + 2 ]
		else
			export MYSQL_PORT="3306"
		fi
	fi
	[[ -z ${MYSQL_ROOT_PASSWORD} ]] && export MYSQL_ROOT_PASSWORD="123456"

	[[ -z ${MYSQL_BASE_DIR} ]] && export MYSQL_BASE_DIR="/soft/mysql_${MYSQL_PORT}/mysqlbase"
	[[ -z ${MYSQL_DATA_DIR} ]] && export MYSQL_DATA_DIR="/data/mysql_${MYSQL_PORT}/mysqldata"
	[[ -z ${MYSQL_LOG_DIR} ]] && export MYSQL_LOG_DIR="/data/mysql_${MYSQL_PORT}/mysqllog"
	[[ -z ${MYSQL_SOCKET} ]] && export MYSQL_SOCKET="${MYSQL_LOG_DIR%/*}/run/mysql.sock"
	[[ -z ${MYSQL_PID} ]] && export MYSQL_PID="${MYSQL_LOG_DIR%/*}/run/mysql.pid"
	[[ -z ${MYSQL_TMP_DIR} ]] && export MYSQL_TMP_DIR="${MYSQL_LOG_DIR%/}/tmp"
	[[ -z ${MYSQL_ERROR} ]] && export MYSQL_ERROR="${MYSQL_LOG_DIR%/}/dblogs/mysql${MYSQL_PORT}.err"
	[[ -z ${MYSQL_SLOW_QUERY_LOG} ]] && export MYSQL_SLOW_QUERY_LOG="${MYSQL_LOG_DIR%/}/dblogs/slow${MYSQL_PORT}.log"
	[[ -z ${MYSQL_SLOW_QUERY} ]] && export MYSQL_SLOW_QUERY="ON"
	[[ -z ${MYSQL_LONG_QUERY} ]] && export MYSQL_LONG_QUERY="1"
	[[ -z ${MYSQL_GENERAL_LOG_FILE} ]] && export MYSQL_GENERAL_LOG_FILE="${MYSQL_LOG_DIR%/}/dblogs/general${MYSQL_PORT}.log"
	[[ -z ${MYSQL_GENERAL_LOG} ]] && export MYSQL_GENERAL_LOG="OFF"
	[[ -z ${MYSQL_BINLOG_FORMAT} ]] && export MYSQL_BINLOG_FORMAT="ROW"
	[[ -z ${MYSQL_BINLOG_BASENAME} ]] && export MYSQL_BINLOG_BASENAME="${MYSQL_LOG_DIR%/}/binlog/m${MYSQL_PORT}" #对应log_bin_basename
	[[ -z ${MYSQL_BINLOG} ]] && export MYSQL_BINLOG="ON" #是否启用binlog 对应log_bin
	[[ -z ${MYSQL_BINLOG_EXPIRE_LOGS_DAYS} ]] && export MYSQL_BINLOG_EXPIRE_LOGS_DAYS="15" #binlog过期天数
	[[ -z ${MYSQL_MAX_BINLOG_SIZE} ]] && export MYSQL_MAX_BINLOG_SIZE="1073741824" #binlog大小
	[[ -z ${MYSQL_SYNC_BINLOG} ]] && export MYSQL_SYNC_BINLOG="1"
	[[ -z ${MYSQL_INNODB_FLUSH_LOG_AT_TRX_COMMIT} ]] && export MYSQL_INNODB_FLUSH_LOG_AT_TRX_COMMIT="1"
	[[ -z ${MYSQL_INNODB_LOG_DIR} ]] && export MYSQL_INNODB_LOG_DIR="${MYSQL_LOG_DIR%/}/redolog"
	[[ -z ${MYSQL_INNODB_LOG_SIZE} ]] && export MYSQL_INNODB_LOG_SIZE="1073741824"  #建议1G  innodb_log_file_size
	[[ -z ${MYSQL_INNODB_LOG_FILES} ]] && export MYSQL_INNODB_LOG_FILES="4" #对应innodb_log_files_in_group 也就是redo的数量, 建议4个

	if [[ -z ${MYSQL_INNODB_BUFFER_POOL_SIZE} ]];then
		export MYSQL_INNODB_BUFFER_POOL_SIZE=$[ ${mem_available} * 1024 * 60 / 100 ]	
	fi

	[[ -z ${MYSQL_INNODB_BUFFER_POOL_INSTANCES} ]] && export MYSQL_INNODB_BUFFER_POOL_INSTANCES="1"
	[[ -z ${MYSQL_INNODB_DATA_DIR} ]] && export MYSQL_INNODB_DATA_DIR="${MYSQL_DATA_DIR%/}" #innodb系统信息存放的位置, 包含ibdata1  ibtmp1
	[[ -z ${MYSQL_INNODB_TMP_MAX_SIZE} ]] && export MYSQL_INNODB_TMP_MAX_SIZE="30G"  #innodb临时表空间的最大大小, 每次重启的时候释放
	[[ -z ${MYSQL_INNODB_OPEN_FILES} ]] && export MYSQL_INNODB_OPEN_FILES="40960" #它指定MySQL 一次可以保持打开的最大.ibd 文件数
	[[ -z ${MYSQL_INNODB_PAGE_SIZE} ]] && export MYSQL_INNODB_PAGE_SIZE="16384" #只能是4096 8192 16384 32768 65536
	[[ -z ${MYSQL_INNODB_DEFAULT_ROW_FORMAT} ]] && export MYSQL_INNODB_DEFAULT_ROW_FORMAT="DYNAMIC" ##可选值REDUNDANT COMPACT DYNAMIC
	[[ -z ${MYSQL_INNODB_LOG_BUFFER_SIZE} ]] && export MYSQL_INNODB_LOG_BUFFER_SIZE="67108864" ##innodb缓存大小 默认16777216 (16M)   推荐 64M (67108864)   最大4G (4294967295)
	[[ -z ${MYSQL_INNODB_DOUBLEWRITE} ]] && export MYSQL_INNODB_DOUBLEWRITE="ON" #双写
	[[ -z ${MYSQL_INNODB_FILL_FACTOR} ]] && export MYSQL_INNODB_FILL_FACTOR="70"
	[[ -z ${MYSQL_INNODB_LRU_SCAN_DEPTH} ]] && export MYSQL_INNODB_LRU_SCAN_DEPTH="1024"
	[[ -z ${MYSQL_TRANSACTION_ISOLATION} ]] && export MYSQL_TRANSACTION_ISOLATION="REPEATABLE-READ" #READ-UNCOMMITTED READ-COMMITTED REPEATABLE-READ SERIALIZABLE 
	[[ -z ${MYSQL_TX_READ_ONLY} ]] && export MYSQL_TX_READ_ONLY="OFF"
	[[ -z ${MYSQL_INNODB_FLUSH_LOG_AT_TIMEOUT} ]] && export MYSQL_INNODB_FLUSH_LOG_AT_TIMEOUT="1"

	[[ -z ${MYSQL_RELAY_LOG_FILE} ]] && export MYSQL_RELAY_LOG_FILE="${MYSQL_LOG_DIR%/}/relay/relay.log"
	[[ -z ${MYSQL_RELAY_LOG_PURGE} ]] && export MYSQL_RELAY_LOG_PURGE="ON"  #是否自动清除不需要了的relay日志
	[[ -z ${MYSQL_RELAY_LOG_INFO_REPOSITORY} ]] && export MYSQL_RELAY_LOG_INFO_REPOSITORY="table"

	[[ -z ${MYSQL_GTID_MODE} ]] && export MYSQL_GTID_MODE="ON" #是否启用gtid
	[[ -z ${MYSQL_GTID_NEXT} ]] && export MYSQL_GTID_NEXT="AUTOMATIC" #AUTOMATIC #ANONYMOUS  #UUID:NUMBER
	[[ -z ${MYSQL_PERFORMANCE_SCHEMA} ]] && export MYSQL_PERFORMANCE_SCHEMA="ON" #是否启用PERFORMANCE_SCHEMA库, 启用性能会低一点点
	[[ -z ${MYSQL_CHARACTER_SET} ]] && export MYSQL_CHARACTER_SET="utf8" #字符集设置, 包括了服务端,客户端, 还有排序字符集  如果有emoj的话, 需要utf8mb4.
	[[ -z ${MYSQL_DEFAULT_STORAGE_ENGINE} ]] && export MYSQL_DEFAULT_STORAGE_ENGINE="INNODB"  #默认存储引擎
	[[ -z ${MYSQL_DISABLED_STORAGE_ENGINE} ]] && export MYSQL_DISABLED_STORAGE_ENGINE="MyISAM,FEDERATED" #禁用myisam存储引擎
	[[ -z ${MYSQL_MAX_ALLOWED_PACKET} ]] && export MYSQL_MAX_ALLOWED_PACKET="1073741824" 
	[[ -z ${MYSQL_MAX_CONNECTIONS} ]] && export MYSQL_MAX_CONNECTIONS="10240"
	[[ -z ${MYSQL_TABLE_OPEN_CACHE} ]] && export MYSQL_TABLE_OPEN_CACHE="10240"
	[[ -z ${MYSQL_SKIP_NAME_RESOLVE} ]] && export MYSQL_SKIP_NAME_RESOLVE="OFF"

	MYSQL_SERVER_ID_TMP=$(date +%s)$(echo ${MYSQL_BIND_ADDRESS} | awk -F . '{print $3$4}')${MYSQL_PORT}
	[[ -z ${MYSQL_SERVER_ID} ]] && export MYSQL_SERVER_ID=${MYSQL_SERVER_ID_TMP:0-9} #server_id限制4G, 故取最后9位一定小于4G
	

	[[ -z ${MYSQL_CNF} ]] && export MYSQL_CNF="${MYSQL_DATA_DIR%/*}/conf/mysql_${MYSQL_PORT}.cnf"

	if [[ -d ${MYSQL_TAR} ]];then
		export MYSQL_TAR=$(ls ${MYSQL_TAR%/}/mysql-*-${OS_TYPE,,}-*${PLATFORM}.tar* -tr 2>/dev/null | grep -v -- '-test-' | grep -v -- '-router-'  | tail -1)
	fi

	if [[ -z ${MYSQL_TAR} ]];then
		export MYSQL_TAR=$(ls ${MYSQL_TAR_DIR%/}/mysql-*-${OS_TYPE,,}-*${PLATFORM}.tar* -tr 2>/dev/null | grep -v -- '-test-' | grep -v -- '-router-' | tail -1 )
	fi
}

#检查变量(不检查环境, 不创建目录之类的, 只是做参数检查, 防止参数有问题)
check_params() {
	#exitflag是判断变量是否有问题的参数, 有问题该变量就大于0
	#exitflag=0
	#检查端口
	[[ -f /etc/ddcw/mysql_${MYSQL_PORT}.conf ]] && echo_color warn "/etc/ddcw/mysql_${MYSQL_PORT}.conf exists" && export exitflag=$[ ${exitflag} + 1 ]
	for src in `tail -n +2 /proc/net/tcp | awk '{print $2}'`;
	do
		src_port="${src##*:}"
		src_host="${src%:*}"
		[[ $((0x${src_port})) -eq "${MYSQL_PORT}" ]] >/dev/null 2>&1 && echo_color warn "PORT: ${MYSQL_PORT} has been used in $((0x${src_host}))" && export exitflag=$[ ${exitflag} + 1 ]
	done
	if [[ ${MYSQL_PORT} -eq ${MYSQL_PORT} ]] >/dev/null 2>&1; then
		if [[ ${MYSQL_PORT} -ge 65535 ]] || [[ ${MYSQL_PORT} -le 1024 ]];
		then
			echo_color warn "MYSQL_PORT (${MYSQL_PORT}) must less 65535 and great 1024" && export exitflag=$[ ${exitflag} + 1 ]
		fi
	else
		echo_color warn "MYSQL_PORT (${MYSQL_PORT}) must be number" && export exitflag=$[ ${exitflag} + 1 ]
	fi

	#检查绑定的地址
	if [[ ! ${MYSQL_BIND_ADDRESS} == "0.0.0.0" ]]; then
		ip addr | grep ${MYSQL_BIND_ADDRESS} >/dev/null 2>&1 || (echo_color warn "${MYSQL_BIND_ADDRESS} is not local address" && export exitflag=$[ ${exitflag} + 1 ])
	fi

	#检查布尔类型的变量
	for vb in MYSQL_SLOW_QUERY MYSQL_GENERAL_LOG MYSQL_BINLOG MYSQL_INNODB_DOUBLEWRITE MYSQL_TX_READ_ONLY MYSQL_RELAY_LOG_PURGE MYSQL_GTID_MODE  MYSQL_PERFORMANCE_SCHEMA MYSQL_SKIP_NAME_RESOLVE 
	do
		#vb_value=${!vb} #ubuntu貌似有点点问题
		vb_value=$(eval echo \$${vb})
		case ${vb_value,,} in
			on|off)
				continue
				;;
			*)
				echo_color warn "${vb} must be on/off."
				export exitflag=$[ ${exitflag} + 1 ]
				;;
		esac
	done

	#检查数值型变量
	for num in MYSQL_LONG_QUERY MYSQL_BINLOG_EXPIRE_LOGS_DAYS MYSQL_MAX_BINLOG_SIZE MYSQL_SYNC_BINLOG MYSQL_INNODB_LOG_SIZE MYSQL_INNODB_LOG_FILES MYSQL_INNODB_BUFFER_POOL_SIZE MYSQL_INNODB_BUFFER_POOL_INSTANCES MYSQL_INNODB_OPEN_FILES MYSQL_INNODB_PAGE_SIZE MYSQL_INNODB_LOG_BUFFER_SIZE MYSQL_INNODB_FILL_FACTOR MYSQL_INNODB_LRU_SCAN_DEPTH MYSQL_INNODB_FLUSH_LOG_AT_TIMEOUT MYSQL_MAX_ALLOWED_PACKET MYSQL_MAX_CONNECTIONS MYSQL_TABLE_OPEN_CACHE
	do
		num_value=`eval echo ${num}`
		[[ ${num_value} -eq ${num_value} ]] >/dev/null 2>&1 || (echo_color warn "${num} must be number." && export exitflag=$[ ${exitflag} + 1 ])
	done

	#其它检查, 比如说范围
	if [[ ${MYSQL_MAX_BINLOG_SIZE} -lt 4096 ]] || [[ ${MYSQL_MAX_BINLOG_SIZE} -gt 1073741824 ]] ;then
		echo_color warn "MYSQL_MAX_BINLOG_SIZE(${MYSQL_MAX_BINLOG_SIZE}) must  4096 < MAX_BINLOG_SIZE < 1073741824"
		export exitflag=$[ ${exitflag} + 1 ]
	fi

	if [[ ${MYSQL_INNODB_PAGE_SIZE} -eq 4096 ]] || [[ ${MYSQL_INNODB_PAGE_SIZE} -eq 8192 ]] || [[ ${MYSQL_INNODB_PAGE_SIZE} -eq 16384 ]] || [[ ${MYSQL_INNODB_PAGE_SIZE} -eq 32768 ]] || [[ ${MYSQL_INNODB_PAGE_SIZE} -eq 65536 ]]; then
		continue
	else
		echo_color warn "MYSQL_INNODB_PAGE_SIZE(${MYSQL_INNODB_PAGE_SIZE}) only 4096  8192 16384 32768 65536"
		export exitflag=$[ ${exitflag} + 1 ] 
	fi

	if [[ "${MYSQL_TRANSACTION_ISOLATION^^}" == " READ-UNCOMMITTED" ]] || [[ "${MYSQL_TRANSACTION_ISOLATION^^}" == "READ-COMMITTED" ]] || [[ "${MYSQL_TRANSACTION_ISOLATION^^}" == "REPEATABLE-READ" ]] || [[ "${MYSQL_TRANSACTION_ISOLATION^^}" == "SERIALIZABLE" ]]; then
		continue
	else
		echo_color warn "only READ-UNCOMMITTED READ-COMMITTED REPEATABLE-READ SERIALIZABLE"
		export exitflag=$[ ${exitflag} + 1 ]
	fi

	#检查字符集

	#检查mysql二进制安装包
	if ! [[ -f ${MYSQL_TAR} ]];then
		echo_color warn "MYSQL_TAR(${MYSQL_TAR}) has not exist"
		export exitflag=$[ ${exitflag} + 1 ]
	fi

	#检查innodb buffer pool size
	if [[ ${MYSQL_INNODB_BUFFER_POOL_SIZE} -lt 104857600  ]] || [[ ${MYSQL_INNODB_BUFFER_POOL_SIZE} -ge $[ ${mem_available} * 1024 ] ]];then
		echo_color warn "MYSQL_INNODB_BUFFER_POOL_SIZE(${MYSQL_INNODB_BUFFER_POOL_SIZE}) must greate 104857600(100M) and less mem_available($[ ${mem_available} * 1024 ])"
		export exitflag=$[ ${exitflag} + 1 ]
	fi
}

help_this() {
	echo_color info "当前参数如下:"
	echo -e ""
	echo -e "###################################"
	echo -e "MYSQL_USER: ${MYSQL_USER}"
	echo -e "MYSQL_GROUP: ${MYSQL_GROUP}"
	echo -e "MYSQL_BIND_ADDRESS: ${MYSQL_BIND_ADDRESS}"
	echo -e "MYSQL_PORT: ${MYSQL_PORT}"
	echo -e "MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}"
	echo -e "MYSQL_BASE_DIR: ${MYSQL_BASE_DIR%/}/mysql"
	echo -e "MYSQL_DATA_DIR: ${MYSQL_DATA_DIR}"
	echo -e "MYSQL_LOG_DIR: ${MYSQL_LOG_DIR}"
	echo -e "MYSQL_INNODB_BUFFER_POOL_SIZE: ${MYSQL_INNODB_BUFFER_POOL_SIZE}" \#$[ ${MYSQL_INNODB_BUFFER_POOL_SIZE} / 1024 /1024 ]"MB"
	echo -e "MYSQL_INNODB_PAGE_SIZE: ${MYSQL_INNODB_PAGE_SIZE}"
	#echo -e "MYSQL_GTID_MODE: ${MYSQL_GTID_MODE}"
	echo -e "MYSQL_CNF: ${MYSQL_CNF}"
	echo -e "MYSQL_MAX_ALLOWED_PACKET: ${MYSQL_MAX_ALLOWED_PACKET}" \#$[ ${MYSQL_MAX_ALLOWED_PACKET} / 1024 /1024 ]"MB"
	echo -e "MYSQL_CHARACTER_SET: ${MYSQL_CHARACTER_SET}"
	echo -e "MYSQL_DEFAULT_STORAGE_ENGINE: ${MYSQL_DEFAULT_STORAGE_ENGINE}"
	echo -e "MYSQL_BINLOG_EXPIRE_LOGS_DAYS: ${MYSQL_BINLOG_EXPIRE_LOGS_DAYS}"
	echo -e "MYSQL_SYNC_BINLOG: ${MYSQL_SYNC_BINLOG}"
	echo -e "MYSQL_INNODB_FLUSH_LOG_AT_TRX_COMMIT: ${MYSQL_INNODB_FLUSH_LOG_AT_TRX_COMMIT}"
	echo -e "MYSQL_BINLOG: ${MYSQL_BINLOG}"
	echo -e "MYSQL_TAR: ${MYSQL_TAR}"
	echo -e "MYSQL_SERVER_ID: ${MYSQL_SERVER_ID}"
	echo -e "###################################"
	echo -e ""
	exit ${exitflag}
}

yumddcw() {
	export PACKT_TYPE="yum"
	which apt >/dev/null 2>&1 && which dpkg >/dev/null 2>&1 && PACKT_TYPE="apt"
	which zypper >/dev/null 2>&1 && which rpm >/dev/null 2>&1 && PACKT_TYPE="zypper"
	packages1=$@
	case ${PACKT_TYPE,,} in
		yum)
			yum -y ${packages1} >>${details} 2>&1 || echo_color warn "mysqlbe install ${packages1} failed ( yum -y ${packages1} )"
			;;
		apt)
			#包名转换, 有的包名在rhel和debian上不一样
			#packages1=$(echo ${packages1} | sed 's/ zlib / zlib1g /g; s/ zlib-devel / zlib1g-dev /g; s/ libaio / libaio1 /g; s/ openssl-libs / libssl1.0.0 /g; ')
			packages1=$(echo ${packages1} | sed 's/zlib/zlib1g/; s/zlib-devel/zlib1g-dev/; s/libaio/libaio1/; s/openssl-libs/libssl1.0.0/; ')
			apt -y $packages1 >>${details} 2>&1 || echo_color warn "mysqlbe install ${packages1} failed ( apt -y $packages1 )"
			;;
		zypper)
			zypper -n ${packages1} >>${details} 2>&1 || echo_color warn "mysqlbe install ${packages1} failed ( zypper -n ${packages1} )"
			;;
		*)
			echo_color err "内部错误 001"
			;;
	esac	
}

set_system_param() {
	#nofile
	[[ $(ulimit -n) -lt 123456 ]] >>${details} 2>&1 || cat << EOF >> /etc/security/limits.conf
* soft nofile 123456
* hard nofile 123456
root soft nofile 123456
root hard nofile 123456
${MYSQL_USER} soft nofile 123456
${MYSQL_USER} hard nofile 123456
EOF
	#aiomaxnr linux: /proc/sys/fs/aio-max-nr  mysql相关参数:innodb_use_native_aio
	[[ $(cat /proc/sys/fs/aio-max-nr) -lt 1048576 ]] || echo "fs.aio-max-nr = 1048579" >> /etc/sysctl.conf


	/sbin/sysctl -p /etc/sysctl.conf >>${details} 2>&1

}

set_env() {
	mkdir /tmp/ddcw -p
	touch /tmp/ddcw/.mysqlinstall_${MYSQL_PORT}.lock
	#log details
	echo_color detail "系统信息如下" ${details}
	echo_color detail "PLATFORM: ${PLATFORM}" ${details}
	echo_color detail "OS_TYPE: ${OS_TYPE}" ${details}
	echo_color detail "OS_NAME: ${OS_NAME}" ${details}
	echo_color detail "OS_VERSION: ${OS_VERSION}" ${details}
	echo_color detail "OS_ID/OS_ID_LIKE: ${OS_ID_LIKE_1}" ${details}
	echo_color info "开始安装"
	echo_color detail "MYSQL_PORT: ${MYSQL_PORT}" ${details}
	echo_color detail "MYSQL_BASE_DIR: ${MYSQL_BASE_DIR}" ${details}
	echo_color detail "MYSQL_DATA_DIR: ${MYSQL_DATA_DIR}" ${details}
	echo_color detail "MYSQL_LOG_DIR: ${MYSQL_LOG_DIR}" ${details}
	echo_color detail "MYSQL_INNODB_BUFFER_POOL_SIZE: ${MYSQL_INNODB_BUFFER_POOL_SIZE} #$[ ${MYSQL_INNODB_BUFFER_POOL_SIZE} / 1024 /1024 ] MB" ${details}
	echo_color detail "MYSQL_TAR: ${MYSQL_TAR}" ${details}
	echo_color detail "详细日志: ${details}" ${details}
	echo_color detail "开始检查/设置环境" ${details}
	useradd ${MYSQL_USER} -s /usr/sbin/nologin >>${details} 2>&1
	groupadd ${MYSQL_GROUP} >>${details} 2>&1
	usermod -g ${MYSQL_GROUP} ${MYSQL_USER} >>${details} 2>&1
	ldconfig -p | grep libssl.so >>${details} 2>&1 || yumddcw install openssl-libs 
	ldconfig -p | grep libaio.so.1 >>${details} 2>&1 || yumddcw  install libaio

	which yum >>${details} 2>&1 && yum install -y compat-openssl10 >>${details} 2>&1
	mkdir -p ${MYSQL_SOCKET%/*} ${MYSQL_BINLOG_BASENAME%/*}  ${MYSQL_BASE_DIR} ${MYSQL_DATA_DIR} ${MYSQL_LOG_DIR} ${MYSQL_TMP_DIR} ${MYSQL_ERROR%/*} ${MYSQL_SLOW_QUERY_LOG%/*} ${MYSQL_GENERAL_LOG_FILE%/*} ${MYSQL_INNODB_LOG_DIR%/} ${MYSQL_RELAY_LOG_FILE%/*} ${MYSQL_CNF%/*}  >>${details} 2>&1
	chown ${MYSQL_USER}:${MYSQL_GROUP} ${MYSQL_SOCKET%/*} ${MYSQL_BINLOG_BASENAME%/*} ${MYSQL_BASE_DIR} ${MYSQL_DATA_DIR} ${MYSQL_LOG_DIR} ${MYSQL_TMP_DIR} ${MYSQL_ERROR%/*} ${MYSQL_SLOW_QUERY_LOG%/*} ${MYSQL_GENERAL_LOG_FILE%/*} ${MYSQL_INNODB_LOG_DIR%/} ${MYSQL_RELAY_LOG_FILE%/*} ${MYSQL_CNF%/*} -R >>${details} 2>&1


	#关闭防火墙和selinux
	echo_color detail "关闭防火墙和selinux" ${details}
	systemctl stop firewalld >>${details} 2>&1
	systemctl disable firewalld >>${details} 2>&1
	service iptables stop >>${details} 2>&1
	chkconfig --del firewalld  >>${details} 2>&1

	setenforce 0  >>${details} 2>&1
	sed -i '/^SELINUX=/cSELINUX=disabled' /etc/selinux/config >>${details} 2>&1

	set_system_param
	
	#检查空间
	echo_color detail "检查空间" ${details}
	[[ $(df -m ${MYSQL_BASE_DIR} | awk '{sub(/\%/," "); print $(NF-2)}' | tail -n -1) -gt 5000 ]] || exits "${MYSQL_BASE_DIR} must greate 5000M"
	[[ $(df -m ${MYSQL_DATA_DIR} | awk '{sub(/\%/," "); print $(NF-2)}' | tail -n -1) -gt 5000 ]] || exits "${MYSQL_DATA_DIR} must greate 5000M"
	[[ $(df -m ${MYSQL_LOG_DIR} | awk '{sub(/\%/," "); print $(NF-2)}' | tail -n -1) -gt 1000 ]] || exits "${MYSQL_LOG_DIR} must greate 1000M"
	#[[ $(df -m . | awk '{sub(/\%/," "); print $(NF-2)}' | tail -n -1) -gt 5000 ]] || exits "current dir$(pwd) must greate 5000MB"
	echo_color detail "空间满足要求" ${details}

	#生成cnf
	echo_color detail "生成cnf文件 ${MYSQL_CNF}" ${details}
	set_mysql_cnf
	[[ -f ${MYSQL_CNF} ]] && echo_color detail "生成cnf成功" ${details}
}


set_mysql_cnf() {
	if [[ -f ${MYSQL_CNF} ]]; then
		echo_color detail "${MYSQL_CNF} has exists and it will be move to /tmp/.${MYSQL_CNF##*/}.${dt}.old "  ${details}
		mv ${MYSQL_CNF} /tmp/.${MYSQL_CNF##*/}.${dt}.old >> ${details} 2>&1
	fi

	cat << EOFMYSQLDDCW > ${MYSQL_CNF}
#create by ddcw at $(date +%Y%m%d-%H:%M:%S)
[mysql]
prompt=(\\\\u@\\\\h) [\\\\d]>\\\\_

[mysqld_safe]
user=${MYSQL_USER}
core-file-size=unlimited
open-files-limit=123456


[mysqld]
user=${MYSQL_USER}
bind_address=${MYSQL_BIND_ADDRESS}
port=${MYSQL_PORT}

basedir=${MYSQL_BASE_DIR}/mysql
datadir=${MYSQL_DATA_DIR}
socket=${MYSQL_SOCKET}
pid_file=${MYSQL_PID}

character-set-server=${MYSQL_CHARACTER_SET}
collation-server=${MYSQL_CHARACTER_SET}_general_ci

server_id=${MYSQL_SERVER_ID}

default_storage_engine=${MYSQL_DEFAULT_STORAGE_ENGINE}
disabled_storage_engines="${MYSQL_DISABLED_STORAGE_ENGINE}"

max_allowed_packet=${MYSQL_MAX_ALLOWED_PACKET}
max_connections=${MYSQL_MAX_CONNECTIONS}
max_user_connections=0
max_connect_errors=2000
table_open_cache=${MYSQL_TABLE_OPEN_CACHE}
open_files_limit=123456

join_buffer_size=2097152
sort_buffer_size=2097152
skip_name_resolve=${MYSQL_SKIP_NAME_RESOLVE}


tmpdir=${MYSQL_TMP_DIR}
log_error=${MYSQL_ERROR}
slow_query_log=${MYSQL_SLOW_QUERY}
slow_query_log_file=${MYSQL_SLOW_QUERY_LOG}
long_query_time=${MYSQL_LONG_QUERY}

general_log=${MYSQL_GENERAL_LOG}
general_log_file=${MYSQL_GENERAL_LOG_FILE}

expire_logs_days=${MYSQL_BINLOG_EXPIRE_LOGS_DAYS}



#===============binlog设置===============#
binlog_format=${MYSQL_BINLOG_FORMAT}
log_bin=${MYSQL_BINLOG_BASENAME}
#log_bin=${MYSQL_BINLOG}
#log_bin_basename=${MYSQL_BINLOG_BASENAME}
sync_binlog=${MYSQL_SYNC_BINLOG}
max_binlog_size=${MYSQL_MAX_BINLOG_SIZE}

#=============innodb===================#
innodb_log_group_home_dir=${MYSQL_INNODB_LOG_DIR}
innodb_log_files_in_group=${MYSQL_INNODB_LOG_FILES}
innodb_log_file_size=${MYSQL_INNODB_LOG_SIZE}
innodb_log_buffer_size=67108864
innodb_log_write_ahead_size=8192
innodb_data_home_dir=${MYSQL_INNODB_DATA_DIR}  #innodb系统表空间文件目录
innodb_temp_data_file_path="ibtmp1:50M:autoextend:max:${MYSQL_INNODB_TMP_MAX_SIZE}"
innodb_open_files=${MYSQL_INNODB_OPEN_FILES}
innodb_page_size=${MYSQL_INNODB_PAGE_SIZE}
innodb_default_row_format=${MYSQL_INNODB_DEFAULT_ROW_FORMAT}
innodb_file_per_table=ON

innodb_buffer_pool_size=${MYSQL_INNODB_BUFFER_POOL_SIZE}
innodb_buffer_pool_instances=1

innodb_doublewrite=${MYSQL_INNODB_DOUBLEWRITE}
innodb_fill_factor=${MYSQL_INNODB_FILL_FACTOR}

#SSD盘建议0   HDD建议1    8.0默认0   5.7默认1   
innodb_flush_neighbors=0  #0刷新的时候不刷邻居  1(默认): 刷新相同范围内的连续脏页 2:范围比1广
innodb_io_capacity=2500  #可以设置为实际测出来的值 机械盘建议低于2500  固态盘建议高于2500
innodb_io_capacity_max=5000  #2倍innodb_io_capacity

innodb_lock_wait_timeout=50 #单位秒
innodb_lru_scan_depth=${MYSQL_INNODB_LRU_SCAN_DEPTH}

innodb_read_only=off

#当变化的页数量达到20页时, 收集统计信息 默认20 建议20 若表数据量非常大, 可以增加这个值
innodb_stats_persistent_sample_pages=20
#指定InnoDB索引统计信息是否持久保存到磁盘 默认ON
innodb_stats_persistent=ON

innodb_thread_concurrency=64


#===============事务================#
transaction_isolation=${MYSQL_TRANSACTION_ISOLATION}
#tx_read_only=${MYSQL_TX_READ_ONLY}

innodb_flush_log_at_trx_commit=${MYSQL_INNODB_FLUSH_LOG_AT_TIMEOUT}
innodb_flush_log_at_timeout=1

binlog_gtid_simple_recovery=on


#=======================主从====================#
relay_log_info_file="relay-log.info"
relay_log="${MYSQL_RELAY_LOG_FILE}"
max_relay_log_size=104857600  #100M  默认0无限制
relay_log_info_repository=${MYSQL_RELAY_LOG_INFO_REPOSITORY}
master_info_repository="TABLE"
relay_log_purge=on


#=============gtid=================#
gtid_mode=${MYSQL_GTID_MODE}
enforce_gtid_consistency=on
#gtid_next=${MYSQL_GTID_NEXT}

#==========performance_schema=====#
performance_schema=${MYSQL_PERFORMANCE_SCHEMA}

EOFMYSQLDDCW

}

set_pid() {
	export PID_FILE="/tmp/ddcw/mysqlinstallByDDCWwithEI_${MYSQL_PORT}.pid"
	if [[ -f /proc/$(cat ${PID_FILE})/comm ]] >/dev/null 2>&1; then
		echo_color err "this script has running (PID: $(cat ${PID_FILE}) )"
		exit 127
	else
		mkdir -p ${PID_FILE%/*}
		echo ${THIS_PID} > ${PID_FILE}
	fi
}

mysql_jieya_jindutiao(){
	for i in {1..100}
	do
		if ls .tar_tmp_mysql_ddcw_jindutiao_hehe/*/bin/mysql >/dev/null 2>&1 ;then
			jindutiao 2 100
			break
		fi
		sleep 0.3
	done
	for i in {1..100}
	do
		if ls .tar_tmp_mysql_ddcw_jindutiao_hehe/*/bin/mysqladmin >/dev/null 2>&1 ;then
			jindutiao 5 100
			break
		fi
		sleep 0.3
	done
	for i in {1..100}
	do
		if ls .tar_tmp_mysql_ddcw_jindutiao_hehe/*/bin/mysqlbinlog >/dev/null 2>&1 ;then
			jindutiao 13 100
			break
		fi
		sleep 0.3
	done
	for i in {1..100}
	do
		if ls .tar_tmp_mysql_ddcw_jindutiao_hehe/*/bin/innochecksum >/dev/null 2>&1 ;then
			jindutiao 35 100
			break
		fi
		sleep 0.3
	done
	for i in {1..100}
	do
		if ls .tar_tmp_mysql_ddcw_jindutiao_hehe/*/bin/perror >/dev/null 2>&1 ;then
			jindutiao 40 100
			break
		fi
		sleep 0.3
	done
	for i in {1..100}
	do
		if ls .tar_tmp_mysql_ddcw_jindutiao_hehe/*/share/charsets/README >/dev/null 2>&1 ;then
			jindutiao 60 100
			break
		fi
		sleep 0.3
	done
	for i in {1..100}
	do
		if ls .tar_tmp_mysql_ddcw_jindutiao_hehe/*/support-files/mysql.server >/dev/null 2>&1 ;then
			jindutiao 100 100
			break
		fi
		sleep 0.3
	done
	echo -e "\r"
	echo -e "\n"
}


#遇到$1就停止, 每隔$2秒打印一个$3
diandianend() {
	[[ -z $1 ]] || endfile_=$1
	[[ -z $2 ]] || interval_=$2
	[[ -z $3 ]] || printflag_=$3
	[[ -z ${endfile_} ]] && exits "内部错误002" && break
	[[ -z ${interval_} ]] && interval_=3.5
	[[ -z ${printflag_} ]] && printflag_="."
	for i in {1..1000}
	do
		[[ -d ${endfile_%/*} ]] || break
		[[ -f ${endfile_} ]] && break
		echo -n "${printflag_}"
		sleep ${interval_}
	done
	#echo ""
}

install_mysql_base() {
	#echo ""
	echo_color detail "开始解压${MYSQL_TAR}.. 预计44秒"
	#rm -rf .tar_tmp_mysql_ddcw_jindutiao_hehe >/dev/null 2>&1
	#mkdir .tar_tmp_mysql_ddcw_jindutiao_hehe -p
	#[[ $(df -m .tar_tmp_mysql_ddcw_jindutiao_hehe | awk '{sub(/\%/," "); print $(NF-2)}' | tail -n -1) -gt 5000 ]] || exits "当前目录$(pwd) must greate 5000M"
	#mysql_jieya_jindutiao .tar_tmp_mysql_ddcw_jindutiao_hehe &
	#diandianend '.tar_tmp_mysql_ddcw_jindutiao_hehe/*/support-files/mysql.server' 2.2 "*" &
	mysql_tar_name=$(tar -xvf ${MYSQL_TAR} -C ${MYSQL_BASE_DIR%/})
	echo "解压内容为: ${mysql_tar_name}" >> ${details}
	mysql_tar_name=${mysql_tar_name%%/*}
	mv ${MYSQL_BASE_DIR%/}/${mysql_tar_name} ${MYSQL_BASE_DIR%/}/mysql >> ${details} 2>&1
	#mv .tar_tmp_mysql_ddcw_jindutiao_hehe/${mysql_tar_name} ${MYSQL_BASE_DIR%/}/mysql >> ${details} 2>&1
	#rm -rf .tar_tmp_mysql_ddcw_jindutiao_hehe >/dev/null 2>&1
	grep '##MYSQL_BASE_BY_DDCW' /etc/profile >> ${details} 2>&1 || echo "export PATH=${MYSQL_BASE_DIR%/}/mysql/bin:\$PATH ##MYSQL_BASE_BY_DDCW" >> /etc/profile
	(source /etc/profile >> ${details} 2>&1; which mysql >> ${details} 2>&1 || echo "export PATH=${MYSQL_BASE_DIR%/}/mysql/bin:\$PATH ##MYSQL_BASE_BY_DDCW" >> /etc/profile)
	[[ -f ~/.my.cnf ]] || cat << EOFMYCNF > ~/.my.cnf
[mysql]
prompt=(\\\\u@\\\\h) [\\\\d]>\\\\_
EOFMYCNF

	if ${MYSQL_BASE_DIR%/}/mysql/bin/mysql --version >> ${details} 2>&1 && ${MYSQL_BASE_DIR%/}/mysql/bin/mysqld --version >> ${details} 2>&1;then
		#echo_color n "\n[\033[32;40mINFO\033[0m `date +%Y%m%d-%H:%M:%S`] \033[32;40m mysql安装成功: `${MYSQL_BASE_DIR%/}/mysql/bin/mysqld --version 2>/dev/null`\033[0m"
		#echo ""
		echo_color detail "mysql安装成功: `${MYSQL_BASE_DIR%/}/mysql/bin/mysqld --version 2>/dev/null`" ${details}
	else
		echo_color detail "mysql安装失败: ${MYSQL_BASE_DIR%/}/mysql/bin/mysqld --version 报错 \n或者\n ${MYSQL_BASE_DIR%/}/mysql/bin/mysql --version 报错 " ${details}
		exit 126
	fi
	echo "INSTALL_MYSQL_SOFTWARE_DDCW_${MYSQL_PORT}" >  /tmp/ddcw/.mysqlinstall_${MYSQL_PORT}.lock 
}


#进度条: $1当前进度,  $2总进度
jindutiao(){
        jindutiaoflag=""
        jindutiaoflagn="1"
        max=$2
        current=$1
        baifenbi=$[ ${current} * 100 / ${max}  ]
	while [[  ${jindutiaoflagn} -lt ${baifenbi} ]];	do jindutiaoflagn=$[ ${jindutiaoflagn} + 1 ] jindutiaoflag="${jindutiaoflag}\033[32;40m#\033" ;done
	while [[ ${jindutiaoflagn} -lt ${max} ]]; do jindutiaoflagn=$[ ${jindutiaoflagn} + 1 ] jindutiaoflag="${jindutiaoflag}\033[31;40m.\033[0m"; done
        echo -ne "\r${baifenbi}% [${jindutiaoflag}]"
}

init_mysql() {
	echo_color detail "开始初始化实例: ${MYSQL_ERROR} (预计花费:123秒)" ${details}
	#echo_color detail "${MYSQL_BASE_DIR%/}/mysql/bin/mysqld --defaults-file=${MYSQL_CNF} --initialize 2>&1 | tee -a ${details}" ${details}
	echo_color detail "${MYSQL_BASE_DIR%/}/mysql/bin/mysqld --defaults-file=${MYSQL_CNF} --initialize " ${details}
	#diandianend "${MYSQL_DATA_DIR%/*}/mysql/user.frm" 2.2 "#" &
	${MYSQL_BASE_DIR%/}/mysql/bin/mysqld --defaults-file=${MYSQL_CNF} --initialize 2>&1 | tee -a ${details}
	sleep 5
	init_mysql_pwd=`grep "A temporary password is generated" ${MYSQL_ERROR} | tail -n1 | awk -F"root@localhost: " '{print $2}'` || exits "初始化失败, 请看日志 ${MYSQL_ERROR}"
	[[ -z ${init_mysql_pwd} ]] && exits "初始化实例失败, 请看日志 ${MYSQL_ERROR}"
	echo_color detail "配置启动服务: /etc/init.d/mysqld_${MYSQL_PORT}"
	rm -rf /etc/init.d/mysqld_${MYSQL_PORT}
	cp -rp ${MYSQL_BASE_DIR%/}/mysql/support-files/mysql.server  /etc/init.d/mysqld_${MYSQL_PORT} >>${details} 2>&1
	sed -i  "/^basedir/cbasedir=${MYSQL_BASE_DIR%/}/mysql" /etc/init.d/mysqld_${MYSQL_PORT} >>${details} 2>&1
	sed -i "/^datadir/cdatadir=${MYSQL_DATA_DIR}" /etc/init.d/mysqld_${MYSQL_PORT} >>${details} 2>&1
	sed -i "/^lockdir/clockdir=${MYSQL_PID%/*}" /etc/init.d/mysqld_${MYSQL_PORT} >>${details} 2>&1
	sed -i "/^mysqld_pid_file_path/cmysqld_pid_file_path=${MYSQL_PID}" /etc/init.d/mysqld_${MYSQL_PORT} >>${details} 2>&1
	sed -i "/mysqld_safe --datadir=/cnohup ./bin/mysqld_safe --defaults-file=${MYSQL_CNF} --user=${MYSQL_USER} >>${MYSQL_LOG_DIR}/nohup.out &" /etc/init.d/mysqld_${MYSQL_PORT}
	echo_color detail "配置mysql_${MYSQL_PORT}成功 即将启动mysql服务: /etc/init.d/mysqld_${MYSQL_PORT} start" ${details}
	systemctl daemon-reload  >>${details} 2>&1
	/etc/init.d/mysqld_${MYSQL_PORT} start >>${details} 2>&1

	sleep 2
	#校验启动成功:
	for i in {1..120}
	do
		${MYSQL_BASE_DIR%/}/mysql/bin/mysql --connect-expired-password -uroot -p"${init_mysql_pwd}" -S ${MYSQL_SOCKET} -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; " >/dev/null 2>&1 && break
		sleep 1.5
	done

	#echo ${MYSQL_BASE_DIR%/}/mysql/bin/mysql -uroot -P${MYSQL_PORT} -p"${MYSQL_ROOT_PASSWORD}" -S ${MYSQL_SOCKET}
	echo_color detail "开始创建账号; root@'%' 'backup'@'%' 'repl'@'%' "

	#${MYSQL_BASE_DIR%/}/mysql/bin/mysql --connect-expired-password -uroot -p"${init_mysql_pwd}" -S ${MYSQL_SOCKET} -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; flush privileges;" >>${details} 2>&1
	${MYSQL_BASE_DIR%/}/mysql/bin/mysql -uroot -P${MYSQL_PORT} -p"${MYSQL_ROOT_PASSWORD}" -S ${MYSQL_SOCKET} -e "create user root@'%' identified by '${MYSQL_ROOT_PASSWORD}'; grant all on *.* to root@'%'; flush privileges;"  >>${details} 2>&1 || echo_color detail "创建用户 root@'%' 失败" ${details}
	${MYSQL_BASE_DIR%/}/mysql/bin/mysql -uroot -P${MYSQL_PORT} -p"${MYSQL_ROOT_PASSWORD}" -S ${MYSQL_SOCKET} -e "create user backup@'%' identified WITH 'mysql_native_password' by 'backup'; grant RELOAD, PROCESS, REPLICATION CLIENT, REPLICATION SLAVE on *.* to 'backup'@'%'; create user 'repl'@'%' identified WITH 'mysql_native_password' by 'repl'; grant replication client,replication slave on *.* to 'repl'@'%'; flush privileges;"  >>${details} 2>&1 || echo_color detail "创建备份用户/同步用户失败" ${details}
	#${MYSQL_BASE_DIR%/}/mysql/bin/mysql -uroot -P${MYSQL_PORT} -p"${MYSQL_ROOT_PASSWORD}" -S ${MYSQL_SOCKET} -e "flush logs;"  >>${details} 2>&1 #刷一下日志, 不然配置主从的时候可能不行
	echo_color info "初始化mysql实例完成"

	echo "INIT_MYSQL_DDCW_${MYSQL_PORT}" >  /tmp/ddcw/.mysqlinstall_${MYSQL_PORT}.lock 
}

install_post() {
	mkdir -p /etc/ddcw || echo_color error "创建目录失败: /etc/ddcw"
	cat << EOFMYSQLCONF > /etc/ddcw/mysql_${MYSQL_PORT}.conf
#write by ddcw at $(date +%Y%m%d-%H:%M:%S) .
#https://github.com/ddcw
#BACKUP_HOST=${MYSQL_BIND_ADDRESS}
MYSQL_PORT="${MYSQL_PORT}"
BACKUP_USER="backup"
BACKUP_PASSWORD="backup"
BACKUP_SOCKET="${MYSQL_SOCKET}"
DEFAULT_CONFIG_FILES="${MYSQL_CNF}"
REPL_USER="repl"
REPL_PASSWORD="repl"
ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"
MYSQL_COMMAND="${MYSQL_BASE_DIR%/}/mysql/bin/mysql"
START_MYSQL_COMMAND="/etc/init.d/mysql_${MYSQL_PORT} start"
STOP_MYSQL_COMMAND="/etc/init.d/mysql_${MYSQL_PORT} stop"
RESTORE_USER="root"
RESTORE_PASSWORD="${MYSQL_ROOT_PASSWORD}"
LOCAL_IP="$((0x${LOCAL_MOST_IP16:6:2})).$((0x${LOCAL_MOST_IP16:4:2})).$((0x${LOCAL_MOST_IP16:2:2})).$((0x${LOCAL_MOST_IP16:0:2}))"
EOFMYSQLCONF
	rm -rf ${PID_FILE}
	rm -rf /tmp/ddcw/.mysqlinstall_${MYSQL_PORT}.lock
	echo ""
	echo_color info "启动mysql(${MYSQL_PORT}): /etc/init.d/mysqld_${MYSQL_PORT} start"
	echo_color info "停止mysql(${MYSQL_PORT}): /etc/init.d/mysqld_${MYSQL_PORT} stop"
	echo_color info "连接mysql参考命令: ${MYSQL_BASE_DIR%/}/mysql/bin/mysql -h127.0.0.1 -uroot -P${MYSQL_PORT} -p${MYSQL_ROOT_PASSWORD}"
	echo ""
	cost_time=$[ $(date +%s) - ${dt} ]
	if [[ ${cost_time} -ge 60 ]];then
		echo_color red "共计耗时约 $[ ${cost_time} / 60 ] 分钟"
	else
		echo_color green "共计耗时 ${cost_time} 秒"
	fi
}

init_user_params
init_auto_params
check_params
[[ ${HELP_FLAG} -eq 1 ]] && help_this
[[ ${exitflag} -gt 0 ]] && exit ${exitflag}
mkdir -p /tmp/ddcw && export details=/tmp/ddcw/.${0##*/}_$(date +%s)_detail.log
touch ${details}

#echo_color info "script begin"
echo "params:\n $@" >> ${details}
set_pid #生成PID, 防止脚本多次运行
set_env #检查环境, 默认自动解决依赖包,等

[[ -z $(cat /tmp/ddcw/.mysqlinstall_${MYSQL_PORT}.lock) ]] >/dev/null 2>&1 || echo_color detail "之前似乎已经安装过了的, 将继续上一次的安装(上一次的PID: $(cat ${PID_FILE}))" ${details}

#以下开始正式安装, 将会记录PID
if [[ "$(cat /tmp/ddcw/.mysqlinstall_${MYSQL_PORT}.lock)" == "INSTALL_MYSQL_SOFTWARE_DDCW_${MYSQL_PORT}" ]] || [[ "$(cat /tmp/ddcw/.mysqlinstall_${MYSQL_PORT}.lock)" == "INIT_MYSQL_DDCW_${MYSQL_PORT}" ]];then
	echo_color detail "软件已经安装, 将跳过该步骤" ${details}
else
	install_mysql_base
fi

if  [[ "$(cat /tmp/ddcw/.mysqlinstall_${MYSQL_PORT}.lock)" == "INIT_MYSQL_DDCW_${MYSQL_PORT}" ]];then
	echo_color detail "实例已经初始化完成, 将跳过该步骤" ${details}
else
	init_mysql
fi

install_post
exit 0
