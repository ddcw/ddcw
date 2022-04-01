from pymysqlreplication import BinLogStreamReader
from pymysqlreplication.row_event import (
	DeleteRowsEvent,
	UpdateRowsEvent,
	WriteRowsEvent,
	TableMapEvent,
)
#from pymysqlreplication.event import (XidEvent,QueryEvent,RotateEvent,)
import pymysql
from multiprocessing import Process, Queue, Manager, Value
import argparse
import signal
import sys
import time
import re


#定义版本
VERSION = "0.1"


def _argparse():
	parser = argparse.ArgumentParser(description='Mysql online schema change, 详情请看 https://github.com/ddcw')
	parser.add_argument('--host',  action='store', dest='host', default='127.0.0.1', help='数据库服务器地址. default 127.0.0.1')
	parser.add_argument('--port', '-P' ,  action='store', dest='port', default=3306, type=int , help='数据库端口. default 3306')
	parser.add_argument('--user', '-u' ,  action='store', dest='user', default="root",  help='数据库用户')
	parser.add_argument('--password', '-p' ,  action='store', dest='password',   help='数据库密码')
	parser.add_argument('--db-name', '-D' ,  action='store', dest='dbname',   help='数据库名字')
	parser.add_argument('--table-name', '-t' ,  action='store', dest='table_name',   help='表名字')
	parser.add_argument('--version', '-v', '-V', action='store_true', dest="version",  help='VERSION')
	parser.add_argument('--add-cols', '-a' ,  action='store', dest='add_cols', default="",   help='添加字段, 多个字段用,隔开(比如 id int,name varchar(20) )')
	parser.add_argument('--del-cols', '-d' ,  action='store', dest='del_cols', default="",  help='删除字段, 多个字段用,隔开(比如 id ,name  )')
	parser.add_argument('--reset-cols', '-r' ,  action='store', dest='reset_cols', default="",  help='重新设置某个(些)字段, 多个字段用,隔开(比如 id int ,name varchar(22)  )')
	parser.add_argument('--lock-table-min-rows', '-l' ,  action='store', dest='lock_table_min_rows', default=5, type=int , help='还剩多少行的时候就可以锁表了(默认5)')
	parser.add_argument('--no-log', '-n' ,  action='store_true', dest='no_log', default=False,  help='不记录日志(默认否, 就是要记录的意思, 不然主从里面, 主库变了, 从库没变....)')
	parser.add_argument('--print-ddl', '-pt' ,  action='store_true', dest='print_ddl', default=False,  help='仅打印修改之后的建表语句, 不执行任何操作..')
	return parser.parse_args()
	

#返回一个连接
def get_conn(HOST, PORT, USER, PASSWORD, DBNAME):
	conn = pymysql.connect(
		host=HOST,
		port=int(PORT),
		user=USER,
		password=PASSWORD,
		database=DBNAME,
	)
	return conn


def get_sql_result(cursor, sql):
	try:
		cursor.execute(sql)
		data = list(cursor.fetchall())
	except Exception as e:
		print(sql, e)
		return {"statue":False, "data":e}
	return {"statue":True, "data":data}


def modify_col(new_table_ddl,ADD_COLS, DEL_COLS, RESET_COLS ):
	#返回修改之后的SQL
	new_table_ddl_1 = new_table_ddl
	new_table_ddl_2 = new_table_ddl

	for x in ADD_COLS.split(","):
		new_table_ddl_2 = new_table_ddl_2.replace("\n) ENGINE=",''',\n{x}\n) ENGINE=''').format(x=x)
	for y in DEL_COLS.split(","):
		tmpa = ""
		for a in new_table_ddl_2.split("\n"):
			if "`{y}`".format(y=y) in a:
				continue
			tmpa = tmpa + str(a)+"\n"
		new_table_ddl_2 = tmpa
	for z in RESET_COLS.split(","):
		try:
			col_name = z.split()[0]
		except:
			break
		tmpa = ""
		for a in new_table_ddl_2.split("\n"):
			if "`{y}`".format(y=col_name) in a:
				continue
			tmpa = tmpa + str(a)+"\n"
		new_table_ddl_2 = tmpa.replace("\n\n","\n") #去掉空行
		new_table_ddl_2 = new_table_ddl_2.replace(",\n) ENGINE=","\n) ENGINE=") #去掉结尾的逗号
		new_table_ddl_2 = new_table_ddl_2.replace("\n) ENGINE=",''',\n{x}\n) ENGINE=''').format(x=z)
	if new_table_ddl_1 == new_table_ddl_2:
		print("修改了个寂寞.....")
		sys.exit(1)
	new_table_ddl_2 = new_table_ddl_2.replace("\n\n","\n") #去掉空行
	new_table_ddl_2 = new_table_ddl_2.replace(",\n) ENGINE=","\n) ENGINE=") #去掉结尾的逗号
	return new_table_ddl_2


def main(HOST, PORT, USER, PASSWORD, DBNAME, TABLE_NAME, ADD_COLS, DEL_COLS, RESET_COLS, LOCK_TABLE_MIN_ROWS, NO_LOG, PRINT_DDL):
	global CAN_DROP_NEW_TABLE
	global NEW_TABLE_NAME
	global END_POS
	global END_FILE
	global MIN_ROWS
	MIN_ROWS = LOCK_TABLE_MIN_ROWS

	CAN_DROP_NEW_TABLE = True  #当这个值为False的时候, 表示不能删除临时表


	#记录开始时间
	BEGIN_TIME = time.time()

	conn = get_conn(HOST, PORT, USER, PASSWORD, DBNAME)
	cursor = conn.cursor()
	NEW_TABLE_NAME = "_TMP_NEW_{TIME}_{TABLE_NAME}_BY_DDCW_".format(TABLE_NAME=TABLE_NAME, TIME=int(time.time()))

	if NO_LOG:
		get_sql_result(cursor,"set sql_log_bin=0;")


	#定义一个普通退出
	def quit1():
		cursor.execute("unlock tables")
		if CAN_DROP_NEW_TABLE:
			drop_new_table_result = get_sql_result(cursor, "drop table if exists {NEW_TABLE_NAME}".format(NEW_TABLE_NAME=NEW_TABLE_NAME))
			if drop_new_table_result["statue"]:
				print("已经删除新表, 不影响旧表")
				sys.exit(2)
			else:
				print("删除新表失败: {error}".format(error = drop_new_table_result["data"]))
	


	#捕获ctrl+c 异常退出的时候, 要回滚, 如果还没有到修改表名的那一步, 直接删掉表就行, 如果过了的话,就直接跑完
	#CURRENT_STATE 表示当前执行到哪一阶段了  具体的我还没想好....
	def quit(signum,frame):
		print("被手动停止了..")
		cursor.execute("unlock tables")
		if CAN_DROP_NEW_TABLE:
			drop_new_table_result = get_sql_result(cursor, "drop table if exists {NEW_TABLE_NAME}".format(NEW_TABLE_NAME=NEW_TABLE_NAME))
			if drop_new_table_result["statue"]:
				print("已经删除新表, 不影响旧表")
				sys.exit(2)
			else:
				print("删除新表失败: {error}".format(error = drop_new_table_result["data"]))

	signal.signal(signal.SIGINT,quit)
	
	r = get_sql_result(cursor,"show create table {TABLE_NAME}".format(TABLE_NAME=TABLE_NAME))
	if r["statue"]:
		new_table_ddl = r["data"][0][1].replace("CREATE TABLE `{TABLE_NAME}`".format(TABLE_NAME=TABLE_NAME), "CREATE TABLE IF NOT EXISTS `{NEW_TABLE_NAME}`".format(NEW_TABLE_NAME=NEW_TABLE_NAME))
		new_table_ddl = modify_col(new_table_ddl,ADD_COLS, DEL_COLS, RESET_COLS )		

		if PRINT_DDL:
			print(new_table_ddl)
			sys.exit(0)

		#new_table_ddl = new_table_ddl.replace('\n','')
		create_new_table = get_sql_result(cursor, new_table_ddl)
		if create_new_table["statue"]:
			print("建表成功或者表存在: {NEW_TABLE_NAME}".format(NEW_TABLE_NAME=NEW_TABLE_NAME))
		else:
			print("建表失败\n {new_table_ddl}".format(new_table_ddl=new_table_ddl))
			sys.exit(1)
	else:
		print("表或者数据库有问题....")
		sys.exit(1)


	#获取新表类型
	new_table_type = '''select COLUMN_NAME from information_schema.columns where table_name='{TABLE_NAME}' and TABLE_SCHEMA="{DBNAME}";'''.format(TABLE_NAME=NEW_TABLE_NAME, DBNAME=DBNAME)
	new_table_type_r = get_sql_result(cursor, new_table_type)["data"]

	FILE_POS_GTID_BEGIN = get_sql_result(cursor, "show master status;")
	FILE_BEGIN = FILE_POS_GTID_BEGIN["data"][0][0]
	POS_BGEIN = FILE_POS_GTID_BEGIN["data"][0][1]

	max_binlog_size = get_sql_result(cursor, "show variables like 'max_binlog_size';")["data"][0][1]
	END_POS = Value('d',float(max_binlog_size) * 2)
	#END_POS = int(max_binlog_size) * 2
	END_FILE = "XXXXXX"
	#print(END_POS)

	#单独开一个进程取抽取日志, 保存在队列里面
	q = Queue()
	get_binlog_process = Process(target=get_binlog, args=(HOST, PORT, USER, PASSWORD, DBNAME, TABLE_NAME, FILE_BEGIN, POS_BGEIN, END_POS, END_FILE, new_table_type_r, NEW_TABLE_NAME, q ), daemon=True) 
	get_binlog_process.start()
	#get_binlog_process.join()


	#开始复制旧表数据到新表
	print("开始复制表...")
	col_sql = 'select COLUMN_NAME from information_schema.COLUMNS where TABLE_SCHEMA="{DBNAME}" and TABLE_NAME="{TABLE_NAME}"'.format(TABLE_NAME=TABLE_NAME, DBNAME=DBNAME)
	table_cols_list = get_sql_result(cursor,col_sql)
	cols = ""
	if table_cols_list["statue"]:
		for col in table_cols_list["data"]:
			if col[0] in DEL_COLS.split(","):
				continue
			cols += ',{col}'.format(col=col[0]) #如果是删除部分字段, 这个地方就把对于字段去掉 修改字段并不影响字段名字,就不做处理
	else:
		print("获取表结构信息失败")
		sys.exit(1)
	cols = cols[1:]
	copy_sql = "insert into {DBNAME}.{new_table}({cols}) select {cols} from {DBNAME}.{old_table}".format(new_table = NEW_TABLE_NAME, old_table=TABLE_NAME, DBNAME=DBNAME,cols=cols)
	#print(copy_sql)
	try:
		cursor.execute("begin")
		cursor.execute(copy_sql)
		cursor.execute("commit")
	except Exception as e:
		print(e)
		sys.exit(1)
	print("复制表完成, 开始追平数据...")

	#获取当前的POS信息 同步进程跑到这就完了...
	FILE_POS_GTID_END = get_sql_result(cursor, "show master status;")
	END_POS.value = FILE_POS_GTID_END["data"][0][1]
	END_FILE = FILE_POS_GTID_END["data"][0][0]


	sql_count = 0 #执行的sql计数器
	while True:
		qsize = q.qsize()
		#if qsize < MIN_ROWS and not get_binlog_process.is_alive():
		if qsize < MIN_ROWS :
			lock_begin = time.time()
			print("还剩{n}条数据(小于 {MIN_ROWS}) 开始锁表,执行rename".format(n=qsize,MIN_ROWS=MIN_ROWS))
			#print("数据量小于 {MIN_ROWS}, 开始锁表".format(MIN_ROWS=MIN_ROWS))
			try:
				CAN_DROP_NEW_TABLE = False
				#cursor.execute("lock tables {old_table} write,{new_table} write;".format(old_table=TABLE_NAME, new_table=NEW_TABLE_NAME))
					
			except Exception as e:
				print(e)
				sys.exit(1)
			while True:
				qsize = q.qsize()
				if qsize == 0:
					break
				sql = q.get(timeout=1)
				try:
					cursor.execute(sql)
				except Exception as e:
					print(e)
					print(sql)
					exit(1)
			cursor.execute("commit")
			rename_sql_1 = "alter table {TABLE_NAME} rename {TMP_TABLE_NAME};".format(TABLE_NAME=TABLE_NAME, TMP_TABLE_NAME=NEW_TABLE_NAME+"_1")
			rename_sql_2 = "alter table {TABLE_NAME} rename {TMP_TABLE_NAME};".format(TABLE_NAME=NEW_TABLE_NAME, TMP_TABLE_NAME=TABLE_NAME)
			rename_sql_3 = "alter table {TABLE_NAME} rename {TMP_TABLE_NAME};".format(TABLE_NAME=NEW_TABLE_NAME+"_1", TMP_TABLE_NAME=NEW_TABLE_NAME)
			cursor.execute(rename_sql_1)
			cursor.execute(rename_sql_2)
			cursor.execute(rename_sql_3)
			#cursor.execute("unlock tables;")
			print("影响时间: {time} 秒".format(time = time.time() - lock_begin))
			CAN_DROP_NEW_TABLE = True
			break
		else:
			try:
				sql = q.get(timeout=1)
				#print(sql)
				cursor.execute(sql)
			except:
				continue

	END_POS.value = 1
	if CAN_DROP_NEW_TABLE:
		drop_new_table_result = get_sql_result(cursor, "drop table if exists {NEW_TABLE_NAME}".format(NEW_TABLE_NAME=NEW_TABLE_NAME))
		if drop_new_table_result["statue"]:
			#print("已经删除新表, 不影响旧表")
			print("在线DDL执行完成. 一共耗时 {time}  秒".format(time=time.time()-BEGIN_TIME))
			sys.exit(0)
		else:
			print("删除新表失败: {error}".format(error = drop_new_table_result["data"]))


def get_binlog(HOST, PORT, USER, PASSWORD, DBNAME, TABLE_NAME, FILE_BEGIN, POS_BGEIN, END_POS, END_FILE, new_table_type_r,NEW_TABLE_NAME, q):
	server_id = 12343210
	MYSQL_SETTINGS = {
	"host": HOST,
	"port": int(PORT),
	"user": USER,
	"passwd": PASSWORD,
	}

	stream = BinLogStreamReader(
		connection_settings=MYSQL_SETTINGS, 
		server_id=server_id, 
		blocking=True, 
		resume_stream=True, 
		log_file=FILE_BEGIN, 
		log_pos=POS_BGEIN,
		only_tables = TABLE_NAME,
		only_schemas = DBNAME,
		only_events = (UpdateRowsEvent, WriteRowsEvent, DeleteRowsEvent)
		)
	
	#print(new_table_type_r,type(new_table_type_r))
	#sys.exit(1)

	def put_sql(action,row):
		sql = ""
		row = row[0]

		if action == "u":
			#改为replace 方便点, 有空了再update
			#print(row["after_values"])
			#print(row["before_values"])
			columns = ""
			set_value = ""
			where = ""
			for col in row["after_values"]:
				for new_col in new_table_type_r:
					if col == new_col[0] and row["before_values"][col] is not None:
						set_value += ", {col}='{v}'".format(col=col, v=row["after_values"][col])
						where += "and {col}='{v}'".format(col=col, v=row["before_values"][col])
					else:
						continue
			set_value = set_value[1:]
			where = where[3:]
			sql = "update {NEW_TABLE_NAME} set {set_value} where {where}".format(NEW_TABLE_NAME=NEW_TABLE_NAME, set_value=set_value, where=where)
			#print(sql)
			
		elif action == "i":
			columns = ""
			values = ""
			for col in row["values"]:
				for new_col in new_table_type_r:
					if col == new_col[0] and row["values"][col] is not None:
						columns += ","+new_col[0]
						values += ",'" + str(row["values"][col]) + "'"
					else:
						continue
			columns = columns[1:]
			values = values[1:]
			#sql = "insert into {NEW_TABLE_NAME}({columns}) values({values})".format(NEW_TABLE_NAME=NEW_TABLE_NAME, columns=columns, values=values)
			sql = "replace into {NEW_TABLE_NAME}({columns}) values({values})".format(NEW_TABLE_NAME=NEW_TABLE_NAME, columns=columns, values=values)
			#print(sql)
		elif action == "d":
			where = ""
			for k in row["values"]:
				for new_col in new_table_type_r:
					if k == new_col[0] and row["values"][k] is not None:
						where += "and {k}='{v}'".format(k=k, v=row["values"][k])
					else:
						continue
			where = where[3:]
			sql = "delete from {NEW_TABLE_NAME} where {where}".format(NEW_TABLE_NAME=NEW_TABLE_NAME, where=where)
			#print(sql)
		else:
			print("gg")
			sys.exit(2)
		q.put(sql)
		

	q.put("begin")
	
	#这玩意是触发型的, 如果没得这张表相关的事务, 就不会执行这个for 也就不会判断执行没执行完....  也就不能根据这个进程是否存在来判断了...
	for binlogevent in stream:
		LOG_POSTION=binlogevent.packet.log_pos
		#log_file = binlogevent.packet.log_file
		log_file = "XXXXXX"
		#print("curr", LOG_POSTION, END_POS.value)
		if LOG_POSTION > int(END_POS.value) and END_FILE == log_file:
			print("抽数据的进程已经结束了....")
			sys.exit(0)
			return 
		if isinstance(binlogevent, UpdateRowsEvent):
			put_sql("u",binlogevent.rows)
		elif isinstance(binlogevent,WriteRowsEvent):
			put_sql("i",binlogevent.rows)
		elif isinstance(binlogevent,DeleteRowsEvent):
			put_sql("d",binlogevent.rows)
		else:
			continue
	stream.close()


if __name__ == "__main__":


	#解析参数
	parser = _argparse()
	if parser.version :
		print("Version: {VERSION}".format(VERSION=VERSION))
	else:
		main(parser.host, parser.port, parser.user, parser.password, parser.dbname, parser.table_name, parser.add_cols, parser.del_cols, parser.reset_cols, parser.lock_table_min_rows, parser.no_log, parser.print_ddl)

