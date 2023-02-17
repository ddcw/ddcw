# -*- coding: utf-8 -*-
import paramiko
import pymysql
import psycopg2 #pip install psycopg2-binary
import cx_Oracle
import base64
from multiprocessing import Process
from threading import Thread
from faker import Faker
import datetime,time
import random
import socket
import yaml
import subprocess
import logging
import os
import configparser

class HostPortUP(object):
	def __init__(self,*args,**kwargs):
		#super().__init__(**kwargs) #object.__init__() takes no parameters
		self.host = kwargs["host"] if 'host' in kwargs else '0.0.0.0'
		self.port = kwargs["port"] if 'port' in kwargs else None
		self.user = kwargs["user"] if 'user' in kwargs else 'root'
		self.password = kwargs["password"] if 'password' in kwargs else None
		self.status = False #上一个调用是否成功.
		self.msg = '' #连接成功或者失败,或者其它报错都记录在这个属性上
		self._conn = None #连接
		self.isconn = False #是否连接.

	def __str__(self):
		return f'Host:{self.host} Port:{self.port} User:{self.user} Password:{self.password} Status:{self.status}'

	def conn(self)->bool:
		conn = self.get_conn()
		if self.status:
			self._conn = conn
			self.isconn = True
			return True
		else:
			return False

	def close(self)->bool:
		try:
			self._conn.close()
			return True
		except Exception as e:
			self.status = False
			self.msg = e
			return False

	def test(self)->bool:
		#return True if self.get_conn else False
		conn = self.get_conn()
		if conn:
			conn.close()
			return True
		else:
			return False
		#pass

	def get_conn(self):
		pass

	def execute(self,command):
		pass

class _dbclass(HostPortUP):
	def __init__(self,*args,**kwargs):
		super().__init__(**kwargs) #object.__init__() takes no parameters

	def sql(self,sql)->tuple:
		"""
		必须先self.conn()
		"""
		if not self.isconn:
			return 'please conn() first'
		try:
			#self._conn.begin() #手动开启事务, 但是psycopg2没得begin...
			cursor = self._conn.cursor()
			cursor.execute(sql)
			data = cursor.fetchall()
			cursor.close()
			#self._conn.commit() #手动提交
			self.status = True
			return data
		except Exception as e:
			self._conn.rollback() #出错了就回滚
			self.msg = e
			self.status = False
			return tuple()

	def sql_dict(self,sql)->list:
		"""return like [{col1:value, col2:value,...},{col1:value, col2:value}]"""
		if not self.isconn:
			return 'please conn() first'
		try:
			cursor = self._conn.cursor()
			cursor.execute(sql)
			colname = [col[0] for col in cursor.description]
			data = [ dict(zip(colname,row)) for row in cursor.fetchall() ]
			cursor.close()
			self.status = True
			return data
		except Exception as e:
			self._conn.rollback()
			self.msg = e
			self.status = False
			return tuple()

	def execute(self,command):
		return self.sql(command)

class _shellcmd:
	def command(self,cmd)->tuple:
		pass

	def is_localip(self,ip='127.0.0.1')->bool:
		"""判断IP是否为本地IP"""
		if ip == '127.0.0.1' or ip == '0.0.0.0' or ip == '::1':
			return True
		else:
			data = self.command("""ip address | grep inet | awk '{print $2}' | awk -F '/' '{print $1}'""")
			if data[0] == 0:
				return True if ip in data[1] else False
			else:
				return False

	def is_online(self,ip)->bool:
		"""判断IP是否在线, 使用ping"""
		pass

	def cpu(self)->dict: 
		data = self.command('lscpu')
		if data[0] == 0:
			_data = {'status':True}
			for x in ('Architecture','Socket','Core','Thread','CPU MHz','BogoMIPS','vendor','Model name'):
				try:
					_data[x] = data[1].split(x)[1].split('\n')[0].split(':')[1].strip()
				except:
					pass
			return _data
		else:
			return {'status':False,'msg':data[2]}

	def mem(self)->dict:
		data = self.command('cat /proc/meminfo')
		if data[0] == 0:
			_data = {'status':True}
			for x in ('MemTotal','MemFree','MemAvailable','Buffers','Cached','SwapTotal','SwapFree','HugePages_Total','HugePages_Free','Shmem'):
				try:
					_data[x] = data[1].split(x)[1].split('\n')[0].split(':')[1].strip() #暂时不做单位换算
				except:
					pass
			return _data
		else:
			return {'status':False,'msg':data[2]}

	def disk(self)->dict:
		data = self.command('lsblk -d -o NAME,KNAME,SIZE,RO,STATE,ROTA,SCHED,UUID | tail -n +2')
		if data[0] == 0:
			_data = {'status':True}
			_data2 = []
			for x in data[1].split('\n'):
				_data2.append(x.split())
			_data['data'] = _data2
			return _data
		else:
			return {'status':False,'msg':data[2]}
	
	def fs(self,)->dict:
		data = self.command('df -PT --direct -k | tail -n +2')
		if data[0] == 0:
			_data = {'status':True}
			_data2 = []
			for x in data[1].split('\n'):
				_data2.append(x.split())
			_data['data'] = _data2
			return _data
		else:
			return {'status':False,'msg':data[2]}

	def get_proc_by_mem(self,n=10)->list:
		"""
		获取内存使用最多的n个进程信息(默认10) 注:VmRSS单位是KB
		参考:https://www.kernel.org/doc/html/latest/filesystems/proc.html
		"""
		data = self.command("""for procnum in /proc/[0-9]*; do Name=`awk '{ if ($1=="Name:") print $2}' ${procnum}/status`; VmRSS=`awk '{ if ($1=="VmRSS:") print $2}' ${procnum}/status`; Pid=`awk '{ if ($1=="Pid:") print $2}' ${procnum}/status`; PPid=`awk '{ if ($1=="PPid:") print $2}' ${procnum}/status`; State=`awk '{ if ($1=="State:") print $2}' ${procnum}/status`; if [ ${VmRSS} > 0 ];then echo "${Name} ${VmRSS} ${Pid} ${PPid} ${State}"; fi; done | sort -r -n -k 2 | head -"""+f"{n}")
		returndata = []
		if data[0] == 0:
			for x in data[1].split('\n'):
				Name,VmRSS,Pid,PPid,State = x.split()
				returndata.append({'Name':Name,'VmRSS':VmRSS,'Pid':Pid,'PPid':PPid,'State':State})
		return returndata

	def get_proc_by_cpu(self,n=10)->list:
		"""
		获取cpu使用时间最多的n个进程信息(默认10): utime + stime + cutime + cstime
		"""
		data = self.command("""for procnum in /proc/[0-9]*; do awk '{print $2,$1,$4,$3,$14+$15+$16+$17}' ${procnum}/stat; done | sort -r -n -k 5 | head -"""+f"{n}")
		returndata = []
		if data[0] == 0:
			for x in data[1].split('\n'):
				Name,Pid,PPid,State,Cputime = x.split()
				returndata.append({'Name':Name,'Pid':Pid,'PPid':PPid,'State':State,'Cputime':Cputime})
		return returndata

	def get_net_rate(self,):
		"""单位:字节  (Receive,Transmit)"""
		_cmd = """tail -n +3 /proc/net/dev | awk '{print $1,$2,$10}' | sed 's/://'"""
		net_rec_tra = {}
		for x in self.command(_cmd)[1].split('\n'):
			interface,receive,transmit = x.split()
			net_rec_tra[interface] = (int(receive),int(transmit))
		lasttime = time.time()
		time.sleep(0.1)
		while True:
			net_rate = {}
			data = self.command(_cmd)
			current_time = time.time()
			time_diff = current_time - lasttime
			lasttime = current_time
			for x in data[1].split('\n'):
				interface,receive,transmit = x.split()
				net_rate[interface] = (round((int(receive)-net_rec_tra[interface][0])/time_diff,2), round((int(transmit)-net_rec_tra[interface][1])/time_diff,2),)
				net_rec_tra[interface] = (int(receive),int(transmit))
			yield net_rate


class ssh(HostPortUP,_shellcmd):
	def __init__(self,*args,**kwargs):
		super().__init__(**kwargs) 
		self.private_key = kwargs["private_key"] if 'private_key' in kwargs else None #rsa,dsa都可以
		self.port = 22 if self.port is None else self.port 

	def command(self,cmd)->tuple: #(exit_code,strout,stderr)
		if not self.isconn:
			return 'please conn() first'
		try:
			ssh = self._conn
			stdin, stdout, stderr = ssh.exec_command(cmd)
			self.status = True
			return stdout.channel.recv_exit_status(),str(stdout.read().rstrip(),encoding="utf-8"),str(stderr.read().rstrip(),encoding="utf-8")
		except Exception as e:
			self.status = False
			self.msg = e
			return tuple()


	def execute(self,cmd):
		return self.command(cmd)
		

	def get_conn(self,):
		HOST = self.host
		SSH_PORT = self.port
		SSH_USER = self.user
		SSH_PASSWORD = self.password
		SSH_PKEY = self.private_key
		ssh = paramiko.SSHClient()
		ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
		if SSH_PKEY is None:
			try:
				ssh.connect(hostname=HOST, port=SSH_PORT, username=SSH_USER, password=SSH_PASSWORD, )
				self.isconn = True
				self.status = True
				return ssh
			except Exception as e:
				self.msg = e
				self.status = False
				return None
		else:
			try:
				ssh.connect(hostname=HOST, port=SSH_PORT, username=SSH_USER, password=SSH_PASSWORD, pkey=paramiko.RSAKey.from_private_key_file(SSH_PKEY))
				self.isconn = True
				self.status = True
				return ssh
			except:
				try:
					ssh.connect(hostname=HOST, port=SSH_PORT, username=SSH_USER, password=SSH_PASSWORD, pkey=paramiko.DSSKey.from_private_key_file(SSH_PKEY))
					self.isconn = True
					self.status = True
					return ssh
				except Exception as e:
					self.msg = e
					self.status = False
					return None
				
					

class sftp(ssh):
	def get_conn(self):
		try:
			tp = paramiko.Transport((self.host,int(self.port)))
			tp.connect(username=self.user, password=self.password)
			self.status = True
			self.isconn = True
			return tp
		except Exception as e:
			self.msg = msg
			self.status = False
		#sftp = paramiko.SFTPClient.from_transport(ts)
		#return sftp

	def put(self,localpath,remotepath,get=False)->bool:
		"""
		get : True 表示是下载.
		remotepath和localpath都是文件名(绝对路径), 我懒得去拼接路径了, 不然可以给个remotepath默认路径的
		"""
		if not self.isconn:
			self.msg = 'please conn() first'
			return False
		try:
			sftp = paramiko.SFTPClient.from_transport(self._conn)
			if get:
				sftp.get(remotepath,localpath)
			else:
				sftp.put(localpath,remotepath)
			sftp.close()
			self.status = True
		except Exception as e:
			self.msg = e
			self.status = False
		return self.status

	def get(self,remotepath,localpath)->bool:
		return self.put(localpath,remotepath,True)
		


class mysql(_dbclass):
	def __init__(self,*args,**kwargs):
		super().__init__(**kwargs)
		self.socket = kwargs["socket"] if 'socket' in kwargs else None
		self.database = kwargs["database"] if 'database' in kwargs else None
		self.port = 3306 if self.port is None else self.port #设置默认值

	def get_conn(self):
		try:
			conn = pymysql.connect(
			host=self.host,
			port=self.port,
			user=self.user,
			password=self.password,
			database=self.database,
			unix_socket = self.socket,
			)
			self.status = True
			return conn
		except Exception as e:
			self.status = False
			self.msg = e
			return False

	def _get_tps_qps_aux(self,conn)->tuple:
		cursor = conn.cursor()
		cursor.execute('show global status')
		data = cursor.fetchall()
		queries = 0
		commit_rollback = 0
		for x in data:
			if x[0] == 'Queries':
				queries = int(x[1])
			elif x[0] == 'Com_rollback':
				commit_rollback += int(x[1])
			elif x[0] == 'Com_commit':
				commit_rollback += int(x[1])
			else:
				continue

		cursor.close()
		return queries,commit_rollback

	def get_tps_qps(self):
		if not self.isconn:
			return 'please execute conn() first'
		queries,commit_rollback = self._get_tps_qps_aux(self._conn)
		date = time.time()
		time.sleep(0.1)
		while True:
			current_queries,current_commit_rollback = self._get_tps_qps_aux(self._conn)
			current_date = time.time()
			tps = round((current_commit_rollback-commit_rollback)/(current_date-date),2)
			qps = round((current_queries-queries)/(current_date-date),2)
			queries,commit_rollback,date = current_queries,current_commit_rollback,current_date
			yield tps,qps

	def get_max_tables(self,n=10)->tuple:
		"""
		获取最大的n(默认10)张表, 比较的是data_length字段, (不含系统库)
		"""
		sql = f"""SELECT TABLE_SCHEMA,TABLE_NAME,ENGINE,TABLE_ROWS,DATA_LENGTH,INDEX_LENGTH from INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA NOT IN ('sys','information_schema','mysql','performance_schema') ORDER BY DATA_LENGTH DESC LIMIT {n};"""
		return self.sql(sql)

	def get_max_dbs(self,n=10)->tuple:
		"""
		获取最大的(n)个库的信息
		"""
		sql = f"""select bb.*,aa.DEFAULT_CHARACTER_SET_NAME from information_schema.SCHEMATA as aa left join (select table_schema, sum(data_length) as data_length, sum(index_length) as index_length from information_schema.tables where TABLE_SCHEMA not in ('sys','mysql','information_schema','performance_schema') group by table_schema) as bb on aa.SCHEMA_NAME=bb.table_schema where bb.table_schema is not null order by bb.data_length desc limit {n};"""
		return self.sql(sql)

	def get_same_user_password(self)->tuple:
		"""
		返回用户名密码相同的用户. 仅mysql_native_password
		"""
		sql = """SELECT CONCAT(user, '@', host) as account FROM mysql.user where authentication_string = CONCAT('*', UPPER(SHA1(UNHEX(SHA1(user)))))"""
		return self.sql(sql)

	def get_sample_user_password(self,passwordlist=['123456','root','123','000000'])->tuple:
		sample_user = tuple()
		for password in passwordlist:
			sql = f"""SELECT CONCAT(user, '@', host) as account FROM mysql.user where authentication_string = CONCAT('*', UPPER(SHA1(UNHEX(SHA1('{password}')))))"""
			sample_user += self.sql(sql)
		return sample_user

	def get_nopk_table(self):
		"""获取没得主键的表"""
		sql = """SELECT aa.TABLE_SCHEMA, aa.TABLE_NAME FROM (SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE    TABLE_SCHEMA NOT IN ('sys','information_schema','mysql','performance_schema')) AS aa LEFT JOIN (SELECT TABLE_SCHEMA, TABLE_NAME FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE  CONSTRAINT_TYPE = 'PRIMARY KEY'   ) AS bb ON aa.TABLE_SCHEMA = bb.TABLE_SCHEMA    AND aa.TABLE_NAME = bb.TABLE_NAME WHERE bb.TABLE_NAME IS NULL;"""
		return self.sql(sql)

	def get_big_table(self,datasize=32212254720,rows=10000000):
		"""
		获取大表. datasize(32GB)和rows(10,000,000行)同时满足
		"""
		sql = f"""select TABLE_SCHEMA,TABLE_NAME,ENGINE,DATA_LENGTH,TABLE_ROWS from information_schema.tables where TABLE_ROWS > {rows} and DATA_LENGTH > {datasize}; """
		return self.sql(sql)

	def get_fragment_table(self,rate=40):
		"""碎片表,  rate碎片率, DATA_FREE/(DATA_LENGTH+DATA_FREE) """
		sql = f"""select * from (select TABLE_SCHEMA,TABLE_NAME,DATA_LENGTH,DATA_FREE,round(DATA_FREE/(DATA_LENGTH+DATA_FREE)*100,2) as fragment_rate from information_schema.tables where DATA_LENGTH>0 and TABLE_SCHEMA not in ('sys','information_schema','mysql','performance_schema')) as aa where aa.fragment_rate > {rate}; """
		return self.sql(sql)

class oracle(_dbclass):
	def __init__(self,*args,**kwargs):
		super().__init__(**kwargs)
		self.servicename = kwargs["servicename"] if 'servicename' in kwargs else None
		self.port = 1521 if self.port is None else self.port #设置默认值

	def get_conn(self,):
		try:
			dsn = cx_Oracle.makedsn(self.host, self.port, service_name=self.servicename)
			conn = cx_Oracle.connect(
			user=self.user,
			password=self.password,
			dsn=dsn,
			encoding="UTF-8",
			)
			self.status = True
			return conn
		except Exception as e:
			self.status = False
			self.msg = e
			return False

	def _get_tps_qps_aux(self,conn)->tuple:
		cursor = conn.cursor() #其实可以只查询一次的, 这里取值 name,value, 但是没得环境就懒得去整了...
		cursor.execute("select value from V$SYSSTAT where name = 'execute count'")
		user_query_count = int(list(cursor.fetchall())[0][0])
		cursor.execute("select value from V$SYSSTAT where name = 'user commits' ")
		user_commit_count = int(list(cursor.fetchall())[0][0])
		cursor.execute("select value from V$SYSSTAT where name = 'user rollbacks' ")
		user_rollback_count = int(list(cursor.fetchall())[0][0])
		cursor.close()
		return (user_query_count,user_commit_count+user_rollback_count)

class postgres(_dbclass):
	def __init__(self,*args,**kwargs):
		super().__init__(**kwargs)
		self.database = kwargs["database"] if 'database' in kwargs else 'postgres'
		#self.schema = kwargs["schema"] if 'schema' in kwargs else 'public'
		self.port = 5432 if self.port is None else self.port

	def sql(self,sql)->tuple:
		"""
		必须先self.conn()
		"""
		if not self.isconn:
			return 'please conn() first'
		try:
			cursor = self._conn.cursor()
			cursor.execute(sql)
			try:
				data = cursor.fetchall()
			except:
				data = tuple()
			cursor.close()
			self._conn.commit() #手动提交
			self.status = True
			return data
		except Exception as e:
			self._conn.rollback() #出错了就回滚
			self.msg = e
			self.status = False
			return tuple()

	def get_conn(self):
		try:
			conn = psycopg2.connect(
			host=self.host,
			port=self.port,
			user=self.user,
			password=self.password,
			database=self.database,
			)
			self.status = True
			return conn
		except Exception as e:
			self.status = False
			self.msg = e
			return False
	
	def _get_tps_qps_aux(self,conn):
		return 1,1 #benchmark_db未统计内部事务量和查询量, pg貌似也没得com_commit之类的统计. 所以就不显示tps,qps了



class costcpu:
	def __init__(self,n=1,action=1):
		"""
		n : 并发数
		action : 1:多进程, 2:多线程
		"""
		self._n = n
		self._action = action 
		self.pdict = {}
		for x in range(self._n):
			if self._action == 1:
				self.pdict[x] = Process(target=self.cost)
			else:
				self.pdict[x] = Thread(target=self.cost)
	def cost(self):
		while True:
			try:
				aa = random.random()*random.random()
			except:
				pass

	def start(self):
		for x in range(self._n):
			self.pdict[x].start()

	def stop(self):
		for x in range(self._n):
			self.pdict[x].terminate()

class costmem:
	def __init__(self,memsize=1*1024*1024):
		self.memsize = memsize
		self._data = ''
	def start(self):
		self._data = ' '*(self.memsize)

	def stop(self,):
		del self._data
		self._data = ''

	def clean(self):
		return self.stop()

class benchmark_db:
	def __init__(self,*args,**kwargs):
		"""
		parallel : 并行,默认4
		tables : 表数量
		rows : 每张表行数
		time : 运行时间, 默认120秒
		trx_type : 1:读写混合(默认), 2:只读  3:只写
		table_basename : 压测的表的基础名字, 默认ddcw_benchmark_xxx
		pipe : 压测结果实时反馈通道, None的话就走STDOUT
		report_interval : 压测结果反馈间隔, 默认10秒
		max_commit : 初始数据时, 每max_commit提交一次. 默认10000
		用法:
			self.prepare() 准备数据
			self.run() 开始压测
			self.cleanup() 清理数据
		"""
		super().__init__(**kwargs)
		self.parallel = kwargs['parallel'] if 'parallel' in kwargs else 4
		self.tables = kwargs['tables'] if 'tables' in kwargs else 12
		self.rows = kwargs['rows'] if 'rows' in kwargs else 100000
		self.time = kwargs['time'] if 'time' in kwargs else 120
		self.trx_type = kwargs['trx_type'] if 'trx_type' in kwargs else 1
		self.table_basename = kwargs['table_basename'] if 'table_basename' in kwargs else 'ddcw_benchmark_'
		self.pipe = kwargs['pipe'] if 'pipe' in kwargs else None
		self.report_interval = kwargs['report_interval'] if 'report_interval' in kwargs else 10
		self.max_commit = kwargs['max_commit'] if 'max_commit' in kwargs else 10000
		self.transactions = 0 #事务数
		self.querys = 0 #查询数量
		self.errors = 0 #错误数 可以使用信号量通知monitor进程..


	def printinfo(self,msg):
		#self.msg.append(msg)
		if self.pipe is None:
			print(msg)
		else:
			self.pipe.send(msg)

	def _prepare_insert(self,n):
		fake = Faker(locale='zh_CN') #中文
		conn = self.get_conn()
		cursor = conn.cursor()
		tablename = f'{self.table_basename}_{n}'
		commit_rows = 0
		for x in range(1,self.rows+1):
			sql = f'insert into {tablename} values(%s,%s,%s,%s,%s)'
			values = (x, fake.name(), fake.date_of_birth(minimum_age=18, maximum_age=65), fake.address(), fake.email(), )
			cursor.execute(sql, values)
			if commit_rows >= self.max_commit:
				conn.commit()
				commit_rows = 0
			else:
				commit_rows += 1
		cursor.close()
		conn.commit()
		cursor = conn.cursor()
		index_sql = f'create index {tablename}_email on {tablename}(email)'
		cursor.execute(index_sql)
		conn.commit()
		conn.close()
		self.printinfo(f'{tablename} table data insert completed.')


	def prepare(self,):
		#创建表结构, 插入数据, 创建索引
		conn = self.get_conn() #来自另一个class, 所以只继承这个类是不行的.
		cursor = conn.cursor()
		for x in range(1,self.tables+1):
			tablename = f'{self.table_basename}_{x}' #数据库名由mysql连接的时候指定的
			#oracle 不支持create table if not exists 所以继承过去之后要重写哈
			create_table_sql = f"""create table if not exists {tablename}(
id int,
name varchar(50),
birthday date,
addr varchar(100),
email varchar(100),
primary key(id)
)"""
			cursor.execute(create_table_sql)
			self.printinfo(f'{tablename} create success.')
		cursor.close()
		conn.commit() #pg要手动提交, 不然ddl未执行成功....
		conn.close()

		insert_work = {}
		for x in range(1,self.tables+1):
			insert_work[x] = Process(target=self._prepare_insert,args=(x,))
		for x in range(1,self.tables+1):
			insert_work[x].start()
		for x in range(1,self.tables+1):
			insert_work[x].join()




	def _monitor(self,):
		conn = self.get_conn()
		runtime = 0
		querys,commit_rollback = self._get_tps_qps_aux(conn)
		while runtime < self.time:
			time.sleep(self.report_interval)
			runtime += self.report_interval
			current_q,current_cr = self._get_tps_qps_aux(conn)
			qps = round((current_q-querys)/self.report_interval,2)
			tps = round((current_cr-commit_rollback)/self.report_interval,2)
			querys,commit_rollback = current_q,current_cr
			self.printinfo(f'{runtime}: qps:{qps} tps:{tps}')

	def benchmark(self):
		fake = Faker(locale='zh_CN')
		if self.trx_type == 1: #混合读写 10主键读, 4范围读, 2:update 1:delete 1:insert
			self.printinfo('start read and write.')
			conn = self.get_conn()
			while True:
				begintime = time.time()
				try:
					cursor = conn.cursor()
					tablename = f'{self.table_basename}_{random.randint(1,self.tables)}'
					for i in range(10):
						id_sql = f'select * from {tablename} where id=%s'
						cursor.execute(id_sql,(random.randint(1,self.rows),))
						#_data = cursor.fetchall()
					for j in range(4):
						range_sql = f'select * from {tablename} where id>=%s and id < %s'
						_id = random.randint(1,self.rows)
						cursor.execute(range_sql,(_id,_id+10))
						#_data = cursor.fetchall()
					update_sql1 = f'update {tablename} set email=%s where id=%s'
					cursor.execute(update_sql1,(fake.email(),random.randint(1,self.rows)))
					#_data = cursor.fetchall()
					update_sql2 = f'update {tablename} set name=%s where id=%s'
					cursor.execute(update_sql2,(fake.name(),random.randint(1,self.rows)))
					#_data = cursor.fetchall()
					delete_id = random.randint(1,self.rows)
					delete_sql = f'delete from {tablename} where id=%s'
					cursor.execute(delete_sql,(delete_id,))
					insert_sql = f'insert into {tablename} values(%s,%s,%s,%s,%s)'
					values = (delete_id, fake.name(), fake.date_of_birth(minimum_age=18, maximum_age=65), fake.address(), fake.email(), )
					cursor.execute(insert_sql,values)
					#_data = cursor.fetchall()
					conn.commit()
					cursor.close()
				except Exception as e:
					self.printinfo(e)
					#time.sleep(1)
					pass #error+1 TODO
			conn.close()
		elif self.trx_type == 2:
			conn = self.get_conn()
			self.printinfo('start read only.')
			while True:
				try:
					cursor = conn.cursor()
					tablename = f'{self.table_basename}_{random.randint(1,self.tables)}'
					for i in range(10):
						id_sql = f'select * from {tablename} where id=%s'
						cursor.execute(id_sql,(random.randint(1,self.rows),))
						#_data = cursor.fetchall()
					for j in range(4):
						range_sql = f'select * from {tablename} where id>=%s and id < %s'
						_id = random.randint(1,self.rows)
						cursor.execute(range_sql,(_id,_id+10))
						#_data = cursor.fetchall()
					cursor.close()
					conn.commit()
				except Exception as e:
					pass #error+1 TODO
			conn.close()
		elif self.trx_type == 3:
			conn = self.get_conn()
			self.printinfo('start write only.')
			while True:
				try:
					cursor = conn.cursor()
					tablename = f'{self.table_basename}_{random.randint(1,self.tables)}'
					update_sql1 = f'update {tablename} set email=%s where id=%s'
					cursor.execute(update_sql1,(fake.email(),random.randint(1,self.rows)))
					_data = cursor.fetchall()
					update_sql2 = f'update {tablename} set name=%s where id=%s'
					cursor.execute(update_sql2,(fake.name(),random.randint(1,self.rows)))
					_data = cursor.fetchall()
					delete_id = random.randint(1,self.rows)
					delete_sql = f'delete from {tablename} where id=%s'
					cursor.execute(delete_sql,(delete_id,))
					insert_sql = f'insert into {tablename} values(%s,%s,%s,%s,%s)'
					values = (delete_id, fake.name(), fake.date_of_birth(minimum_age=18, maximum_age=65), fake.address(), fake.email(), )
					cursor.execute(insert_sql,values)
					_data = cursor.fetchall()
					conn.commit()
					cursor.close()
				except Exception as e:
					self.printinfo(e)
					pass #error+1 TODO
			conn.close()
				
		else:
			return


	def run(self):
		if not hasattr(self,'servicename') and self.database is None :
			return 'database is None'
		self.msg = [] #清空
		#parallel:压测  还有个进程负责监控
		P_monitor = Process(target=self._monitor,)
		P_monitor.start()
		#获取多个连接
		P_work = {}
		for x in range(self.parallel):
			P_work[x] = Process(target=self.benchmark,)
		for x in range(self.parallel):
			P_work[x].start()
		P_monitor.join()
		for x in range(self.parallel):
			P_work[x].terminate()

	def cleanup(self):
		"""
		清理数据
		"""
		conn = self.get_conn() 
		cursor = conn.cursor()
		for x in range(1,self.tables+1):
			tablename = f'{self.table_basename}_{x}' #数据库名由mysql连接的时候指定的
			delete_table_sql = f"""drop table if exists {tablename}"""
			cursor.execute(delete_table_sql)
			_data = cursor.fetchall()
		conn.commit()
		cursor.close()
		conn.close()
		self.printinfo('clean table success.')


class benchmark_mysql(benchmark_db,mysql):
	def __init__(self,*args,**kwargs):
		#benchmark_db.__init__(self)
		#mysql.__init__(self)
		super().__init__(**kwargs)

class benchmark_postgres(benchmark_db,postgres):
	def __init__(self,*args,**kwargs):
		super().__init__(**kwargs)

class benchmark_oracle(benchmark_db,oracle):
	def __init__(self,*args,**kwargs):
		super().__init__(**kwargs)

	def _prepare_insert(self,n):
		fake = Faker(locale='zh_CN') #中文
		conn = self.get_conn()
		cursor = conn.cursor()
		tablename = f'{self.table_basename}_{n}'
		commit_rows = 0
		for x in range(1,self.rows+1):
			sql = f'insert into {tablename} values(:1,:2,:3,:4,:5)'
			values = (x, fake.name(), fake.date_of_birth(minimum_age=18, maximum_age=65), fake.address(), fake.email(), )
			cursor.execute(sql, values)
			if commit_rows >= self.max_commit:
				conn.commit()
				commit_rows = 0
			else:
				commit_rows += 1
		cursor.close()
		conn.commit()
		cursor = conn.cursor()
		index_sql = f'create index {tablename}_email on {tablename}(email)'
		cursor.execute(index_sql)
		conn.commit()
		conn.close()
		self.printinfo(f'{tablename} table data insert completed.')
	def prepare(self,):
		conn = self.get_conn() 
		cursor = conn.cursor()
		for x in range(1,self.tables+1):
			tablename = f'{self.table_basename}_{x}'
			#oracle 不支持if not exists
			create_table_sql = f"""create table {tablename}(
id int,
name varchar2(50),
birthday date,
addr varchar2(100),
email varchar2(100),
primary key(id)
)"""
			try:
				cursor.execute(create_table_sql)
				self.printinfo(f'{tablename} create success.')
			except Exception as e:
				self.printinfo(f'{tablename} create faild. maybe exists. ERROR:{e}')
		cursor.close()
		conn.commit() #pg要手动提交, 不然ddl未执行成功....
		conn.close()

		insert_work = {}
		for x in range(1,self.tables+1):
			insert_work[x] = Process(target=self._prepare_insert,args=(x,))
		for x in range(1,self.tables+1):
			insert_work[x].start()
		for x in range(1,self.tables+1):
			insert_work[x].join()

	def benchmark(self):
		fake = Faker(locale='zh_CN')
		if self.trx_type == 1: #混合读写 10主键读, 4范围读, 2:update 1:delete 1:insert
			self.printinfo('start read and write.')
			conn = self.get_conn()
			while True:
				begintime = time.time()
				try:
					cursor = conn.cursor()
					tablename = f'{self.table_basename}_{random.randint(1,self.tables)}'
					for i in range(10):
						id_sql = f'select * from {tablename} where id=:1'
						cursor.execute(id_sql,(random.randint(1,self.rows),))
						#_data = cursor.fetchall()
					for j in range(4):
						range_sql = f'select * from {tablename} where id>=:1 and id < :2'
						_id = random.randint(1,self.rows)
						cursor.execute(range_sql,(_id,_id+10))
						#_data = cursor.fetchall()
					update_sql1 = f'update {tablename} set email=:1 where id=:2'
					cursor.execute(update_sql1,(fake.email(),random.randint(1,self.rows)))
					#_data = cursor.fetchall()
					update_sql2 = f'update {tablename} set name=:1 where id=:2'
					cursor.execute(update_sql2,(fake.name(),random.randint(1,self.rows)))
					#_data = cursor.fetchall()
					delete_id = random.randint(1,self.rows)
					delete_sql = f'delete from {tablename} where id=:1'
					cursor.execute(delete_sql,(delete_id,))
					insert_sql = f'insert into {tablename} values(:1,:2,:3,:4,:5)'
					values = (delete_id, fake.name(), fake.date_of_birth(minimum_age=18, maximum_age=65), fake.address(), fake.email(), )
					cursor.execute(insert_sql,values)
					#_data = cursor.fetchall()
					conn.commit()
					cursor.close()
				except Exception as e:
					self.printinfo(e)
					#time.sleep(1)
					pass #error+1 TODO
			conn.close()
		elif self.trx_type == 2:
			conn = self.get_conn()
			self.printinfo('start read only.')
			while True:
				try:
					cursor = conn.cursor()
					tablename = f'{self.table_basename}_{random.randint(1,self.tables)}'
					for i in range(10):
						id_sql = f'select * from {tablename} where id=:1'
						cursor.execute(id_sql,(random.randint(1,self.rows),))
						#_data = cursor.fetchall()
					for j in range(4):
						range_sql = f'select * from {tablename} where id>=:1 and id < :2'
						_id = random.randint(1,self.rows)
						cursor.execute(range_sql,(_id,_id+10))
						#_data = cursor.fetchall()
					cursor.close()
					conn.commit()
				except Exception as e:
					pass #error+1 TODO
			conn.close()
		elif self.trx_type == 3:
			conn = self.get_conn()
			self.printinfo('start write only.')
			while True:
				try:
					cursor = conn.cursor()
					tablename = f'{self.table_basename}_{random.randint(1,self.tables)}'
					update_sql1 = f'update {tablename} set email=:1 where id=:2'
					cursor.execute(update_sql1,(fake.email(),random.randint(1,self.rows)))
					_data = cursor.fetchall()
					update_sql2 = f'update {tablename} set name=:1 where id=:2'
					cursor.execute(update_sql2,(fake.name(),random.randint(1,self.rows)))
					_data = cursor.fetchall()
					delete_id = random.randint(1,self.rows)
					delete_sql = f'delete from {tablename} where id=:1'
					cursor.execute(delete_sql,(delete_id,))
					insert_sql = f'insert into {tablename} values(:1,:2,:3,:4,:5)'
					values = (delete_id, fake.name(), fake.date_of_birth(minimum_age=18, maximum_age=65), fake.address(), fake.email(), )
					cursor.execute(insert_sql,values)
					_data = cursor.fetchall()
					conn.commit()
					cursor.close()
				except Exception as e:
					self.printinfo(e)
					pass #error+1 TODO
			conn.close()
				
		else:
			return
	def cleanup(self):
		"""
		清理数据
		"""
		conn = self.get_conn() 
		cursor = conn.cursor()
		for x in range(1,self.tables+1):
			tablename = f'{self.table_basename}_{x}' #数据库名由mysql连接的时候指定的
			delete_table_sql = f"""drop table {tablename}"""
			try:
				cursor.execute(delete_table_sql)
				_data = cursor.fetchall()
			except:
				pass
		conn.commit()
		cursor.close()
		conn.close()
		self.printinfo('clean table success.')

class email(HostPortUP):
	pass #TODO

def read_yaml(filename:str)->dict:
	with open(filename, 'r', encoding="utf-8") as f:
		inf_data =  f.read()
	conf = yaml.load(inf_data,Loader=yaml.Loader)
	return conf

def save_yaml(filename:str,data:dict)->bool:
	try:
		with open(filename,'w',encoding='utf-8') as f:
			yaml.dump(data=data,stream=f,)
		return True
	except Exception as e:
		print(e)
		return False
		

def read_conf(filename:str)->dict:
	_config = configparser.ConfigParser()
	_config.read(filename)
	data = {}
	for x in _config._sections:
		data[x] = dict(_config._sections[x])
	return data

def save_conf(filename:str,config:dict)->bool:
	"""没做异常处理"""
	parser = configparser.ConfigParser()
	parser.read_dict(config)
	with open(filename, 'w') as configfile:
		parser.write(configfile)
	return True

def sendpack_tcp(host:str,port:int,bdata:bytes)->bool:
	"""发送二进制数据到目标服务器, 不接受回包."""
	return_status = False
	try:
		conn = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		conn.connect((host,port))
		if conn.send(bdata) == len(bdata):
			return_status = True
		conn.close()
		return return_status
	except:
		return False

def getlog(filename='/tmp/.testbyddcw.log',logformat='%(asctime)s %(levelname)s %(message)s'):
	logging.basicConfig(level=logging.INFO,format=logformat,filename=filename)
	log = logging.getLogger('ddcwlog')
	return log

def file_abs(filename:str)->str:
	"""返回文件的绝对路径"""
	return os.path.abspath(filename)

def file_dir(filename:str)->str:
	"""返回文件的路径"""
	return os.path.dirname(filename)

def file_name(filename:str)->str:
	"""返回文件名"""
	return os.path.basename(filename)

def parse_binlog(binlog)->list:
	"""解析binlog. 这是要干嘛呢... 我忘了, 后面想起来了再实现吧.... -_-"""
	pass

def encrypt(k,salt=None)->bytes:
	'''
	k: str, 需要加密的字符串
	salt: 盐
	'''
	return base64.b64encode(k.encode('utf-8'))


def decrypt(k,salt=None)->str:
	return base64.b64decode(k).decode('utf-8')

def scanport(host='0.0.0.0',start=None,end=None,)->list:
	"""
	host:默认0.0.0.0
	start:起始端口
	end:结束端口, 不指定就只扫描start的那个端口
	扫描目标主机的tcp端口,返回能正常建立连接的tcp端口(list)
	用法例子: 
		scanport() 扫描本机所有tcp端口
		scanport(host='192.168.101.21') 扫描192.168.101.21的所有tcp端口
		ddcw_tool.scanport(host='192.168.101.21',start=1,end=22)  扫描指定主机的指定范围的端口
		ddcw_tool.scanport(host='192.168.101.21',start=22) 扫描指定主机的指定端口
	"""
	success_port = []
	if start is None  or (start is None and end is None):
		start,end = 1,65535
	elif end is None:
		end = start
	else:
		pass

	family = socket.AF_INET
	try:
		_tmp = socket.inet_aton(host) #利用inet_aton不支持ipv6来判断是否为ipv4, 但是并没有使用inet_pton判断是否为ip地址(懒)
	except:
		family = socket.AF_INET6
		
	for x in range(start,end+1):
		try:
			conn = socket.socket(family, socket.SOCK_STREAM)
			conn.connect((host,x))
			conn.close()
			success_port.append(x)
		except:
			pass
	return success_port

class remote_yaml(sftp):
	def __init__(self,*args,**kwargs):
		"""
		远程修改yaml, 通过ssh把远程服务器上的yaml下载到本地, 修改完成后,再上传回去
		self.open()  连接ssh,并下载文件到本地
		self.save()  保存在本地, 然后上传到远端服务器上.
		self.data    就是yaml文件内容, type:dict
		self.close() 断开ssh连接.(不保存...)
		"""
		super().__init__(**kwargs) 
		self.remote_file = kwargs['remote_file'] if 'remote_file' in kwargs else None
		self.localfilename = f'/tmp/.testfile_{time.time()}'
		self.data = dict()

	def open(self):
		if self.remote_file is None:
			return 'please set remote_file first'
		if self.conn():
			self.get(self.remote_file,self.localfilename)
			self.data = read_yaml(self.localfilename)
		else:
			return False

	def save(self):
		if self.remote_file is None:
			return 'please set remote_file first'
		if save_yaml(self.localfilename,self.data):
			self.put(self.localfilename,self.remote_file)
			return True
		else:
			return False

class localcmd(_shellcmd):
	def __init__(self,*args,**kwargs):
		#super().__init__(**kwargs) 
		self.timeout = kwargs['timeout'] if 'timeout' in kwargs else 1200

	def command(self,cmd)->tuple: #(exit_code,strout,stderr)
		with subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as f:
			try:
				return f.wait(self.timeout),str(f.stdout.read().rstrip(),encoding="utf-8"),str(f.stderr.read().rstrip(),encoding="utf-8")
			except Exception as e:
				f.kill()
				return -1,e,str(f.stderr.read().rstrip(),encoding="utf-8")



def get(url):
	pass

def post(url,data):
	pass

def tcpdump(interface=None,rule=None):
	pass

class mysql_ms:
	def __init__(self,*args,**kwargs):
		"""
		输入n个mysql数据库信息,可以是 ddcw_tool.mysql对象, 也可以是(host,port,username,password)的元组形式
		若只给了一个mysql从库信息, 当self.auto_conn = True(默认)的时候, 会自动获取主库信息,但获取不了其它从库信息(找不到端口)
		只支持1主N从. 不支持多主/主主
		"""
		db_info = {}
		for x in args:
			if isinstance(x,mysql):
				name = f'{x.host}_{x.port}'
				db_info[name] = {'host':x.host,'port':x.port,'user':x.user,'password':x.password}
			elif isinstance(x,tuple):
				name = f'{x[0]}_{x[1]}'
				db_info[name] = {'host':x[0],'port':x[1],'user':x[2],'password':x[3]}
			else:
				pass
		self._db_base_info = db_info
		self._reset_slave = False #默认不执行reset slave
		self._set_read_only = False #默认不手动设置从库只读
		self.master = tuple()
		self.slave = tuple()
		self.__conn__ = dict() #数据库连接信息
		self.msg = ''
		self.status = False
		self.auto_conn = True #True:自动连接相关的其它节点,并参加选主.  False不连接,也不参与选主
		self._ignore_master = tuple() #((host,port),(host,port)) 这些主库将不被计算在主库数量上. 主库只能有一个
		self.wait = 3 #默认等待3秒事务完成,然后就kill
		self.user = None #用于主从复制的账号, 为空的时候, self._update会自动更新
		self.password = None #用于主从复制的密码
	
	def conn(self)->bool:
		"""连接到mysql, 并获取主从相关信息"""
		new_db_info = {}
		_db_base_info = self._db_base_info
		for name in _db_base_info:
			_tmp_mysql = mysql(host=_db_base_info[name]['host'],port=_db_base_info[name]['port'],user=_db_base_info[name]['user'],password=_db_base_info[name]['password'])
			if _tmp_mysql.conn():
				self.__conn__[name] = _tmp_mysql
				for master in _tmp_mysql.sql('select Host,Port,User_name,User_password,Channel_name,Uuid from mysql.slave_master_info where port !=0;'):
					_name = f'{master[0]}_{master[1]}'
					if _name not in self._db_base_info:
						new_db_info[_name] = master
					self.user = master[2] if self.user is None else self.user
					self.password = master[3] if self.password is None else self.password
				#select HOST,USER from information_schema.processlist where COMMAND = 'Binlog Dump'; #看不到从库的db端口.就不看了
			else:
				self.status = False
				self.msg = _tmp_mysql.msg
				return self.status
		if self.auto_conn:
			for name in new_db_info:
				_tmp_mysql = mysql(host=new_db_info[name][0],port=new_db_info[name][1],user=new_db_info[name][2],password=new_db_info[name][3])
				if _tmp_mysql.conn():
					self.__conn__[name] = _tmp_mysql
				else:
					pass
		return self._update()

	def _update(self)->bool:
		"""更新self.master and self.slave"""
		#找到主库, 最多只能有一个主库
		for name in self.__conn__:
			for master in self.__conn__[name].sql('select Host,Port,User_name,User_password,Channel_name,Uuid from mysql.slave_master_info where port !=0;'):
				if (master[0],master[1]) not in self._ignore_master and (master[0],master[1]) not in self.master:
					self.master += ((master[0],master[1]),)

		if len(self.master) > 1:
			self.status = False
			self.msg = f'there have more than 1 master. {self.master}'
			return self.status

		#找到从库
		self.slave = tuple() #先清空信息
		for name in self.__conn__:
			_db_base_info = self._db_base_info
			for slave in _db_base_info:
				host,port = _db_base_info[slave]['host'],_db_base_info[slave]['port']
				if (host,port) not in self.master and (host,port) not in self.slave:
					self.slave += ((host,port),)

		#验证复制账号是否能登录. 
		#算了, 不验证了, 有可能限制了IP的....

		self.status = True
		return self.status


	def get_delay(self,obj=[]):
		data = self.slave_detail(obj)
		return [(x['host'],x['port'],x['slave_status']['Seconds_Behind_Master']) for x in data ]

	def get_delay_gtid(self,obj=[]):
		"""返回主从之间相差的gtid数"""
		master_name = f'{self.master[0][0]}_{self.master[0][1]}'
		server_uuid = self.master_detail()['uuid']
		obj = self.slave if len(obj) == 0 else obj
		slave_list = []
		for slave in obj:
			name = f'{slave[0]}_{slave[1]}'
			gtid_executed = self.__conn__[name].sql('select @@GLOBAL.gtid_executed;')[0][0]
			slave_gtid_executed = [ x.split(',')[0] for x in gtid_executed.split() if x.split(':')[0]==server_uuid ][0]
			master_gtid_executed = self.__conn__[master_name].sql('select @@GLOBAL.gtid_executed;')[0][0]
			master_gtid_executed = [ x.split(',')[0] for x in master_gtid_executed.split() if x.split(':')[0]==server_uuid ][0]
			sql = f"select GTID_SUBTRACT('{master_gtid_executed}','{slave_gtid_executed}')"
			gtid = self.__conn__[name].sql(sql)[0][0]
			slave_list.append({'host':slave[0],'port':slave[1],'gtid_diff':gtid,'master_gtid':master_gtid_executed,'slave_gtid':slave_gtid_executed})
		return slave_list

	def get_status(self,obj=[])->tuple:
		data = self.slave_detail(obj)
		return [(x['host'],x['port'],x['slave_status']['Slave_IO_Running'],x['slave_status']['Slave_SQL_Running'],x['slave_status']['Auto_Position']) for x in data ]

	def get(self):
		return {'master':self.master,'slave':self.slave}

	def master_detail(self)->dict:
		master_name = f'{self.master[0][0]}_{self.master[0][1]}'
		slave_conn = self.__conn__[master_name].sql("select HOST,USER,STATE from information_schema.processlist where COMMAND = 'Binlog Dump';")
		uuid = self.__conn__[master_name].sql('select @@server_uuid;')[0][0]
		version = self.__conn__[master_name].sql('select @@version;')[0][0]
		return {'host':self.master[0][0], 'port':self.master[0][1], 'slave_conn':slave_conn, 'uuid':uuid, 'version':version }

	def slave_detail(self,obj=[])->list:
		""" 
		obj:[(host,port),(host,port)]指定的从库信息, 默认空, 表示取所有
		注: Seconds_Behind_Master可能不准, 甚至有可能为负数,这跟它的计算方式有关.
		"""
		obj = self.slave if len(obj) == 0 else obj
		slaveinfo = []
		for slave in obj:
			name = f'{slave[0]}_{slave[1]}'
			#print(name)
			uuid = self.__conn__[name].sql('select @@server_uuid;')[0][0]
			version = self.__conn__[name].sql('select @@version;')[0][0]
			_slave_info = self.__conn__[name].sql_dict('show slave status') #可能与多个主从的信息
			_slave_info = [ x for x in _slave_info if (x['Master_Host'],x['Master_Port']) in self.master ] #只要和self.master相关的
			if len(_slave_info) > 0:
				slaveinfo.append({'host':slave[0], 'port':slave[1], 'version':version, 'uuid':uuid, 'slave_status':_slave_info[0]})
		return slaveinfo

	def _clean_to_gtid(self,gtid_execute)->int:
		return int(gtid_execute.split(':')[-1].split('-')[-1])
				
	
	def switch(self,master=None)->bool:
		"""
		master=(host,port)  若为None, 则自动选择
		切换流程:
		1. 主库设置为只读,等待当前事务提交完成(默认3秒), kill所有连接(不含system user),包含ddcw_tool.mysql的, 所以要记得重连哈
		2. 选择新主(只有1个就不选了), 等待新主执行完relay log, 然后记录master status
		3. 校验数据(可选),这里就不做了, 也可以参考我之前写的数据校验脚本
		4. 新主:stop slave; reset slave all(可选); set global read_only=ON;
		5. 关闭旧主库shutdown(可选), 这里就不做了.
		6. 等待其它从库完成relay log, 然后change master到新主库.(均不使用channel)
		7. self._update
		"""
		if master not in self.slave and master is not None:
			self.status = False
			self.msg = f'{master} not in {self.slave}'
			return self.status

		if len(self.slave) == 1:
			master = self.slave
		elif len(self.slave) == 0:
			self.status = False
			self.msg = f'no slave to switch to master'
			return self.status
		else:
			pass
		old_master = self.master
		print(f'master:{self.master[0]} before switch.')
		print('stop old master')
		self._stop_master()
		print('choose master if not exists.')
		master = self._chosen_one() if master is None else master
		print('wait new master to complete relay log',master)
		new_master_info = self._wait_new_master(master)
		print('check data')
		self._checkdata(new_master_info[2])
		print('new master set read write')
		self._new_master_set(master)
		print('set slave to new master')
		change_master = f"""CHANGE MASTER TO MASTER_HOST='{master[0][0]}',MASTER_PORT={master[0][1]},MASTER_USER='{self.user}',MASTER_PASSWORD='{self.password}',master_log_file='{new_master_info[0]}',master_log_pos={new_master_info[1]};"""
		self._change_new_master(change_master)
		print('set old master to new master')
		self._old_master_to_slave(change_master,old_master)
		self._update()
		print(f'master:{self.master[0]} after switch.')

	def _stop_master(self)->bool:
		"""停主"""
		master_name = f'{self.master[0][0]}_{self.master[0][1]}'
		self.__conn__[master_name].sql('set global read_only=ON;')
		self.__conn__[master_name].sql('set global super_read_only=ON;') 
		self.__conn__[master_name].sql('stop slave;')
		self.__conn__[master_name].sql('reset slave all;') #重置主从状态 
		#self.__conn__[master_name].sql('flush tables with read lock;')  #若这里加了的话, 切换完成后记得 unlcok tables;
		time.sleep(self.wait)
		this_mid = self.__conn__[master_name].sql('select connection_id();')[0][0]
		#获取普通连接的id, 并kill掉
		for mid in self.__conn__[master_name].sql("select id from information_schema.processlist where User != 'system user';"):
			if mid[0] != this_mid: #我不kill自己的id 这样就不用重连了.
				#print(f'{this_mid}: kill {mid}')
				kill_sql = f'kill {mid[0]};'
				self.__conn__[master_name].sql(kill_sql)
		return True

	def _chosen_one(self)->tuple:
		"""
		选主 return tuple
		比较来自server的gtid呢, 还是比较Seconds_Behind_Master呢
		-- select @@GLOBAL.gtid_executed;
		"""
		#还是用gtid吧, 可以执行空gtid来跳过之前没有的信息, 这里不返回gtid信息和binlog信息. 由self.switch去获取,因为可能是手动设置的新主库
		max_gtid = 0
		name = tuple()
		for x in self.get_delay_gtid():
			#_gtid = int(x['slave_gtid'].split(':')[-1].split('-')[-1])
			_gtid = self._clean_to_gtid(x['slave_gtid'])
			if _gtid > max_gtid:
				max_gtid = _gtid
				name = (x['host'],x['port'])
		return name

	def _wait_new_master(self,new_master):
		"""等待新主跑完relay log 然后返回master info 和gtid信息"""
		while True:
			sql_thread = self.slave_detail(new_master)[0]['slave_status']['Slave_SQL_Running_State']
			if sql_thread == 'Slave has read all relay log; waiting for more updates':
				break
			else:
				time.sleep(1)
		new_master_name = f"{new_master[0][0]}_{new_master[0][1]}"
		data = self.__conn__[new_master_name].sql_dict('show master status;')[0]
		new_master_uuid = uuid = self.__conn__[new_master_name].sql('select @@server_uuid;')[0][0]
		gtid_executed = [ x.split(',')[0] for x in data['Executed_Gtid_Set'].split() if x.split(':')[0]==new_master_uuid ][0]
		return (data['File'],data['Position'],self._clean_to_gtid(gtid_executed))

	def _checkdata(self,new_master_gtid):
		"""主从数据校验, 校验旧主和新主数据是否一直. 这里就不校验了. 比较下最大的gtid信息即可. 不一致就返回False"""
		master_name = f'{self.master[0][0]}_{self.master[0][1]}'
		server_uuid = self.master_detail()['uuid']
		master_gtid_executed = self.__conn__[master_name].sql('select @@GLOBAL.gtid_executed;')[0][0]
		master_gtid_executed = [ x.split(',')[0] for x in master_gtid_executed.split() if x.split(':')[0]==server_uuid ][0]
		old_master_gtid = self._clean_to_gtid(master_gtid_executed)
		return True if new_master_gtid == old_master_gtid else False

	def _new_master_set(self,new_master):
		"""新主库设置, read_only=OFF,  self.master=xxx slave信息后面再更新"""
		master_name = f'{new_master[0][0]}_{new_master[0][1]}'
		self.__conn__[master_name].sql('stop slave;') #先停主从
		self.__conn__[master_name].sql('reset slave all;') #先停主从
		self.__conn__[master_name].sql('set global read_only = OFF;')
		self.__conn__[master_name].sql('set global super_read_only = OFF;')
		self._old_master = self.master #旧的先保存下来, 后面要用
		self.master = tuple(new_master,)
		return True

	def _change_new_master(self,change_master):
		"""等待其它从库执行完relay log然后 change master to new master. 使用gtid的话, 先set gtid_next=xxx begin;commit;"""
		timeout = 60
		n = 0
		_tmp_slave = list(self.slave)
		_tmp_slave.remove(self.master[0]) 
		while n <= timeout:
			if len(_tmp_slave) == 0:
				break
			for x in _tmp_slave[:]:
				name = f'{x[0]}_{x[1]}'
				slave_dict = self.__conn__[name].sql_dict('show slave status')
				for y in slave_dict:
					if y['Master_Host'] == self._old_master[0][0] and y['Master_Port'] == self._old_master[0][1] and y['Slave_SQL_Running_State'] == 'Slave has read all relay log; waiting for more updates':
						self.__conn__[name].sql('stop slave;')
						self.__conn__[name].sql(change_master)
						self.__conn__[name].sql('start slave;')
						_tmp_slave.remove(x)
						print(x,'complete')
			time.sleep(1)
			n += 1

	def _vip_change(self):
		"""切换VIP. 自己取整. """
		pass

	def _old_master_to_slave(self,change_master,old_master):
		"""在旧主库上, unlock tables. change master to 这步执行完了, 上层调用记得self._update下"""
		name = f"{old_master[0][0]}_{old_master[0][1]}"
		self.__conn__[name].sql('unlock tables')
		self.__conn__[name].sql('stop slave')
		self.__conn__[name].sql(change_master)
		#print(change_master,name)
		self.__conn__[name].sql('start slave')
		return True

	
	def close(self)->bool:
		self.msg = []
		self.status = True
		for x in self.__conn__:
			try:
				self.__conn__[x].close()
			except Exception as e:
				self.status = False
				self.msg.append(e)
		return self.status
