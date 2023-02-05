# -*- coding: utf-8 -*-
import paramiko
import pymysql
import base64
from multiprocessing import Process
from faker import Faker
import datetime,time
import random

class HostPortUP(object):
	def __init__(self,*args,**kwargs):
		#super().__init__(**kwargs) #object.__init__() takes no parameters
		self.host = kwargs["host"] if 'host' in kwargs else '0.0.0.0'
		self.port = kwargs["port"] if 'port' in kwargs else None
		self.user = kwargs["user"] if 'user' in kwargs else 'root'
		self.password = kwargs["password"] if 'password' in kwargs else None
		self.status = False #是否连接 只有连接成功, 才会改为True
		self.msg = '' #连接成功或者失败,或者其它报错都记录在这个属性上
		self._conn = None #连接

	def __str__(self):
		return f'Host:{self.host} Port:{self.port} User:{self.user} Password:{self.password} Status:{self.status}'

	def conn(self)->bool:
		pass

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

	def get_result_dict(self)->dict:
		pass

class ssh(HostPortUP):
	def __init__(self,*args,**kwargs):
		super().__init__(**kwargs) #继承HostPortUP的属性
		self.private_key = kwargs["private_key"] if 'private_key' in kwargs else None #自己的属性
		self.port = 22 if self.port is None else self.port #设置默认值

	def conn(self)->bool:
		pass

class ssh_sftp(ssh):
	#属性和ssh一样, 只需要重构conn,然后添加上传文件的功能即可
	def conn(self):
		pass
	
	def uploadfile(self,localfile,remote_dir='/tmp')->bool:
		pass


class mysql(HostPortUP):
	def __init__(self,*args,**kwargs):
		super().__init__(**kwargs)
		self.socket = kwargs["socket"] if 'socket' in kwargs else None
		self.database = kwargs["database"] if 'database' in kwargs else None
		self.port = 3306 if self.port is None else self.port #设置默认值

	def conn(self):
		pass

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
			#self.status = True
			return conn
		except Exception as e:
			self.msg = e
			return False


class oracle(HostPortUP):
	pass

class postgres(HostPortUP):
	pass

class costcpu:
	def __init__(self,n:int,action:int):
		"""
		n : 并发数
		action : 1:多进程, 2:多线程
		"""
		self.n = n
		self.action = action 
	def start(self):
		pass
	def stop(self):
		pass

def scanport(start=1024,end=65535,protocol=1)->list:
	"""
	start:起始端口
	end:结束端口
	protocol: 1:tcp 2:udp
	"""
	pass

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
			create_table_sql = f"""create table if not exists {tablename}(
id int,
name varchar(50),
birthday date,
addr varchar(100),
email varchar(100),
primary key(id)
)"""
			cursor.execute(create_table_sql)
			#cursor.fetchall()
			self.printinfo(f'{tablename} create success.')
		cursor.close()
		conn.close()
		insert_work = {}
		for x in range(1,self.tables+1):
			insert_work[x] = Process(target=self._prepare_insert,args=(x,))
		for x in range(1,self.tables+1):
			insert_work[x].start()
		for x in range(1,self.tables+1):
			insert_work[x].join()



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
			self.print('start read and write.')
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
					self.print(e)
					#time.sleep(1)
					pass #error+1 TODO
			conn.close()
		elif self.trx_type == 2:
			conn = self.get_conn()
			self.print('start read only.')
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
			self.print('start write only.')
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

class email(HostPortUP):
	pass

def testport(start=1024,end=65535,protocol=1)->bool:
	pass

def localcmd(cmd:str)->dict:
	pass

def read_yaml(filename:str)->dict:
	pass

def read_conf(filename:str):
	pass

def sendpack_tcp(host:str,port:int,bdata:bytes)->bool:
	pass

def getlog(filename:str,logformat):
	pass

def absfilename(filename:str)->str:
	"""返回文件的绝对路径"""
	pass

def dirfilename(filename:str)->str:
	"""返回文件的路径"""
	pass

def namefilename(filename:str)->str:
	"""返回文件名"""
	pass

def parse_binlog(binlog)->list:
	"""解析binlog"""

def encrypt(k,salt=None)->bytes:
	'''
	k: str, 需要加密的字符串
	salt: 盐
	'''
	return base64.b64encode(k.encode('utf-8'))


def decrypt(k,salt=None)->str:
	return base64.b64decode(k).decode('utf-8')
