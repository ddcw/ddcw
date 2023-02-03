# -*- coding: utf-8 -*-
import paramiko
import pymysql
import socket

class HostPortUP:
	def __init__(self,*args,**kwargs):
		self.host = kwargs["host"] if 'host' in kwargs else '0.0.0.0'
		self.port = kwargs["port"] if 'port' in kwargs else None
		self.user = kwargs["user"] if 'user' in kwargs else 'root'
		self.password = kwargs["password"] if 'password' in kwargs else None
		self.status = False #是否连接 只有连接成功, 才会改为True
		self.msg = '' #连接成功或者失败,或者其它报错都记录在这个属性上
		self._conn = None #连接
		#super().__init__(**kwargs)

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
		pass

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

def random(start=0,end=1):
	"""return random number between start and end"""
	pass

def scanport(start=1024,end=65535,protocol=1)->list:
	"""
	start:起始端口
	end:结束端口
	protocol: 1:tcp 2:udp
	"""
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
