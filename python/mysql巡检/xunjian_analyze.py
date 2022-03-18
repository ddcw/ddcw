import json
import argparse
import pandas as pd
import datetime
from jinja2 import FileSystemLoader,Environment

def main(FILE):
	with open(FILE,'r') as f :
		xunjian = json.load(f)
	xunjian_result = json.loads(xunjian)
	DBTYPE = xunjian_result["DBTYPE"]
	HOST = xunjian_result["HOST"]
	PORT = xunjian_result["PORT"]
	AUTHOR = xunjian_result["AUTHOR"]
	START_TIME = xunjian_result["START_TIME"]
	DATA = xunjian_result["DATA"]
	HOST_INFO = xunjian_result["HOST_INFO"]

	if DBTYPE == "MYSQL":
		users = pd.DataFrame(DATA["users"], columns=['Host', 'User', 'Select_priv', 'Insert_priv', 'Update_priv', 'Delete_priv', 'Create_priv', 'Drop_priv', 'Reload_priv', 'Shutdown_priv', 'Process_priv', 'File_priv', 'Grant_priv', 'References_priv', 'Index_priv', 'Alter_priv', 'Show_db_priv', 'Super_priv', 'Create_tmp_table_priv', 'Lock_tables_priv', 'Execute_priv', 'Repl_slave_priv', 'Repl_client_priv', 'Create_view_priv', 'Show_view_priv', 'Create_routine_priv', 'Alter_routine_priv', 'Create_user_priv', 'Event_priv', 'Trigger_priv', 'Create_tablespace_priv', 'ssl_type', 'ssl_cipher', 'x509_issuer', 'x509_subject', 'max_questions', 'max_updates', 'max_connections', 'max_user_connections', 'plugin', 'authentication_string', 'password_expired', 'password_last_changed', 'password_lifetime', 'account_locked'])
		#print(users['User'].values)
		version = DATA["version"]
		tps = DATA["tps"]
		qps = DATA["qps"]
		plugins = pd.DataFrame(DATA["plugins"], columns=['PLUGIN_NAME', 'PLUGIN_VERSION', 'PLUGIN_STATUS', 'PLUGIN_TYPE', 'PLUGIN_TYPE_VERSION', 'PLUGIN_LIBRARY', 'PLUGIN_LIBRARY_VERSION', 'PLUGIN_AUTHOR', 'PLUGIN_DESCRIPTION', 'PLUGIN_LICENSE', 'LOAD_OPTION'])
		#print(plugins["PLUGIN_NAME"])
		schemata = pd.DataFrame(DATA["schemata"], columns=['CATALOG_NAME', 'SCHEMA_NAME', 'DEFAULT_CHARACTER_SET_NAME', 'DEFAULT_COLLATION_NAME'])
		tables = pd.DataFrame(DATA["tables"], columns=['ABLE_CATALOG', 'TABLE_SCHEMA', 'TABLE_NAME', 'TABLE_TYPE', 'ENGINE', 'VERSION', 'ROW_FORMAT', 'TABLE_ROWS', 'AVG_ROW_LENGTH', 'DATA_LENGTH', 'MAX_DATA_LENGTH', 'INDEX_LENGTH', 'DATA_FREE', 'AUTO_INCREMENT', 'CREATE_TIME', 'UPDATE_TIME', 'CHECK_TIME', 'TABLE_COLLATION', 'CHECKSUM', 'CREATE_OPTIONS', 'TABLE_COMMENT'])
		cols = pd.DataFrame(DATA["cols"], columns=['TABLE_CATALOG', 'TABLE_SCHEMA', 'TABLE_NAME', 'COLUMN_NAME', 'ORDINAL_POSITION', 'COLUMN_DEFAULT', 'IS_NULLABLE', 'DATA_TYPE', 'CHARACTER_MAXIMUM_LENGTH', 'CHARACTER_OCTET_LENGTH', 'NUMERIC_PRECISION', 'NUMERIC_SCALE', 'DATETIME_PRECISION', 'CHARACTER_SET_NAME', 'COLLATION_NAME', 'COLUMN_TYPE', 'COLUMN_KEY', 'EXTRA', 'PRIVILEGES', 'COLUMN_COMMENT', 'GENERATION_EXPRESSION'])
		#print(cols["TABLE_NAME"].values)
		views = pd.DataFrame(DATA["views"], columns=['TABLE_CATALOG', 'TABLE_SCHEMA', 'TABLE_NAME', 'VIEW_DEFINITION', 'CHECK_OPTION', 'IS_UPDATABLE', 'DEFINER', 'SECURITY_TYPE', 'CHARACTER_SET_CLIENT', 'COLLATION_CONNECTION'])
		events = pd.DataFrame(DATA["events"], columns=['EVENT_CATALOG', 'EVENT_SCHEMA', 'EVENT_NAME', 'DEFINER', 'TIME_ZONE', 'EVENT_BODY', 'EVENT_DEFINITION', 'EVENT_TYPE', 'EXECUTE_AT', 'INTERVAL_VALUE', 'INTERVAL_FIELD', 'SQL_MODE', 'STARTS', 'ENDS', 'STATUS', 'ON_COMPLETION', 'CREATED', 'LAST_ALTERED', 'LAST_EXECUTED', 'EVENT_COMMENT', 'ORIGINATOR', 'CHARACTER_SET_CLIENT', 'COLLATION_CONNECTION', 'DATABASE_COLLATION'])
		partitions = pd.DataFrame(DATA["partitions"], columns=['TABLE_CATALOG', 'TABLE_SCHEMA', 'TABLE_NAME', 'PARTITION_NAME', 'SUBPARTITION_NAME', 'PARTITION_ORDINAL_POSITION', 'SUBPARTITION_ORDINAL_POSITION', 'PARTITION_METHOD', 'SUBPARTITION_METHOD', 'PARTITION_EXPRESSION', 'SUBPARTITION_EXPRESSION', 'PARTITION_DESCRIPTION', 'TABLE_ROWS', 'AVG_ROW_LENGTH', 'DATA_LENGTH', 'MAX_DATA_LENGTH', 'INDEX_LENGTH', 'DATA_FREE', 'CREATE_TIME', 'UPDATE_TIME', 'CHECK_TIME', 'CHECKSUM', 'PARTITION_COMMENT', 'NODEGROUP', 'TABLESPACE_NAME'])
		user_pri = pd.DataFrame(DATA["user_pri"], columns=['GRANTEE', 'TABLE_CATALOG', 'PRIVILEGE_TYPE', 'IS_GRANTABLE'])
		db_pri = pd.DataFrame(DATA["db_pri"], columns=['Host', 'Db', 'User', 'Select_priv', 'Insert_priv', 'Update_priv', 'Delete_priv', 'Create_priv', 'Drop_priv', 'Grant_priv', 'References_priv', 'Index_priv', 'Alter_priv', 'Create_tmp_table_priv', 'Lock_tables_priv', 'Create_view_priv', 'Show_view_priv', 'Create_routine_priv', 'Alter_routine_priv', 'Execute_priv', 'Event_priv', 'Trigger_priv'])
		status = pd.DataFrame(DATA["status"], columns=['key','value']).set_index('key')
		#Uptime = status.loc['Uptime','value']
		variables = pd.DataFrame(DATA["variables"], columns=['key','value']).set_index('key')
		if version[0][0][0:1] == 8:
			binlog = pd.DataFrame(DATA["binlog"], columns=['Log_name','File_size','Encrypted'])
		elif version[0][0][0:1] == 5:
			binlog = pd.DataFrame(DATA["binlog"], columns=['Log_name','File_size'])
		else:
			binlog = "not support"
		engine_innodb_status = DATA["engine_innodb_status"]
		threads = pd.DataFrame(DATA["threads"], columns=['THREAD_ID', 'NAME', 'TYPE', 'PROCESSLIST_ID', 'PROCESSLIST_USER', 'PROCESSLIST_HOST', 'PROCESSLIST_DB', 'PROCESSLIST_COMMAND', 'PROCESSLIST_TIME', 'PROCESSLIST_STATE', 'PROCESSLIST_INFO', 'PARENT_THREAD_ID', 'ROLE', 'INSTRUMENTED', 'HISTORY', 'CONNECTION_TYPE', 'THREAD_OS_ID'])
		slave_master_info = pd.DataFrame(DATA["slave_master_info"], columns=['Number_of_lines', 'Master_log_name', 'Master_log_pos', 'Host', 'User_name', 'Port', 'Connect_retry', 'Enabled_ssl', 'Heartbeat', 'Retry_count'])
		slave_relay_log_info = pd.DataFrame(DATA["slave_relay_log_info"], columns=['Number_of_lines', 'Relay_log_name', 'Relay_log_pos', 'Master_log_name', 'Master_log_pos', 'Sql_delay', 'Number_of_workers', 'Id', 'Channel_name'])
		slave_worker_info =  pd.DataFrame(DATA["slave_worker_info"], columns=['Id', 'Relay_log_name', 'Relay_log_pos', 'Master_log_name', 'Master_log_pos', 'Channel_name'])
		slave_status = DATA["slave_status"]
		innodb_trx = pd.DataFrame(DATA["innodb_trx"], columns=['trx_id', 'trx_state', 'trx_started', 'trx_requested_lock_id', 'trx_wait_started', 'trx_weight', 'trx_mysql_thread_id', 'trx_query', 'trx_operation_state', 'trx_tables_in_use', 'trx_tables_locked', 'trx_lock_structs', 'trx_lock_memory_bytes', 'trx_rows_locked', 'trx_rows_modified', 'trx_concurrency_tickets', 'trx_isolation_level', 'trx_unique_checks', 'trx_foreign_key_checks', 'trx_last_foreign_key_error', 'trx_adaptive_hash_latched', 'trx_adaptive_hash_timeout', 'trx_is_read_only', 'trx_autocommit_non_locking'])
		innodb_locks = pd.DataFrame(DATA["innodb_locks"], columns=['wait_started', 'wait_age', 'wait_age_secs', 'locked_table', 'locked_table_schema', 'locked_table_name', 'locked_index', 'locked_type', 'waiting_trx_id', 'waiting_trx_started', 'waiting_trx_age', 'waiting_trx_rows_locked', 'waiting_trx_rows_modified', 'waiting_pid', 'waiting_query', 'waiting_lock_id', 'waiting_lock_mode', 'blocking_trx_id', 'blocking_pid', 'blocking_query', 'blocking_lock_id', 'blocking_lock_mode', 'blocking_trx_started', 'blocking_trx_age', 'blocking_trx_rows_locked', 'blocking_trx_rows_modified', 'sql_kill_blocking_query', 'sql_kill_blocking_connection'])
		processlist = pd.DataFrame(DATA["processlist"], columns=['ID', 'USER', 'HOST', 'DB', 'COMMAND', 'TIME', 'STATE', 'INFO'])
		statistics = pd.DataFrame(DATA["statistics"], columns=['TABLE_CATALOG', 'TABLE_SCHEMA', 'TABLE_NAME', 'NON_UNIQUE', 'INDEX_SCHEMA', 'INDEX_NAME', 'SEQ_IN_INDEX', 'COLUMN_NAME', 'COLLATION', 'CARDINALITY', 'SUB_PART', 'PACKED', 'NULLABLE', 'INDEX_TYPE', 'COMMENT', 'INDEX_COMMENT'])

		#innodb的统计信息
		innodb_table_stats = pd.DataFrame(DATA["innodb_table_stats"], columns=['database_name', 'table_name', 'last_update', 'n_rows', 'clustered_index_size', 'sum_of_other_index_sizes'])
		innodb_index_stats = pd.DataFrame(DATA["innodb_index_stats"], columns=['database_name', 'table_name', 'index_name', 'last_update', 'stat_name', 'stat_value', 'sample_size', 'stat_description'])
		

		#sql执行情况
		statement_analysis = pd.DataFrame(DATA["statement_analysis"], columns=['query', 'db', 'full_scan', 'exec_count', 'total_latency', 'max_latency', 'avg_latency', 'lock_latency', 'rows_sent', 'rows_sent_avg', 'digest'])



		#主机信息采集
		HAVE_DATA = HOST_INFO["HAVE_DATA"]
		#if HAVE_DATA == "yes":
		OS_TYPE = HOST_INFO["OS_TYPE"]
		OS_LIKE = HOST_INFO["OS_LIKE"]
		OS_NAME = HOST_INFO["OS_NAME"]
		PLATFORM = HOST_INFO["PLATFORM"]
		KERNEL_VERSION = HOST_INFO["KERNEL_VERSION"]
		CPU_USAGE_100 = HOST_INFO["CPU_USAGE_100"]  #CPU当前使用百分比
		CPU_USAGE_100_TOTAL = HOST_INFO["CPU_USAGE_100_TOTAL"] #CPU总使用百分比
		DF_HT = HOST_INFO["DF_HT"].split("\n") #不准备显示这个数据, 就不做转换了... (当前是一维数组)
		MEM_TOTAL = int(HOST_INFO["MEM_TOTAL"])
		MEM_ALI = int(HOST_INFO["MEM_ALI"])
		LOAD_AVG = HOST_INFO["LOAD_AVG"]
		TCP4_SOCKET = HOST_INFO["TCP4_SOCKET"]
		HOSTNAME = HOST_INFO["HOSTNAME"]
		SWAP_TOTAL = HOST_INFO["SWAP_TOTAL"]
		SWAPPINESS = HOST_INFO["SWAPPINESS"]
		TIME_ZONE = HOST_INFO["TIME_ZONE"]
		TOP500_DMESG = HOST_INFO["TOP500_DMESG"]

		DATA_DIR = HOST_INFO["MYSQL_INFO"]["datadir"].split()
		LOGBIN_DIR = HOST_INFO["MYSQL_INFO"]["log_bin_dir"].split()
		RELAY_DIR = HOST_INFO["MYSQL_INFO"]["relay_log_dir"].split()

		SLOW_LOG = HOST_INFO["MYSQL_INFO"]["tail500_slow_query_log"]
		ERROR_LOG = HOST_INFO["MYSQL_INFO"]["tail500_log_error"]


		#数据采集完成, 开始分析, 初步打算输出格式为 html 用jinja2来搞, 但是前端界面还没有想好, 就先print讲究下把.....
		#print("数据库类型:{DBTYPE} {version}".format(DBTYPE=DBTYPE, version=version[0][0])) 
		#print("数据库 IP端口: {HOST}:{PORT}".format(HOST=HOST, PORT=HOST))
		#print("总库数量: {rows}".format(rows=schemata.shape[0]))
		#print("数据库为: {db}".format(db=schemata["SCHEMA_NAME"].values))
		#print("总数据量为: {total_size} 字节".format(total_size=tables["DATA_LENGTH"].sum(axis=0)))
		#print("总索引大小为: {total_size} 字节".format(total_size=tables["INDEX_LENGTH"].sum(axis=0)))
		#print("TPS: {tps}    QPS: {qps}".format(tps=tps,qps=qps))
		#print("总表数量 {count}".format(count=tables.shape[0]))
		#print("主库是: {master}  从库是:{slave}".format(master=slave_master_info[['Host','Port']], slave=processlist.where(processlist['COMMAND']=="Binlog Dump")[["HOST"]].dropna()))
		#print(tables[["TABLE_SCHEMA","TABLE_NAME",'DATA_LENGTH','INDEX_LENGTH']].sort_values(by=["DATA_LENGTH",'INDEX_LENGTH'], ascending=False).head(10)) #所有表

		#重复索引
		#print("重复索引的表")
		re_index = statistics[statistics.duplicated(subset=['TABLE_SCHEMA','TABLE_NAME','COLUMN_NAME'],keep=False)]#重复索引 subset根据什么字段判断为重复索引
		repeat_index=re_index[['TABLE_SCHEMA','TABLE_NAME','INDEX_NAME','COLUMN_NAME']]

		#无主键的表
		#print("无主键/唯一索引的表")
		primary_key_unique_key_table = cols[cols.COLUMN_KEY.isin(['PRI','UNI'])][['TABLE_SCHEMA','TABLE_NAME']]  #相当于 select TABLE_SCHEMA,TABLE_NAME from cols where COLUMN_KEY in (PRI,UNI)
		no_primary_key = pd.concat([tables[['TABLE_SCHEMA','TABLE_NAME']],primary_key_unique_key_table,primary_key_unique_key_table]).drop_duplicates(keep=False) #取并集,然后删除重复的所有行

		#没得索引的表, 也就是排除 PRI UNI  MUL
		#print("没得索引的表")
		have_index_table = cols[cols.COLUMN_KEY.isin(['PRI','UNI','MUL'])][['TABLE_SCHEMA','TABLE_NAME']]
		no_index = pd.concat([tables[['TABLE_SCHEMA','TABLE_NAME']],have_index_table,have_index_table]).drop_duplicates(keep=False)

		#非innodb表
		#print("非innodb表")
		#print(tables[~tables.ENGINE.isin(['InnoDB'])][['TABLE_SCHEMA','TABLE_NAME','ENGINE']])

		#显示插件信息
		#print(plugins[['PLUGIN_NAME','PLUGIN_STATUS','PLUGIN_TYPE','PLUGIN_LIBRARY','PLUGIN_LICENSE']])
		all_plugins = plugins[['PLUGIN_NAME','PLUGIN_STATUS','PLUGIN_TYPE','PLUGIN_TYPE_VERSION','PLUGIN_AUTHOR','LOAD_OPTION']]

		#长时间未更新统计信息的表/索引 本次演示就是2天前
		over30days_table_static = innodb_table_stats.where(innodb_table_stats['last_update'] < str(datetime.datetime.now() - datetime.timedelta(days=30)), ).dropna()
		over30days_index_static = innodb_index_stats.where(innodb_index_stats['last_update'] < str(datetime.datetime.now() - datetime.timedelta(days=30)), ).dropna()

		#变量
		#print("取部分变量")
		#print(variables.loc['version','value'])
		#print(variables.loc['transaction_isolation','value'])

		#状态
		#print("部分状态信息")
		#print(status.loc['Uptime','value'])
		#print(status.loc['Connections','value'])

		#主从信息
		#print("主从复制进程状态")
		#print(slave_status[0][10])
		#print(slave_status[0][11])
		Master_Host=slave_status[0][1]
		Master_Port=slave_status[0][3]
		Slave_IO_Running=slave_status[0][10]
		Slave_SQL_Running=slave_status[0][11]
		Master_Bind=slave_status[0][46]


		#碎片
		#print("碎片大于1M")
		over_100M_data_free = tables.where(tables["DATA_FREE"]>107374182400 )[['TABLE_SCHEMA','TABLE_NAME','DATA_FREE']].dropna()

		#用户和权限
		#print("用户和权限")
		#print(users[['Host','User']])
		user_any = users.where(users["Host"]=="%")[['User','Host']].dropna()


		#锁
		#print("innodb锁")
		#print(innodb_locks)
		

		#各种TOP10
		#print("连接时间最长的10个会话")
		session_top10 = processlist[['USER', 'HOST', 'DB', 'COMMAND', 'TIME', 'STATE', 'INFO']].sort_values(by=["TIME"], ascending=False).head(10)


		#TOP10 sql
		sql_top10 = statement_analysis[['query', 'db', 'full_scan', 'exec_count', 'total_latency', 'max_latency', 'avg_latency', 'lock_latency', 'rows_sent', 'rows_sent_avg', 'digest']].sort_values(by=["exec_count","total_latency"],ascending=False).head(10)
		

		#top10 table
		table_top10 = tables[["TABLE_SCHEMA","TABLE_NAME","TABLE_ROWS","DATA_LENGTH","INDEX_LENGTH"]].sort_values(by=["DATA_LENGTH","INDEX_LENGTH"],ascending=False).head(10)

		#top10 lock
		lock_top10 = innodb_locks[[ "locked_table_schema","locked_table_name",'wait_age_secs','locked_index','locked_type', 'waiting_query','blocking_query','sql_kill_blocking_query' ]].sort_values(by=['wait_age_secs'],ascending=False).head(10)

		#测试
		#print("####################################################################################")
		#print(tables.groupby(['TABLE_SCHEMA']).agg({'TABLE_NAME':'count','DATA_LENGTH':'sum','INDEX_LENGTH':'sum'}).sort_values(by=['DATA_LENGTH','INDEX_LENGTH'], ascending=False).reset_index(inplace=False))
		#print(type(repeat_index),repeat_index)
		#print(type(list(DATA_DIR)),list(DATA_DIR),DATA_DIR.split()[1])
		#print(type(MEM_TOTAL),MEM_TOTAL,MEM_ALI)

		#渲染模板
		env = Environment(loader=FileSystemLoader('./')) 
		template = env.get_template('templates.html')
		tmp_file = template.render(
author=AUTHOR,
host=HOST,
port=PORT,
dbtype=DBTYPE, 
version=version[0][0], 
server_id=variables.loc['server_id','value'],
isslave=any(slave_master_info),
uptime=int(status.loc['Uptime','value']),
dbcount=tables.groupby(['TABLE_SCHEMA']).agg({'TABLE_NAME':'count','DATA_LENGTH':'sum','INDEX_LENGTH':'sum'}).sort_values(by=['DATA_LENGTH','INDEX_LENGTH'], ascending=False).reset_index(inplace=False).values,
no_innodb=tables[~tables.ENGINE.isin(['InnoDB'])][['TABLE_SCHEMA','TABLE_NAME','ENGINE']].values,
no_primary=no_primary_key.values,
repeat_index=repeat_index.values,
no_index=no_index.values,
over30days_table_static=over30days_table_static.values,
over30days_index_static=over30days_index_static.values,
over_100M_data_free=over_100M_data_free.values,
user_any=user_any.values,
tps=tps,
qps=qps,
transaction_isolation=variables.loc['transaction_isolation','value'],
master_host=Master_Host,
master_port=Master_Port,
slave_io_running=Slave_IO_Running,
slave_sql_running=Slave_SQL_Running,
master_bind=Master_Bind,
session_top10=session_top10.values,
sql_top10=sql_top10.values,
table_top10=table_top10.values,
have_host=(HAVE_DATA == "yes"),
data_dir=DATA_DIR,
logbin_dir=LOGBIN_DIR,
relay_dir=RELAY_DIR,
all_plugins=all_plugins.values,
cpu_p=CPU_USAGE_100,
cpu_p_total=CPU_USAGE_100_TOTAL,
mem_p=round( (MEM_TOTAL - MEM_ALI ) / MEM_TOTAL ,2),
os_detail="{OS_NAME} {PLATFORM} {KERNEL_VERSION}".format(OS_NAME=OS_NAME, PLATFORM=PLATFORM, KERNEL_VERSION=KERNEL_VERSION),
loadavg=LOAD_AVG,
lock_top10=lock_top10.values,
)
		FILE_HTML = '{FILE}.html'.format(FILE=FILE)
		with open(FILE_HTML,'w') as fhtml :
			fhtml.write(tmp_file)
		print("分析完成, 结果保存在 {html}".format(html=FILE_HTML))


	elif DBTYPE == "PG":
		print('暂不支持 pg')
	else:
		print("不支持 {DBTYPE}".format(DBTYPE=DBTYPE))

def _argparse():
	parser = argparse.ArgumentParser(description='Mysql xunjian analyze by ddcw. you can visit https://github.com/ddcw')
	parser.add_argument('--file', '-f' ,  action='store', dest='file', required=True,   help='need analyze file ')
	parser.add_argument('--version', '-v', '-V', action='store_true', dest="version",   help='VERSION')
	return parser.parse_args()

if __name__ == '__main__':
	parser = _argparse()
	if parser.version :
		print("Version: 0.1")
	else:
		main(parser.file)
