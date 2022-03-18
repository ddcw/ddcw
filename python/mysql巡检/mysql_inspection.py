import pymysql
import time
import json
import argparse
import subprocess
import paramiko

#版本定义
VERSION = "0.11"

#作者
#AUTHOR = "ddcw"



def main(MYSQL_HOST,MYSQL_PORT,MYSQL_USER,MYSQL_PASSWORD, SAVED_FILE, NO_FILE, SSH_PORT, SSH_USER, SSH_PASSWORD, AUTHOR):

	current_time = str(time.strftime('%Y%m%d_%H%M%S', time.localtime()))
	if SAVED_FILE is None:
		SAVED_FILE = "ddcw_mysql_xunjian_{host}_{port}_{date}.json".format(host=MYSQL_HOST, port=MYSQL_PORT, date=current_time)
	
	inspection_info = {}
	inspection_info["DBTYPE"]="MYSQL"
	inspection_info["HOST"]=MYSQL_HOST
	inspection_info["PORT"]=MYSQL_PORT
	inspection_info["AUTHOR"]=AUTHOR
	inspection_info["START_TIME"]=current_time
	inspection_info["VERSION"]=VERSION
	inspection_info["DATA"]={}
	inspection_info["HOST_INFO"]={}
	
	db = pymysql.connect(
	host=MYSQL_HOST,
	port=int(MYSQL_PORT),
	user=MYSQL_USER,
	password=MYSQL_PASSWORD,
	database="information_schema"
	)


	def get_host_info():
		host_info = {}
		host_info["HAVE_DATA"] = "no"
		ssh_host = MYSQL_HOST
		ssh_port = SSH_PORT
		ssh_user = SSH_USER
		ssh_password = SSH_PASSWORD
		IS_LOCALHOST = False
		global get_command_result
		if MYSQL_HOST == "0.0.0.0" or MYSQL_HOST == "127.0.0.1":
			IS_LOCALHOST = True

		if ssh_password is None and not IS_LOCALHOST :
			return host_info
		elif IS_LOCALHOST:
			def get_command_result(comm):
				return str(subprocess.Popen(comm, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout.read().rstrip(),encoding="utf-8")
		else:
			ssh = paramiko.SSHClient()
			try:
				ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
				ssh.connect(hostname=ssh_host, port=ssh_port, username=ssh_user, password=ssh_password)
			except Exception as e:
				print(e)
				print("将跳过主机信息巡检")
				return host_info
			def get_command_result(comm):
				stdin, stdout, stderr = ssh.exec_command(comm)
				return str(stdout.read().rstrip(),encoding="utf-8")
			
		host_info["HAVE_DATA"] = "yes"
		host_info["OS_TYPE"] = get_command_result("cat /proc/sys/kernel/ostype")
		host_info["OS_LIKE"] = get_command_result("""grep '^ID_LIKE=' /etc/os-release  | awk -F =  '{print $2}' | sed 's/\"//g' | awk '{print $1}'""")
		host_info["OS_NAME"] = get_command_result("""grep "^NAME=" /etc/os-release  | awk -F = '{print $2}' | sed 's/\"//g'""")
		host_info["PLATFORM"] = get_command_result("uname -m")
		host_info["KERNEL_VERSION"] = get_command_result("uname -r")
		cpu_sock = int(get_command_result("/usr/bin/lscpu  | /usr/bin/grep 'Socket(s)' | /usr/bin/awk '{print $NF}'"))
		cpu_core = int(get_command_result("/usr/bin/lscpu  | /usr/bin/grep 'Core(s)' | /usr/bin/awk '{print $NF}'"))
		cpu_thread = int(get_command_result("/usr/bin/lscpu  | /usr/bin/grep 'Thread(s)' | /usr/bin/awk '{print $NF}'"))
		cpu_count = cpu_sock * cpu_core * cpu_thread
		host_info["CPU_SOCK"] = cpu_sock
		host_info["CPU_CORE"] = cpu_core
		host_info["CPU_THREAD"] = cpu_thread
		uptime_res = get_command_result("/usr/bin/cat /proc/uptime")
		uptime = round(float(uptime_res.split()[0])/60/60/24,2) #开机时间 单位天
		cpu_b = get_command_result("/usr/bin/head -1 /proc/stat | /usr/bin/awk '{print $2+$3+$4+$5+$6+$7+$8+$9+$(10),$5}'")
		time.sleep(0.1)
		cpu_e = get_command_result("/usr/bin/head -1 /proc/stat | /usr/bin/awk '{print $2+$3+$4+$5+$6+$7+$8+$9+$(10),$5}'")
		cpu_total = int(cpu_e.split()[0]) - int(cpu_b.split()[0])
		cpu_idle = int(cpu_e.split()[1]) - int(cpu_b.split()[1])
		cpu_p = (cpu_total - cpu_idle ) / cpu_total #cpu当前使用率  总为1
		cpu_p100 = round((cpu_total - cpu_idle ) / cpu_total * 100,3)  #CPU当前使用百分比
		cpu_p_total = round((float(uptime_res.split()[0]) * cpu_count  - float(uptime_res.split()[1]))/float(uptime_res.split()[0])*100*cpu_count,3)#cpu开机到现在的使用百分比
		host_info["CPU_USAGE_100"] = cpu_p100
		host_info["CPU_USAGE_100_TOTAL"] = cpu_p_total
		host_info["DF_HT"] = get_command_result("df -PT | tail -n +2")
		host_info["MEM_TOTAL"] = get_command_result("/usr/bin/grep MemTotal /proc/meminfo | /usr/bin/awk '{print $2}'")
		host_info["MEM_ALI"] = get_command_result("/usr/bin/grep MemAvailable /proc/meminfo | /usr/bin/awk '{print $2}'")
		host_info["LOAD_AVG"] = get_command_result("/usr/bin/awk '{print $1,$2,$3}' /proc/loadavg")
		host_info["TCP4_SOCKET"] = get_command_result("/usr/bin/wc -l /proc/net/tcp | /usr/bin/awk '{print $1-1}'")
		host_info["HOSTNAME"] = get_command_result("/usr/bin/cat /proc/sys/kernel/hostname")
		host_info["SWAP_TOTAL"] = get_command_result("/usr/bin/grep SwapTotal /proc/meminfo | /usr/bin/awk '{print $2}'")
		host_info["SWAPPINESS"] = get_command_result("/usr/bin/cat /proc/sys/vm/swappiness")
		host_info["TIME_ZONE"] = get_command_result("ls -l /etc/localtime | awk -F /zoneinfo/ '{print $NF}'")
		host_info["TOP500_DMESG"] = get_command_result("tail -500 /var/log/dmesg")

		return host_info

	
	def get_info(sql):
		cursor = db.cursor()
		try:
			cursor.execute(sql)
			data = list(cursor.fetchall())
		except Exception as e:
			print(e)
			data = " FAILED to execute ( {sql} ) ".format(sql=sql)
		finally:
			#cursor.close()
			return data


	#主机信息巡检
	inspection_info["HOST_INFO"] = get_host_info()

	#如果主机巡检成功了的话, 就看下对应的目录信息,日志之类的
	if inspection_info["HOST_INFO"]["HAVE_DATA"] == "yes":
		inspection_info["HOST_INFO"]["MYSQL_INFO"]={}
		inspection_info["HOST_INFO"]["MYSQL_INFO"]["tmpdir"] = get_command_result("df -PT {dir} | tail -n +2".format(dir=get_info("show variables like 'tmpdir';")[0][1]))
		inspection_info["HOST_INFO"]["MYSQL_INFO"]["datadir"] = get_command_result("df -PT {dir} | tail -n +2".format(dir=get_info("show variables like 'datadir';")[0][1]))
		inspection_info["HOST_INFO"]["MYSQL_INFO"]["innodb_data_home_dir"] = get_command_result("df -PT {dir} | tail -n +2".format(dir=get_info("show variables like 'innodb_data_home_dir';")[0][1]))
		inspection_info["HOST_INFO"]["MYSQL_INFO"]["redo_log_dir"] = get_command_result("df -PT {dir} | tail -n +2".format(dir=get_info("show variables like 'innodb_log_group_home_dir';")[0][1]))
		inspection_info["HOST_INFO"]["MYSQL_INFO"]["log_bin_dir"] = get_command_result("df -PT $(tail -1 {dir} ) | tail -n +2".format(dir=get_info("show variables like 'log_bin_index';")[0][1]))
		inspection_info["HOST_INFO"]["MYSQL_INFO"]["relay_log_dir"] = get_command_result("df -PT $(tail -1 {dir} ) | tail -n +2".format(dir=get_info("show variables like 'relay_log_index';")[0][1]))
		inspection_info["HOST_INFO"]["MYSQL_INFO"]["tail500_slow_query_log"] = get_command_result("tail -500 {dir}".format(dir=get_info("show variables like 'slow_query_log_file';")[0][1]))
		inspection_info["HOST_INFO"]["MYSQL_INFO"]["tail500_log_error"] = get_command_result("tail -500 {dir}".format(dir=get_info("show variables like 'log_error';")[0][1]))
		
	#数据库版本, 支持的插件
	inspection_info["DATA"]["version"] = get_info("select @@version;")
	inspection_info["DATA"]["plugins"] = get_info("select PLUGIN_NAME,PLUGIN_VERSION,PLUGIN_STATUS,PLUGIN_TYPE,PLUGIN_TYPE_VERSION,PLUGIN_LIBRARY,PLUGIN_LIBRARY_VERSION,PLUGIN_AUTHOR,PLUGIN_DESCRIPTION,PLUGIN_LICENSE,LOAD_OPTION from information_schema.plugins;")
	
	
	#数据库用户SCHEMA TABLE COLS VIEWS EVENTS 和分区信息 和statics
	inspection_info["DATA"]["users"] = get_info("select Host,User,Select_priv,Insert_priv,Update_priv,Delete_priv,Create_priv,Drop_priv,Reload_priv,Shutdown_priv,Process_priv,File_priv,Grant_priv,References_priv,Index_priv,Alter_priv,Show_db_priv,Super_priv,Create_tmp_table_priv,Lock_tables_priv,Execute_priv,Repl_slave_priv,Repl_client_priv,Create_view_priv,Show_view_priv,Create_routine_priv,Alter_routine_priv,Create_user_priv,Event_priv,Trigger_priv,Create_tablespace_priv,ssl_type,ssl_cipher,x509_issuer,x509_subject,max_questions,max_updates,max_connections,max_user_connections,plugin,authentication_string,password_expired,password_last_changed,password_lifetime,account_locked from mysql.user;")
	inspection_info["DATA"]["schemata"] = get_info("select CATALOG_NAME,SCHEMA_NAME,DEFAULT_CHARACTER_SET_NAME,DEFAULT_COLLATION_NAME from information_schema.schemata WHERE SCHEMA_NAME NOT IN ('mysql', 'performance_schema', 'information_schema', 'sys');")
	inspection_info["DATA"]["tables"] = get_info("select TABLE_CATALOG,TABLE_SCHEMA,TABLE_NAME,TABLE_TYPE,ENGINE,VERSION,ROW_FORMAT,TABLE_ROWS,AVG_ROW_LENGTH,DATA_LENGTH,MAX_DATA_LENGTH,INDEX_LENGTH,DATA_FREE,AUTO_INCREMENT,CREATE_TIME,UPDATE_TIME,CHECK_TIME,TABLE_COLLATION,CHECKSUM,CREATE_OPTIONS,TABLE_COMMENT from information_schema.tables where TABLE_SCHEMA not in ('sys','mysql','information_schema','performance_schema');")
	inspection_info["DATA"]["cols"] = get_info("select TABLE_CATALOG,TABLE_SCHEMA,TABLE_NAME,COLUMN_NAME,ORDINAL_POSITION,COLUMN_DEFAULT,IS_NULLABLE,DATA_TYPE,CHARACTER_MAXIMUM_LENGTH,CHARACTER_OCTET_LENGTH,NUMERIC_PRECISION,NUMERIC_SCALE,DATETIME_PRECISION,CHARACTER_SET_NAME,COLLATION_NAME,COLUMN_TYPE,COLUMN_KEY,EXTRA,PRIVILEGES,COLUMN_COMMENT,GENERATION_EXPRESSION from information_schema.COLUMNS where TABLE_SCHEMA not in ('sys','mysql','information_schema','performance_schema');")
	inspection_info["DATA"]["views"] = get_info("select TABLE_CATALOG,TABLE_SCHEMA,TABLE_NAME,VIEW_DEFINITION,CHECK_OPTION,IS_UPDATABLE,DEFINER,SECURITY_TYPE,CHARACTER_SET_CLIENT,COLLATION_CONNECTION from information_schema.VIEWS where TABLE_SCHEMA not in ('sys','mysql','information_schema','performance_schema');")
	inspection_info["DATA"]["events"] = get_info("select EVENT_CATALOG,EVENT_SCHEMA,EVENT_NAME,DEFINER,TIME_ZONE,EVENT_BODY,EVENT_DEFINITION,EVENT_TYPE,EXECUTE_AT,INTERVAL_VALUE,INTERVAL_FIELD,SQL_MODE,STARTS,ENDS,STATUS,ON_COMPLETION,CREATED,LAST_ALTERED,LAST_EXECUTED,EVENT_COMMENT,ORIGINATOR,CHARACTER_SET_CLIENT,COLLATION_CONNECTION,DATABASE_COLLATION from information_schema.events where event_name not in ('sys','mysql','information_schema','performance_schema');")
	inspection_info["DATA"]["partitions"] = get_info("select TABLE_CATALOG,TABLE_SCHEMA,TABLE_NAME,PARTITION_NAME,SUBPARTITION_NAME,PARTITION_ORDINAL_POSITION,SUBPARTITION_ORDINAL_POSITION,PARTITION_METHOD,SUBPARTITION_METHOD,PARTITION_EXPRESSION,SUBPARTITION_EXPRESSION,PARTITION_DESCRIPTION,TABLE_ROWS,AVG_ROW_LENGTH,DATA_LENGTH,MAX_DATA_LENGTH,INDEX_LENGTH,DATA_FREE,CREATE_TIME,UPDATE_TIME,CHECK_TIME,CHECKSUM,PARTITION_COMMENT,NODEGROUP,TABLESPACE_NAME from information_schema.PARTITIONS where TABLE_SCHEMA not in ('sys','mysql','information_schema','performance_schema');")
	inspection_info["DATA"]["statistics"] = get_info("select TABLE_CATALOG,TABLE_SCHEMA,TABLE_NAME,NON_UNIQUE,INDEX_SCHEMA,INDEX_NAME,SEQ_IN_INDEX,COLUMN_NAME,COLLATION,CARDINALITY,SUB_PART,PACKED,NULLABLE,INDEX_TYPE,COMMENT,INDEX_COMMENT from information_schema.statistics where TABLE_SCHEMA not in ('sys','mysql','information_schema','performance_schema') ;")	

	#权限 表级和字段级 就不管了, 这玩意影响性能不算太大
	inspection_info["DATA"]["user_pri"] = get_info("select GRANTEE,TABLE_CATALOG,PRIVILEGE_TYPE,IS_GRANTABLE from information_schema.USER_PRIVILEGES;")
	inspection_info["DATA"]["db_pri"] = get_info(" select Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv,Create_priv,Drop_priv,Grant_priv,References_priv,Index_priv,Alter_priv,Create_tmp_table_priv,Lock_tables_priv,Create_view_priv,Show_view_priv,Create_routine_priv,Alter_routine_priv,Execute_priv,Event_priv,Trigger_priv from mysql.db;")
	
	#状态信息
	inspection_info["DATA"]["status"] = get_info("show global status;")
	inspection_info["DATA"]["variables"] = get_info("show global variables;")
	inspection_info["DATA"]["engine_innodb_status"] = get_info("SHOW ENGINE INNODB STATUS;")
	inspection_info["DATA"]["binlog"] = get_info("SHOW BINARY LOGS;")
	
	
	#线程信息
	inspection_info["DATA"]["threads"] = get_info("select THREAD_ID,NAME,TYPE,PROCESSLIST_ID,PROCESSLIST_USER,PROCESSLIST_HOST,PROCESSLIST_DB,PROCESSLIST_COMMAND,PROCESSLIST_TIME,PROCESSLIST_STATE,PROCESSLIST_INFO,PARENT_THREAD_ID,ROLE,INSTRUMENTED,HISTORY,CONNECTION_TYPE,THREAD_OS_ID from performance_schema.threads;") #performance_schema可能没有开启
	
	#主从相关的参数
	inspection_info["DATA"]["slave_master_info"] = get_info("select Number_of_lines,Master_log_name,Master_log_pos,Host,User_name,Port,Connect_retry,Enabled_ssl,Heartbeat,Retry_count from mysql.slave_master_info;")
	inspection_info["DATA"]["slave_relay_log_info"] = get_info("select Number_of_lines,Relay_log_name,Relay_log_pos,Master_log_name,Master_log_pos,Sql_delay,Number_of_workers,Id,Channel_name from mysql.slave_relay_log_info;")
	inspection_info["DATA"]["slave_worker_info"] = get_info("select Id,Relay_log_name,Relay_log_pos,Master_log_name,Master_log_pos,Channel_name from mysql.slave_worker_info;")
	inspection_info["DATA"]["slave_status"] = get_info("show slave status")
	
	#事务, 锁, 会话(processlist)等
	inspection_info["DATA"]["innodb_trx"] = get_info("select trx_id,trx_state,trx_started,trx_requested_lock_id,trx_wait_started,trx_weight,trx_mysql_thread_id,trx_query,trx_operation_state,trx_tables_in_use,trx_tables_locked,trx_lock_structs,trx_lock_memory_bytes,trx_rows_locked,trx_rows_modified,trx_concurrency_tickets,trx_isolation_level,trx_unique_checks,trx_foreign_key_checks,trx_last_foreign_key_error,trx_adaptive_hash_latched,trx_adaptive_hash_timeout,trx_is_read_only,trx_autocommit_non_locking from information_schema.INNODB_TRX;") #当前的事务
	inspection_info["DATA"]["innodb_locks"] = get_info("select wait_started,wait_age,wait_age_secs,locked_table,locked_table_schema,locked_table_name,locked_index,locked_type,waiting_trx_id,waiting_trx_started,waiting_trx_age,waiting_trx_rows_locked,waiting_trx_rows_modified,waiting_pid,waiting_query,waiting_lock_id,waiting_lock_mode,blocking_trx_id,blocking_pid,blocking_query,blocking_lock_id,blocking_lock_mode,blocking_trx_started,blocking_trx_age,blocking_trx_rows_locked,blocking_trx_rows_modified,sql_kill_blocking_query,sql_kill_blocking_connection from sys.innodb_lock_waits;") #5.7 sys.innodb_lock_waits = information_schema.INNODB_TRX + INFORMATION_SCHEMA.INNODB_LOCK_WAITS    8.0 sys.innodb_lock_waits = information_schema.INNODB_TRX + `performance_schema`.`data_lock_waits` ...  当前的锁
	inspection_info["DATA"]["processlist"] = get_info("select ID,USER,HOST,DB,COMMAND,TIME,STATE,INFO from information_schema.PROCESSLIST;") #会话

	#innodb统计信息
	inspection_info["DATA"]["innodb_table_stats"] = get_info("select database_name,table_name,last_update,n_rows,clustered_index_size,sum_of_other_index_sizes from mysql.innodb_table_stats where database_name not in ('sys','mysql','information_schema','performance_schema');")
	inspection_info["DATA"]["innodb_index_stats"] = get_info("select database_name,table_name,index_name,last_update,stat_name,stat_value,sample_size,stat_description from mysql.innodb_index_stats where database_name not in ('sys','mysql','information_schema','performance_schema');")

	#sql执行情况
	inspection_info["DATA"]["statement_analysis"] = get_info("select query,db,full_scan,exec_count,total_latency,max_latency,avg_latency,lock_latency,rows_sent,rows_sent_avg,digest from sys.statement_analysis;")
	
	
	#TPS QPS
	qps_begin = get_info("show global status like 'Questions';")
	tps_begin_commit = get_info("show global status like 'Com_commit';")
	tps_begin_rollback = get_info("show global status like 'Com_rollback';")
	time.sleep(1)
	qps_end = get_info("show global status like 'Questions';")
	tps_end_commit = get_info("show global status like 'Com_commit';")
	tps_end_rollback = get_info("show global status like 'Com_rollback';")
	QPS = int(qps_end[0][1]) - int(qps_begin[0][1])
	TPS = int(tps_end_commit[0][1]) + int(tps_end_rollback[0][1]) - int(tps_begin_commit[0][1]) - int(tps_begin_rollback[0][1])
	inspection_info["DATA"]["qps"] = QPS
	inspection_info["DATA"]["tps"] = TPS
	
	
	
	class MyJsonEncoder(json.JSONEncoder):
		def default(self,obj):
			return str(obj)
	
	inspection_info = json.dumps(inspection_info, cls=MyJsonEncoder) 
	db.close()
	if NO_FILE:
		print(inspection_info)
	else:
		with open(SAVED_FILE,"w") as f:
			#f.write( json.dumps(inspection_info) )
			json.dump(inspection_info,f)
		print("(你真棒!) 巡检完成. 巡检结果已保存在 {SAVED_FILE} ".format(SAVED_FILE=SAVED_FILE))

def _argparse():
	parser = argparse.ArgumentParser(description='Mysql xunjian script by ddcw. you can visit https://github.com/ddcw')
	parser.add_argument('--host',  action='store', dest='mysql_host', default='127.0.0.1', help='mysql server ip/host. default 127.0.0.1')
	parser.add_argument('--port', '-P' ,  action='store', dest='mysql_port', default=3306, type=int , help='mysql server port. default 3306')
	parser.add_argument('--ssh-port', '-sshP' ,  action='store', dest='ssh_port', default=22, type=int , help='ssh port')
	parser.add_argument('--user', '-u' ,  action='store', dest='mysql_user', default="root",  help='mysql user. default root')
	parser.add_argument('--ssh-user', '-sshu' ,  action='store', dest='ssh_user', default="root",  help='ssh user. default root')
	parser.add_argument('--password', '-p' ,  action='store', dest='mysql_password',   help='mysql password of mysql user')
	parser.add_argument('--ssh-password', '-sshp' ,  action='store', dest='ssh_password',   help='ssh user password ')
	parser.add_argument('--file', '-f' ,  action='store', dest='saved_file',   help='Save mysql inspection results. default ddcw_mysql_xunjian_xxxxxxxx_xxxx.json ')
	parser.add_argument('--no-file',  action='store_true', dest="no_file",   help='print mysql inspection results')
	parser.add_argument('--author',  action='store', dest="author", default="ddcw",   help='author ')
	parser.add_argument('--version', '-v', '-V', action='store_true', dest="version",  help='VERSION')
	return parser.parse_args()

#print(parser)
#print(parser.mysql_host)
#print(parser.no_file)

if __name__ == '__main__':
	parser = _argparse()
	if parser.version :
		print("Version: {VERSION}".format(VERSION=VERSION))
	else:
		main(parser.mysql_host, parser.mysql_port, parser.mysql_user, parser.mysql_password, parser.saved_file, parser.no_file, parser.ssh_port, parser.ssh_user, parser.ssh_password, parser.author)

