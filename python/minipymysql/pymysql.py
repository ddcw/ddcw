# 连接数据库的 , 基础的跑SQL, 就行. 不做TPC,之类的,
# 参考 PEP-0249 https://peps.python.org/pep-0249
import hashlib
import struct
import socket
import os
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import padding

__capabilities_flags = """
#client/server
CLIENT_LONG_PASSWORD = 1 << 0  #旧密码插件 Use the improved version of Old Password Authentication
CLIENT_FOUND_ROWS = 1 << 1  #Send found rows instead of affected rows in EOF_Packet
CLIENT_LONG_FLAG = 1 << 2 # for ColumnDefinition320
CLIENT_CONNECT_WITH_DB = 1 << 3 #是否带有 dbname 
CLIENT_NO_SCHEMA = 1 << 4 #已弃用. (不允许使用db.table.col)
CLIENT_COMPRESS = 1 << 5 #是否支持压缩
CLIENT_ODBC = 1 << 6 #odbc
CLIENT_LOCAL_FILES = 1 << 7 #能否使用 LOAD DATA LOCAL
CLIENT_IGNORE_SPACE = 1 << 8 #是否忽略 括号( 前面的空格
CLIENT_PROTOCOL_41 = 1 << 9 #是否使用CLIENT_PROTOCOL_41
CLIENT_INTERACTIVE = 1 << 10 #是否为交互式终端(就是mysql连接的那种)
CLIENT_SSL = 1 << 11 #是否支持SSL
CLIENT_IGNORE_SIGPIPE = 1 << 12 #网络故障的时候发SIGPIPE
CLIENT_TRANSACTIONS = 1 << 13 #OK/EOF包的status_flags
CLIENT_RESERVED  = 1 << 14 #已弃用 
CLIENT_RESERVED2 = 1 << 15 #已弃用 
CLIENT_MULTI_STATEMENTS = 1 << 16 #是否支持multi-stmt.  COM_QUERY/COM_STMT_PREPARE中多条语句
CLIENT_MULTI_RESULTS = 1 << 17 #multi-results
CLIENT_PS_MULTI_RESULTS = 1 << 18 #PS-protocol
CLIENT_PLUGIN_AUTH = 1 << 19 #是否支持密码插件
CLIENT_CONNECT_ATTRS = 1 << 20 #是否支持连接属性
CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA = 1 << 21 #密码认证包能否大于255字节
CLIENT_CAN_HANDLE_EXPIRED_PASSWORDS = 1 << 22 #不关闭密码过期的连接. 我要改密码..
CLIENT_SESSION_TRACK = 1 << 23 #能够处理服务器状态变更信息
CLIENT_DEPRECATE_EOF = 1 << 24 #OK包代替EOF包.  小坑...
CLIENT_OPTIONAL_RESULTSET_METADATA = 1 << 25 #客户端能处理可选元数据信息
CLIENT_ZSTD_COMPRESSION_ALGORITHM = 1 << 26 #zstd压缩
CLIENT_QUERY_ATTRIBUTES = 1 << 27 #支持COM_QUERY/COM_STMT_EXECUTE中的可选参数
MULTI_FACTOR_AUTHENTICATION = 1 << 28 
CLIENT_CAPABILITY_EXTENSION  = 1 << 29 
CLIENT_SSL_VERIFY_SERVER_CERT = 1 << 30 #验证服务器证书
CLIENT_REMEMBER_OPTIONS = 1 << 31 
"""

def sha2_rsa_encrypt(password, salt, public_key):
	message = _xor_password(password + b"\0", salt)
	rsa_key = serialization.load_pem_public_key(public_key, default_backend())
	return rsa_key.encrypt(
		message,
		padding.OAEP(
			mgf=padding.MGF1(algorithm=hashes.SHA1()),
			algorithm=hashes.SHA1(),
			label=None,
		),
	)

def _xor_password(password, salt):
	salt = bytearray(salt[:20])
	password = bytearray(password)
	for i in range(len(password)):
		password[i] ^= salt[i%len(salt)]
	return bytes(password)

def _read_lenenc(bdata,i): 
	length = struct.unpack('<B',bdata[i:i+1])[0]
	i += 1
	data = bdata[i:i+length]
	i += length
	return data,i

def native_password(password,salt):
	stage1 = hashlib.sha1(password).digest()
	stage2 = hashlib.sha1(stage1).digest()

	rp = hashlib.sha1(salt)
	rp.update(stage2)
	result = bytearray(rp.digest())

	for x in range(len(result)):
		result[x] ^= stage1[x]
	return result

def sha2_password(password,salt):
	stage1 = hashlib.sha256(password).digest()
	stage2 = hashlib.sha256(stage1).digest()
	stage3 = hashlib.sha256(stage2+salt).digest()
	result = bytearray(stage3)
	for x in range(len(result)):
		result[x] ^= stage1[x]
	return result


def _lenenc_int(i):
	if i < 0:
		raise ValueError("Encoding %d is less than 0 - no representation in LengthEncodedInteger" % i)
	elif i < 0xFB:
		return bytes([i])
	elif i < (1 << 16):
		return b"\xfc" + struct.pack("<H", i)
	elif i < (1 << 24):
		return b"\xfd" + struct.pack("<I", i)[:3]
	elif i < (1 << 64):
		return b"\xfe" + struct.pack("<Q", i)
	else:
		raise ValueError("Encoding %x is larger than %x - no representation in LengthEncodedInteger"% (i, (1 << 64)))

class cursor(object):
	def __init__(self,conn):
		"""
		只实现 execute, fetchall 所以就放这了.
		"""
		self.conn = conn
		self.description = None
		self.rowcount = -1
		self.column_count = 0
		self._result = None # 查询结果

	def callproc(self,procname,parameters=None):
		pass

	def close(self,):
		pass

	def execute(self,sql,parameters=None):
		# 不支持%这种传参. 太麻烦了. 不符合本脚本的初衷(所以初衷是啥呢?)
		self._result = []
		self.description = []
		self.conn._query(sql)
		stat = self.conn._read_pack() # column count
		# 暂不考虑太多行的情况(<=251使用1字节)
		stat1 = struct.unpack('<B',stat[:1])[0]
		if stat1 == 0: # OK
			return
		elif stat1 < 252:
			column_count = stat1
		elif stat1 == 252:
			column_count = struct.unpack('<H',stat[1:3])[0]
		elif stat1 == 255: #error
			return {'code':struct.unpack('<H',stat[1:3])[0],'msg':stat[3:].decode()}
		else:
			column_count = -1 # 不支持,谁TM没事建那么多列???
		self.column_count = column_count
		for x in range(column_count):
			bdata = self.conn._read_pack()
			col = {}
			i = 0
			# https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_com_query_response_text_resultset_column_definition.html
			catalog,i = _read_lenenc(bdata,i)
			schema,i = _read_lenenc(bdata,i)
			table,i = _read_lenenc(bdata,i)
			org_table,i = _read_lenenc(bdata,i)
			name,i = _read_lenenc(bdata,i)
			org_name,i = _read_lenenc(bdata,i)
			i += 1 # 0x0c
			character_set = struct.unpack('<H',bdata[i:i+2])[0]
			i += 2
			column_length = struct.unpack('<L',bdata[i:i+4])[0]
			i += 4
			_type = struct.unpack('<B',bdata[i:i+1])[0]
			i += 1
			flags = struct.unpack('<H',bdata[i:i+2])[0]
			i += 2
			decimals = struct.unpack('<B',bdata[i:i+1])[0]
			i += 1
			self.description.append({
			'catalog':catalog,
			'schema':schema,
			'table':table,
			'name':name,
			'character_set':character_set,
			'column_length':column_length,
			'_type':_type,
			'flags':flags,
			'decimals':decimals
			})
		while True:
			bdata = self.conn._read_pack()
			if bdata[:1] == b'\xfe': #OK包, 我们使用OK包代替了EOF包, 所以这就结束了
				# 行数之类的信息我也懒得读了. 不对又能怎样呢?
				break
			# 正常读数据 长度+值 所以全部当作字符串就行
			_data = []
			i = 0
			for _ in range(column_count):
				i1 = struct.unpack('<B',bdata[i:i+1])[0]
				i += 1
				if i1 <= 0xFB:
					i2 = i1
				elif i1 == 0xFC:
					i2 = struct.unpack('<H',bdata[i:i+2])[0]
					i += 2
				elif i1 == 0xFD:
					i21,i22 = struct.unpack('<HB',bdata[i:i+3])
					i2 = i21<<16+i22
				elif i1 == 0xFE:
					i2 = struct.unpack('<Q',bdata[i:i+8])[0]
				try:
					_data.append(bdata[i:i+i2].decode())
				except:
					_data.append(bdata[i:i+i2])
				i += i2
			self._result.append(_data)
			

	def executemany(self,*args,**kwargs):
		pass

	def fetchone(self):
		if self._result is not None:
			return self._result[:1]
		else:
			return self._result

	def fetchmany(self,n):
		return self._result[:n]

	def fetchall(self,):
		return self._result

	def nextset(self,):
		pass

	def arraysize(self,):
		pass

	def setinputsizes(self,size):
		pass

	def setoutputsize(self,size,column=None):
		pass
		

class connect(object):
	def __init__(self,*args,**kwargs):
		"""
		暂时不支持SOCKET连接, 也不支持 --login-path (懒得调openssl)
		也不支持ssl, 为啥? 懒 (caching_sha2_password要求ssl 所以不支持caching_sha2_password, 但是9.1不支持mysql_native_password)
		也不支持dsn , 懒得拆分字符串了.
		只支持mysql_native_password
		"""
		self.host = kwargs['host'] if 'host' in kwargs else '127.0.0.1'
		self.port = int(kwargs['port']) if 'port' in kwargs else 3306
		self.user = kwargs['user'] if 'user' in kwargs else 'root' # 不默认当前OS账号, 直接默认root
		self.password = kwargs['password'] if 'user' in kwargs else None
		self.database = kwargs['database'] if 'database' in kwargs else None
		self.cert = None
		self.key = None
		self.socket = None
		self.connect_status = False
		self.autocommit = False
		self.sql_mode = 0
		self.charset = 33 #直接utf8mb3
		self.msg = "" # 没写异常, 直接把信息放这把...
		self._error_msg = None
		self.conn = None # read/send pack
		self.__next_seq_id = 0 # 计数的
		self._conn() # 直接连接数据库.

	def __str__(self,):
		return f"CONNECT:{self.connect_status} {self.user}@{self.host}:{self.port}"

	def _conn(self,):
		# 这里就是建立mysql连接了
		self._next_seq_id = 0
		sock = socket.create_connection((self.host, self.port)) # 直接走tcp, 不考虑socket
		sock.settimeout(None)
		self.conn = sock
		self._rf = self.conn.makefile("rb")
		bdata = self._read_pack() # 服务端主动发消息, (告诉我们它用啥玩意加密)
		self._handshake(bdata) # 那我们瞅一瞅是个啥
		if not self._HandshakeResponse41(): # 瞅完了, 就回复一声(default_authentication_plugin可能和用户实际使用的不一致)
			raise Exception(f"连接失败, {self._error_msg}")
		

	def _handshake(self,bdata):
		i = 0
		protocol_version = bdata[:1] # 10:\n
		self.protocol_version = struct.unpack('<B',protocol_version)[0]
		server_end = bdata.find(b"\0", i)
		self.server_version = bdata[1:server_end].decode()
		i = server_end + 1
		self.thread_id = struct.unpack('<L',bdata[i:i+4])[0]
		i += 4
		self.salt = bdata[i:i+8]
		i += 8 + 1
		self.server_capabilities = struct.unpack('<H',bdata[i:i+2])[0]
		i += 2
		self.server_charset = struct.unpack('<B',bdata[i:i+1])[0]
		i += 1
		self.server_status = struct.unpack('<H',bdata[i:i+2])[0]
		i += 2
		self.server_capabilities |= struct.unpack('<H',bdata[i:i+2])[0] << 16
		i += 2
		salt_length = struct.unpack('<B',bdata[i:i+1])[0]
		salt_length = max(13,salt_length-8)
		i += 1
		i += 10 #reserved
		self.salt += bdata[i:i+salt_length]
		i += salt_length
		self.server_plugname = bdata[i:]

	def _HandshakeResponse41(self):
		# 不想支持dbname,还要判断, 不符合本脚本的设计之初
		client_flag = 33531525 #if self.database is None else 33531525 ^ (1<<3)
		charset_id = self.charset if int(self.server_version[0]) >= 8 else 33
		bdata = struct.pack('<iIB23s',client_flag,2**24-1,charset_id,b'')
		bdata += self.user.encode() + b'\0'
		auth_password = native_password(self.password.encode(), self.salt[:20])
		auth_response = _lenenc_int(len(auth_password)) + auth_password
		bdata += auth_response
		bdata += b"mysql_native_password" + b'\0'
		attr = {'_client_name':'ddcw_for_pymysql', '_pid':str(os.getpid()), "_client_version":'0.0.1',}
		connect_attrs = b""
		for k, v in attr.items():
			k = k.encode()
			connect_attrs += _lenenc_int(len(k)) + k
			v = v.encode()
			connect_attrs += _lenenc_int(len(v)) + v
		bdata += _lenenc_int(len(connect_attrs)) + connect_attrs
		self._write_pack(bdata)
		auth_pack = self._read_pack()
		if auth_pack[:1] == b'\0': #OK
			return True
		elif auth_pack[:1] == b'\xfe': # 交换认证
			#print('交换认证')
			if auth_pack.find(b'caching_sha2_password') < 0:
				return False
			scrambled = sha2_password(self.password.encode(),auth_pack[auth_pack.find(b'\x00')+1:])
			self._write_pack(scrambled)
			auth_pack = self._read_pack()
			self.caching_sha2_password_auth(auth_pack)
		elif auth_pack[:1] == b'\x01': # 额外认证
			#print('额外认证')
			self.caching_sha2_password_auth(auth_pack)
		elif auth_pack[:1] == b'\xff': # 连接失败
			self._error_msg = {'code':struct.unpack('<H',auth_pack[1:3])[0],'msg':auth_pack[3:].decode()}
			return False
		else:
			return False
		return True

	def caching_sha2_password_auth(self,auth_pack):
		#print('caching_sha2_password_auth')
		if auth_pack[1:2] == b'\x03': #fast
			bdata = self._read_pack() #ok pack
		elif auth_pack[1:2] == b'\x04': #full
			#如果是SSL/socket/shard_mem就直接发送密码(不需要加密了) TODO
			self._write_pack(b'\x02') #要公钥
			bdata = self._read_pack() #server发来的公钥
			pubk = bdata[1:]
			self.pubk = pubk
			password = sha2_rsa_encrypt(self.password.encode(), self.salt, pubk)
			self._write_pack(password)
			authpack = self._read_pack() #看看是否成功
			if authpack[:1] == b'\xff':
				raise Exception({'code':struct.unpack('<H',authpack[1:3])[0],'msg':authpack[3:].decode()})
		else:
			return False

	def _read_pack(self,):
		pack_header = self._rf.read(4)
		btrl, btrh, packet_seq = struct.unpack("<HBB", pack_header)
		pack_size = btrl + (btrh << 16)
		self._next_seq_id = (self._next_seq_id + 1) % 256
		bdata = self._rf.read(pack_size)
		return bdata

	def _write_pack(self,data):
		bdata = struct.pack("<I", len(data))[:3] + bytes([self._next_seq_id]) + data
		self.conn.sendall(bdata)
		self._next_seq_id = (self._next_seq_id + 1) % 256

	def cursor(self,):
		return cursor(self)

	def _query(self,sql):
		sql = sql.encode()
		bdata = struct.pack('<IB',len(sql)+1,0x03) + sql
		self.conn.sendall(bdata)
		self._next_seq_id = 1
		#return self._result()

	def _result(self,):
		pass

	def begin(self):
		pass

	def commit(self):
		pass

	def close(self):
		pass

	def rollback(self,):
		pass

	def ping(self,):
		pass # 发个mysql ping给mysql, return True or False
