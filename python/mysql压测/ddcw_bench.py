import time
import pymysql
#import cx_Oracle
import argparse
from multiprocessing import Process, Queue, Manager
from faker import Faker
import random
import signal
import sys


#本脚本版本定义
VERSION = "0.1"


#返回一个cursor
def get_cursor(MYSQL_HOST,MYSQL_PORT,MYSQL_USER,MYSQL_PASSWORD,DBNAME):
	db = pymysql.connect(
	host=MYSQL_HOST,
	port=int(MYSQL_PORT),
	user=MYSQL_USER,
	password=MYSQL_PASSWORD,
	database=DBNAME,
	)
	return db.cursor()


#插入数据
def insert_table(HOST, PORT, USER, PASSWORD, DBNAME, ACTION, TABLE_BASE_NAME, TABLE_ROWS, TABLE_PER_COMMIT, TABLE_THREAD, NO_LOG, TABLE_COUNT, p, q):
	fake = Faker()
	cursor = get_cursor(HOST, PORT, USER, PASSWORD, DBNAME)
	#while not q.empty():  #多进程, 不可靠....
	while True:
		try:
			table_index = str(q.get(block=False,timeout=10))
		except:
			break
		if int(table_index) > int(TABLE_COUNT):
			break
		table_name = str(TABLE_BASE_NAME) + str(table_index)
		print("process: {p} 往 {table_name} 插入 {TABLE_ROWS} 行... ".format(p=p,table_name=table_name, TABLE_ROWS=TABLE_ROWS))
		rest_of_rows = TABLE_ROWS
		#cursor.execute("lock tables {table_name} WRITE;".format(table_name=table_name))
		while rest_of_rows > 0 :
			run_rows = TABLE_PER_COMMIT if rest_of_rows > TABLE_PER_COMMIT else rest_of_rows
			values = ""
			for x in range(0, run_rows ):
				k = random.randint(1,TABLE_ROWS-20)
				values += ",('{k}','{c}','{c2}')".format(k=random.randint(1,TABLE_ROWS-20), c=fake.text(100), c2=fake.text(50))
			sql = "insert into {table_name}(k,c,c2) values{values}".format(table_name=table_name, values=values[1:])
			cursor.execute("begin;")
			cursor.execute(sql)
			cursor.execute("commit;")
			rest_of_rows -= TABLE_PER_COMMIT
		#本来像顺便把索引创建了, 结果会产生metadata lock.. 原因: 建表后没有提交...  虽然其它表能查询到索引和数据...
		print("process: {p} 给表 {table_name} 创建索引 k_{table_index}".format(p=p,table_name=table_name, table_index=table_index))
		#cursor.execute("unlock tables;")
		cursor.execute("begin;")
		cursor.execute("CREATE INDEX k_{table_index} ON {table_name}(k)".format(table_index=table_index, table_name=table_name))
		cursor.execute("commit;")
	cursor.close()


#随机压测
def bench(HOST, PORT, USER, PASSWORD, DBNAME, ACTION, TABLE_BASE_NAME, TABLE_ROWS, TABLE_PER_COMMIT, TABLE_THREAD, NO_LOG, TABLE_COUNT, p, MODE):
	cursor = get_cursor(HOST, PORT, USER, PASSWORD, DBNAME)
	fake = Faker()

	time.sleep(random.random()+random.random()+random.random()+random.random())#随机沉睡一段时间, 醒来就该干活了..
	def bench_write_sql():
		while True:
			table_name = str(TABLE_BASE_NAME) + str(random.randint(1,TABLE_COUNT))
			for index in range(1,TABLE_ROWS+1):
				sql = []
				sql.append("UPDATE {table_name} SET k=k+1 WHERE id={index};".format(table_name=table_name, index=random.randint(1,TABLE_ROWS)))
				sql.append("UPDATE {table_name} SET c ='{c}' WHERE id={index};".format(table_name=table_name,c=fake.text(100), index=random.randint(1,TABLE_ROWS)))
				sql.append("DELETE FROM {table_name} WHERE id={index}".format(table_name=table_name, index=index))
				sql.append("INSERT INTO {table_name} (id, k, c, c2) VALUES({index},{index2},'{c}','{c2}')".format(table_name=table_name, index=index, index2=index+1, c=fake.text(100), c2=fake.text(50)))
				yield sql
	def bench_read_sql():
		while True:
			table_name = str(TABLE_BASE_NAME) + str(random.randint(1,TABLE_COUNT))
			for index in range(1,TABLE_ROWS+1):
				sql = []
				for x in range(1,19):
					sql.append("SELECT c FROM {table_name} WHERE id={index}".format(table_name=table_name, index=random.randint(1,TABLE_ROWS)))
				yield sql
	def bench_read_write_sql():
		while True:
			table_name = str(TABLE_BASE_NAME) + str(random.randint(1,TABLE_COUNT))
			for index in range(1,TABLE_ROWS+1):
				sql = []
				sql.append("UPDATE {table_name} SET k=k+1 WHERE id={index};".format(table_name=table_name, index=random.randint(1,TABLE_ROWS)))
				sql.append("UPDATE {table_name} SET c ='{c}' WHERE id={index};".format(table_name=table_name,c=fake.text(100), index=random.randint(1,TABLE_ROWS)))
				sql.append("DELETE FROM {table_name} WHERE id={index}".format(table_name=table_name, index=index))
				sql.append("INSERT INTO {table_name} (id, k, c, c2) VALUES({index},{index2},'{c}','{c2}')".format(table_name=table_name, index=index, index2=index+1, c=fake.text(100), c2=fake.text(50)))
				for x in range(1,19):
					sql.append("SELECT c FROM {table_name} WHERE id={index}".format(table_name=table_name, index=random.randint(1,TABLE_ROWS)))
				yield sql
				
	write_sql = bench_write_sql()
	read_sql = bench_read_sql()
	read_write_sql = bench_read_write_sql()
	if MODE == 0:
		for sql_list in read_write_sql:
			cursor.execute("begin;")
			for sql in sql_list:
				try:
					cursor.execute(sql)
				except:
					cursor.execute("rollback")
					time.sleep(random.random())
					break
			cursor.execute("commit")
	elif MODE == 1:
		for sql_list in read_sql:
			cursor.execute("begin;")
			for sql in sql_list:
				try:
					cursor.execute(sql)
				except:
					cursor.execute("rollback")
					time.sleep(random.random())
					break
			cursor.execute("commit")
	elif MODE == 2:
		for sql_list in write_sql:
			cursor.execute("begin;")
			for sql in sql_list:
				try:
					cursor.execute(sql)
				except:
					cursor.execute("rollback")
					time.sleep(random.random())
					break
			cursor.execute("commit")
	
	else:
		return


#返回一个dict
def get_query_commit_rollback_mysql(cursor):
	
	#oracle 参考
	#select value from V$SYSSTAT where name = 'execute count';  #间隔一秒的差值就是QPS
	#select value from V$SYSSTAT where name = 'user commits' ;
	#select value from V$SYSSTAT where name = 'user rollbacks' ;

	#mysql参考
	#show global status like 'Questions';
	#show global status like 'Com_commit';
	#show global status like 'Com_rollback';

	#PG
	#自己搜索...

	cursor.execute("show global status like 'Questions';")
	user_query_count = int(list(cursor.fetchall())[0][1])
	cursor.execute("show global status like 'Com_commit';")
	user_commit_count = int(list(cursor.fetchall())[0][1])
	cursor.execute("show global status like 'Com_rollback';")
	user_rollback_count = int(list(cursor.fetchall())[0][1])

	return {"query":user_query_count,"commit_rollback":user_commit_count+user_rollback_count}



def _argparse():
	parser = argparse.ArgumentParser(description='Mysql 压测脚本, 其它类型的请看 https://github.com/ddcw')
	parser.add_argument('--type',  action='store', dest='db_type', default='mysql', help='数据库类型(目前只支持Mysql)')
	parser.add_argument('--host',  action='store', dest='host', default='127.0.0.1', help='数据库服务器地址. default 127.0.0.1')
	parser.add_argument('--port', '-P' ,  action='store', dest='port', default=3306, type=int , help='数据库端口. default 3306')
	parser.add_argument('--user', '-u' ,  action='store', dest='user', default="root",  help='数据库用户')
	parser.add_argument('--password', '-p' ,  action='store', dest='password',   help='数据库密码')
	parser.add_argument('--db-name', '-d' ,  action='store', dest='dbname',   help='数据库名字')
	parser.add_argument('--version', '-v', '-V', action='store_true', dest="version",  help='VERSION')
	parser.add_argument( action='store', dest='action', nargs='?', default='prepare', help='prepare|run|cleanup')
	parser.add_argument('--table-count', '-t' ,  action='store', dest='table_count', default=12, type=int, help='表的数量 默认12')
	parser.add_argument('--table-name', '-Tname' ,  action='store', dest='table_name', default="ddcw", type=str, help='表的名字 默认ddcw')
	parser.add_argument('--table-rows', '-Trows' ,  action='store', dest='table_rows', default=100000, type=int, help='每张表有多少行 默认100K')
	parser.add_argument('--insert-per-commit', '-i' ,  action='store', dest='insert_per_commit', default=1000, type=int, help='准备数据的时候, 多少次insert后再commit(只有prepare阶段才有效) 默认1000')
	parser.add_argument('--no-log', '-n' ,  action='store_true', dest='no_log', default=True,  help='准备数据的时候, 是否写日志(默认不写)')
	parser.add_argument('--report-interval', '-ri' ,  action='store', dest='report_interval', default=10, type=int, help='多少秒显示一次结果(默认10)')
	parser.add_argument('--thread', '-T' ,  action='store', dest='thread', default=4, type=int , help='并行度(默认4)')
	parser.add_argument('--run-time',  '-r',  action='store', dest='runtime', default=120, type=int , help='运行时间(单位:秒)(默认120)')
	parser.add_argument('--mode', '-m',    action='store', dest='mode', choices=[0,1,2], default=0, type=int , help='0 读写混合(2u + 1d + 1i + 14s)   1 仅读   2 仅写  (默认0)')
	return parser.parse_args()
	

#事务参考sysbench的
#读写混合事务 只读+只写
#只读  14读 10主键查询(SELECT c FROM sbtest2 WHERE id=6627) 4范围查询(SELECT SUM(k) FROM sbtest1 WHERE id BETWEEN 10034 AND 10133)
#只写  4个写    2个update(UPDATE sbtest1 SET k=k+1 WHERE id=10097;  UPDATE sbtest8 SET c='04783700457-11022314443-11196051429-04609604999-93370579754-08599442436-08316839798-90681291724-45743712237-79562915805' WHERE id=6771)  1 delete(DELETE FROM sbtest10 WHERE id=10467) 1 insert(INSERT INTO sbtest10 (id, k, c, pad) VALUES (10467, 10091, '61444066182-81146431806-62522970475-40908356696-45863184087-57867749697-81994614843-47018332789-77464465313-16365474026', '09623299485-04250405371-67071095438-22681804144-49756379189'))


def main(HOST, PORT, USER, PASSWORD, DBNAME, ACTION, TABLE_BASE_NAME, TABLE_ROWS, TABLE_PER_COMMIT, TABLE_THREAD, NO_LOG, RUNTIME, REPORT_INTERVAL, TABLE_COUNT, MODE):
	#ACTION 动作, prepare准备数据  run运行 cleanup清除数据
	#TABLES_ROWS 每张表数据量  TABLE_COUNT表的数量  TABLE_BASE_NAME表名   TABLE_ROWS 表行数  TABLE_THREAD并行度
	#MODE 0 读写  1 仅读  2仅写

	#获取一个cursor
	cursor = get_cursor(HOST, PORT, USER, PASSWORD, DBNAME)

	if ACTION == "prepare":
		print("开始创建表...")
		for table_index in range(1, TABLE_COUNT+1):
			table_name = str(TABLE_BASE_NAME)+str(table_index)
			cursor.execute('''
  CREATE TABLE IF NOT EXISTS `{table_name}` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `k` int(11) NOT NULL DEFAULT '0',
  `c` char(120) NOT NULL DEFAULT '',
  `c2` char(60) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) /*! ENGINE = innodb */
/*!*/;
			'''.format(table_name=table_name))
			print("创建表 {DBNAME}.{table_name} 成功".format(DBNAME=DBNAME, table_name=table_name))
		cursor.execute("select count(*) from {DBNAME}.{table_name}".format(DBNAME=DBNAME, table_name=table_name))
		if int(cursor.fetchall()[0][0]) > 0:
			print("{DBNAME}.{table_name} 已存在数据, 请先清空, 或者换个名字".format(DBNAME=DBNAME, table_name=table_name))
			exit(1)

		#这里不加commit的话, 多进程最后一张表就无法创建索引..... 太坑了...
		cursor.execute("commit")
		print("开始插入数据")
		#进程间通信用队列, 队列有个BUG, 如果直接循环打印(不做其它任何操作,就是快速取值)的话, 可能取不了全部队列....
		q = Queue(TABLE_COUNT*2)
		#q = Manager().Queue(TABLE_COUNT)
		for i in range(1,TABLE_COUNT*2+1):
			q.put(i)
		thread_list={}
		for p in range(0,TABLE_THREAD):
			thread_list[p] = Process(target=insert_table, args=(HOST, PORT, USER, PASSWORD, DBNAME, ACTION, TABLE_BASE_NAME, TABLE_ROWS, TABLE_PER_COMMIT, TABLE_THREAD, NO_LOG, TABLE_COUNT, p, q), daemon=True)
		for p in range(0,TABLE_THREAD):
			thread_list[p].start()
		for p in range(0,TABLE_THREAD):
			thread_list[p].join()
		print("数据准备完成")
		cursor.close()
	elif ACTION == "run":
		print("开始压测.... 每隔{REPORT_INTERVAL} 秒显示一次".format(REPORT_INTERVAL=REPORT_INTERVAL))

		#放后台一直压测
		thread_list={}
		for p in range(0,TABLE_THREAD):
			thread_list[p] = Process(target=bench, args=(HOST, PORT, USER, PASSWORD, DBNAME, ACTION, TABLE_BASE_NAME, TABLE_ROWS, TABLE_PER_COMMIT, TABLE_THREAD, NO_LOG, TABLE_COUNT, p, MODE), daemon=True)
		for p in range(0,TABLE_THREAD):
			thread_list[p].start()

	
		#显示QPS TPS
		last_qcr = get_query_commit_rollback_mysql(cursor)
		last_query = last_qcr["query"]
		last_commit_rollback = last_qcr["commit_rollback"]
		time.sleep(REPORT_INTERVAL)
		for t in range(0, int(RUNTIME / REPORT_INTERVAL)):
			current_qcr = get_query_commit_rollback_mysql(cursor)
			current_query = current_qcr["query"]
			current_commit_rollback = current_qcr["commit_rollback"]
			print("[ {times} s ]  thds: {process}  tps: {tps}    qps: {qps}".format(tps = (current_commit_rollback - last_commit_rollback)/REPORT_INTERVAL, qps = (current_query - last_query)/REPORT_INTERVAL, process=TABLE_THREAD, times=(t+1)*REPORT_INTERVAL))
			time.sleep(REPORT_INTERVAL)
			last_query = current_query
			last_commit_rollback = current_commit_rollback
		print("压测完成")
		exit(0)
			
	elif ACTION == "cleanup":
		print("开始清理表")
		for table_index in range(1, TABLE_COUNT+1):
			table_name = str(TABLE_BASE_NAME)+str(table_index)
			cursor.execute("DROP TABLE IF EXISTS {table_name};".format(table_name=table_name))
			print("清除表 {table_name} 完成.".format(table_name=table_name))
		print("清理完成")
	else:
		print("不知道 ACTION , 仅支持 prepare|run|cleanup")

if __name__ == "__main__":
	#捕获ctrl+c
	def quit(signum,frame):
		print("被手动停止了..")
		sys.exit(2)

	signal.signal(signal.SIGINT,quit)

	#解析参数
	parser = _argparse()
	if parser.version :
		print("Version: {VERSION}".format(VERSION=VERSION))
	else:
		main(parser.host, parser.port, parser.user, parser.password, parser.dbname, parser.action,  parser.table_name, parser.table_rows, parser.insert_per_commit, parser.thread, parser.no_log, parser.runtime, parser.report_interval, parser.table_count, parser.mode)
