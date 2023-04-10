#给sqlite3加个网络模块,  为啥呢?  因为太闲了.....
#懒得写驱动(connect)客户端之类的, 直接用mysql现成的... -_-

import socket,struct
import sqlite3
import hashlib
import random
import os
#import sqlparse
import re

def btoint(bdata,t='little'):
	return int.from_bytes(bdata,t)

def native_password(password,salt):
	stage1 = hashlib.sha1(password).digest()
	stage2 = hashlib.sha1(stage1).digest()
	rp = hashlib.sha1(salt)
	rp.update(stage2)
	result = bytearray(rp.digest())
	for x in range(len(result)):
		result[x] ^= stage1[x]
	return result

class mysqlpack(object):
	"""返回mysql包的Payload"""
	@classmethod
	def HandshakeV10(self,salt,version,capability_flags):
		bdata = b'\n' + version + b'\x00' + struct.pack('<L',6666) + salt[:8] + b'\x00' + capability_flags[:2] + struct.pack('<B',33) + struct.pack('<H',2) + capability_flags[2:4] + struct.pack('<B',len(salt)) + int(0).to_bytes(10,'little') + salt[8:] + b'mysql_native_password\x00'
		return bdata

	@classmethod
	def okpack(self,affected_rows,last_insert_id,status_flags,warnings):
		bdata = struct.pack('<BBBHH',0,affected_rows,last_insert_id,status_flags,warnings)
		return bdata

	@classmethod
	def errorpack(self,code,msg):
		bdata = b'\xff' + struct.pack('<H',code) + msg
		return bdata

	@classmethod
	#懒得去组装字段名字了....
	def rowpack(self,row:tuple,EOFPACK=False):
		#print(row,type(row),'AAAAAAAAAAAAAAAAaaa')
		col_count = len(row[0])
		bdata = []
		bdata = [struct.pack('<B',col_count),]
		for x in range(col_count):
			#均使用63(binary)
			colname = f'col_{x}'
			t = b'\x03def' + int(0).to_bytes(3,'little') + struct.pack('<B',len(colname)) + colname.encode() + b'\x00' + b'\x0c'  + b'?\x00'
			if isinstance(row[0][x],int):
				t += struct.pack('<LB',len(str(row)),3) #3:MYSQL_TYPE_LONG 
			else:
				t += struct.pack('<LB',len(str(row)),253) #253:MYSQL_TYPE_VAR_STRING
			t += b'\x00\x00\x00\x00\x00'
			bdata.append(t)
		if EOFPACK:
			bdata.append(b'\xfe\x00\x00\x00\x00')
		for x in row:
			t = b''
			for col in x:
				_col = str(col)
				t += struct.pack('<B',len(_col)) + _col.encode()
			bdata.append(t)

		if EOFPACK:
			bdata.append(b'\xfe\x00\x00\x00\x00')
		else:
			bdata.append(b'\xfe\x00\x00"\x00\x00\x00')
		return bdata

class sqlite3net(object):
	def __init__(self,*args,**kwargs):
		self.host = '0.0.0.0' #bind host
		self.port = 3306 #bind port
		self.user = 'root' #仅支持单个用户连接.
		self.password = '123456' #加密方式参考 mysql_native_password
		self.database = 'db1' #默认的数据库名, 可以使用Use切换

		self.version_comment = 'sqlite3 with net by ddcw' #version_comment
		self.version = sqlite3.version + '-ddcw' #sqlite版本

		self.dbconn = None #当前的sqlite3连接
		
		self.datadir = './testsqlite' #数据库目录, 支持create database
		self.dblist = [self.database] #当前目录有的数据库
		self.capability_flags = 0 #支持的功能
		self._seq = 0

	def readpack(self):
		pack_header = self.rf.read(4)
		if len(pack_header) < 4:
			print(pack_header,' bye!')
			self._seq = 0
			return None
		btrl, btrh, packet_seq = struct.unpack("<HBB", pack_header)
		self._seq = (packet_seq + 1)%255
		pack_size = btrl + (btrh << 16)
		bdata = self.rf.read(pack_size)
		print('C->S: ',packet_seq,bdata)
		return bdata

	def sendpack(self,bdata):
		pack = len(bdata).to_bytes(3,'little') + struct.pack('<B',self._seq) + bdata
		self.conn.sendall(pack)
		print('S->C: ',self._seq,bdata)
		self._seq += 1

	def accept_client(self):
		while True:
			conn, addr = self.socket_server.accept()
			self.handler(conn, addr)

	def handler(self,conn,addr):
		self.conn = conn
		self.rf = conn.makefile('rb')
		self.client = addr
		salt = hashlib.sha256(str(random.random()).encode()).digest()[:21] #虽然只要前面20字节, 但是最小要21字节, 不然报错: ERROR 2012 (HY000): Error in server handshake
		version = self.version.encode()
		capability_flags = struct.pack('<L',3253731327) #去掉了SSL (1<<11)
		self.sendpack(mysqlpack.HandshakeV10(salt,version,capability_flags))

		authpack = self.readpack()
		if authpack is None:
			return 
		#仅验证账号密码,  把db信息取出来
		npassword = native_password(self.password.encode(),salt[:20]) #只要前面20位...
		stat,dbname = self.auth(authpack,npassword)
		self.database = dbname.decode() if dbname is not None else self.database
		if stat:
			returnpack = mysqlpack.okpack(0,0,2,0)
			self.sendpack(returnpack)
		else:
			returnpack = mysqlpack.errorpack(1024,b"#28000Access denied. user or password is not match")
			self.sendpack(returnpack)
		print('CLIENT FLAG:',self.client_flag)
		while True:
			pack = self.readpack() #出来客户端数据... 解析sql, 根据不同的sql返回不同的数据
			#rowpack = [[]]
			if pack is None:
				break
			if pack[:1] == b'\x01':
				print(f'{self.client} closed.')
			elif pack[:1] == b'\x03': #com_query
				sql = pack[1:].decode()
				#psql = sqlparse.parse(sql)[0]
				if sql == 'select @@version_comment limit 1':
					rowpack = mysqlpack.rowpack([(f'{self.version_comment}',),],self.require_EOF)
				elif re.match('.*select.*@version.*',sql,re.I):
					rowpack = mysqlpack.rowpack([(f'{self.version}',),] ,  self.require_EOF)
				elif re.match('.*select.*user().*',sql,re.I):
					rowpack = mysqlpack.rowpack([(f'{self.user}',),] ,  self.require_EOF)
				elif sql == 'SELECT DATABASE()':
					rowpack = mysqlpack.rowpack([(f'{self.database}',),], self.require_EOF)
				elif re.match('.*show.*create table.*',sql,re.I):
					tablename = sql.split()[-1:][0]
					cursor = self.dbconn.cursor()
					_sql = f"select sql from sqlite_master where type = 'table' and name = '{tablename}'"
					print(_sql,self.database)
					res = cursor.execute(_sql)
					_data = res.fetchall()
					rowpack = mysqlpack.rowpack(_data,self.require_EOF) if len(_data) > 0 else [mysqlpack.errorpack(6669,f'{tablename} do not exist'.encode())]
					
				#elif sql == 'show databases' or sql == 'show database':
				elif re.match('.*show.*databases.*',sql,re.I) or re.match('.*show.*database.*',sql,re.I):
					rowl = [ [x] for x in self.dblist ]
					if len(rowl) == 0:
						rowl = [['no database'],]
					rowpack = mysqlpack.rowpack(rowl, self.require_EOF)
				elif sql == 'SET AUTOCOMMIT = 0':
					rowpack = [b'\x00\x00\x00\x00\x00\x00\x00'] #OKPACK

				elif re.match('.*select.*database.*',sql,re.I):
					rowpack = mysqlpack.rowpack([[f'{self.database}']]  ,self.require_EOF)

				elif re.match('.*create.*database.*',sql,re.I):
					dbname = sql.split('database')[1].split()[0]
					if dbname not in self.dblist:
						self._open(dbname)
						#self.dbconn[dbname] = sqlite3.connect(f'{self.datadir}/{dbname}.db')
						#self.database = dbname
						rowpack = mysqlpack.rowpack([[f'{self.database}']]  ,self.require_EOF)
					else:
						rowpack = [ mysqlpack.errorpack(6667,f'{dbname} existed.'.encode()) ]

				#elif sql == 'show tables':
				elif re.match('.*show.*tables.*',sql,re.I) or re.match('.*show.*table.*',sql,re.I):
					cursor = self.dbconn.cursor()
					res = cursor.execute("select name from sqlite_master where type='table';")
					_data = res.fetchall()
					rowpack = mysqlpack.rowpack(_data,self.require_EOF) if len(_data) > 0 else [mysqlpack.okpack(0,0,2,0)]
					#print(rowpack)
				else:
					#rowpack = mysqlpack.rowpack([('TO BE CONTINED...',)], self.require_EOF)
					cursor = self.dbconn.cursor()
					#print('SQL: ',sql)
					try:
						res = cursor.execute(sql)
						_data = res.fetchall()
						rowpack = mysqlpack.rowpack(_data,self.require_EOF) if len(_data) > 0 else [mysqlpack.okpack(0,0,2,0)]
					except Exception as e:
						rowpack = [ mysqlpack.errorpack(6668,str(e).encode()) ]
					finally:
						cursor.close()

				#print('COM_QUERY SEND PACK',sql)
				for x in rowpack:
					if len(x) > 0:
						self.sendpack(x)
			elif pack[:1] == b'\x02': #切换库, use dbname
				dbname = pack[1:].decode()
				if dbname in self.dblist:
					self._open(dbname)
					#self.database = dbname
					_tdata = b'\x00\x00\x00\x02@\x00\x00\x00'
					_t = b'\x01' + struct.pack('<BBBB',len(dbname)+3,1,len(dbname)+1,len(dbname)) + dbname.encode()
					_tdata += _t
					#rowpack = mysqlpack.rowpack([[f'{self.database}']]  ,self.require_EOF)
					rowpack = [_tdata]
				else:
					rowpack = [mysqlpack.errorpack(6666,f'{dbname} dose not exists'.encode())]
				for x in rowpack:
					self.sendpack(x)

			elif pack[:1] == b'\x04': #查看字段类型, 后面再说吧, 先返回error包
				self.sendpack(mysqlpack.errorpack(6668,'COM_FIELD_LIST TO BE CONTINUED'.encode()))
					
		return

	def _open(self,dbname):
		if dbname not in self.dblist:
			self.dblist.append(dbname)
		try:
			self._close()
		except:
			pass
		self.dbconn = sqlite3.connect(f'{self.datadir}/{dbname}.db')
		self.database = dbname
		

	def _close(self,):
		self.dbconn.commit() #先提交
		self.dbconn.close()
		self.database = None

	def _delete(self,dbname):
		if dbname == self.database:
			self._close()
		if dbname in self.dblist:
			self.dblist.remove(dbname)
		os.remove(f'{self.datadir}/{dbname}.db')

	def start(self):

		#打开本地sqlite3
		os.makedirs(self.datadir,exist_ok=True)
		self._open(self.database)
		for x in os.listdir(self.datadir):
			dbname = x.replace('.db','')
			if dbname not in self.dblist:
				self.dblist.append(dbname)

		socket_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		socket_server.bind((self.host, self.port))
		print(f'bind: {self.host}:{self.port}')
		socket_server.listen(1) #设置连接数
		self.socket_server = socket_server
		self.accept_client()

	def auth(self,bdata,npassword):
		self.client_flag = btoint(bdata[:4])
		self.require_EOF = True if self.client_flag & (1<<24) == 0 else False #24位表示是否使用OK代替EOF
		uoffset = 32 + bdata[32:].find(b'\x00')
		user = bdata[32:uoffset]
		uoffset += 1 #有个b'\x00'
		password_l = btoint(bdata[uoffset:uoffset+1]) #不支持超过253长度, 为啥? 因为我懒...
		password = bdata[uoffset+1:uoffset+1+password_l]
		dbname = None
		#print('USERNAME: ',user,'PASSWORD:',password,'NPASS',npassword,'?????????',bdata)
		if user == self.user.encode() and npassword == password:
			if self.client_flag & ( 1 << 3 ):
				uoffset = uoffset+1+password_l
				dbl_offset = uoffset + bdata[uoffset:].find(b'\x00')
				dbname = bdata[uoffset:dbl_offset]
			return True,dbname
		else:
			return False,dbname
			

aa = sqlite3net()
aa.start()
