import hashlib
import socket
import struct
import os


#来自pymysql
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

def native_password(password,salt):
	stage1 = hashlib.sha1(password).digest()
	stage2 = hashlib.sha1(stage1).digest()
	
	rp = hashlib.sha1(salt)
	rp.update(stage2)
	result = bytearray(rp.digest())
	
	for x in range(len(result)):
		result[x] ^= stage1[x]
	return result


def btoint(bdata,t='little'):
        return int.from_bytes(bdata,t)

class mysql(object):
	def __init__(self):
		self.host = '192.168.101.21'
		self.port = 3308
		self.user = 'root'
		self.password = '123456'

	def read_pack(self,):
		pack_header = self.rf.read(4)
		btrl, btrh, packet_seq = struct.unpack("<HBB", pack_header)
		pack_size = btrl + (btrh << 16)
		self._next_seq_id = (self._next_seq_id + 1) % 256 
		bdata = self.rf.read(pack_size) #也懒得考虑超过16MB的包了
		return bdata

	def write_pack(self,data):
		#3字节长度, 1字节seq, data
		bdata = struct.pack("<I", len(data))[:3] + bytes([self._next_seq_id]) + data
		self.sock.sendall(bdata)
		self._next_seq_id = (self._next_seq_id + 1) % 256

	def handshake(self,bdata):
		i = 0 #已经读取的字节数, 解析binlog的时候也是这么用的.....
		protocol_version = bdata[:1] #只解析10

		server_end = bdata.find(b"\0", i)
		self.server_version = bdata[i:server_end]
		i = server_end + 1

		self.thread_id = btoint(bdata[i:i+4])
		i += 4

		self.salt = bdata[i:i+8]
		i += 9 #还有1字节的filter, 没啥意义,就不保存了

		self.server_capabilities = btoint(bdata[i:i+2])
		i += 2

		self.server_charset = btoint(bdata[i:i+1])
		i += 1

		self.server_status = btoint(bdata[i:i+2])
		i += 2
		
		self.server_capabilities |= btoint(bdata[i:i+2]) << 16 #往左移16位 为啥不把capability_flags_1和capability_flags_2和一起呢
		i += 2

		salt_length = struct.unpack('<B',bdata[i:i+1])[0] #懒得去判断capabilities & CLIENT_PLUGIN_AUTH了
		salt_length = max(13,salt_length-8) #前面已经有8字节了
		i += 1

		i += 10 #reserved

		self.salt += bdata[i:i+salt_length]
		i += salt_length

		self.server_plugname = bdata[i:]

	def HandshakeResponse41(self,):
		client_flag = 3842565 #不含DBname   
		#client_flag |= 1 << 3

		charset_id = 45 #45:utf8mb4  33:utf8

		#bdata = client_flag.to_bytes(4,'little') #其实应该最后在加, 毕竟还要判断很多参数, 可能还需要修改, 但是懒
		bdata = struct.pack('<iIB23s',client_flag,2**24-1,charset_id,b'')

		bdata += self.user.encode() + b'\0'
		
		auth_password = native_password(self.password.encode(), self.salt[:20])
		auth_response = _lenenc_int(len(auth_password)) + auth_password 
		bdata += auth_response

		bdata += b"mysql_native_password" + b'\0'

		#本文有设置连接属性, 主要是为了方便观察
		attr = {'_client_name':'ddcw_for_pymysql', '_pid':str(os.getpid()), "_client_version":'0.0.1',}
		#key长度+k+v长度+v
		connect_attrs = b""
		for k, v in attr.items():
			k = k.encode()
			connect_attrs += _lenenc_int(len(k)) + k
			v = v.encode()
			connect_attrs += _lenenc_int(len(v)) + v
		bdata += _lenenc_int(len(connect_attrs)) + connect_attrs
		self.write_pack(bdata)
			
		auth_pack = self.read_pack() #看看是否连接成功
		if auth_pack[:1] == b'\0':
			print('OK',)
		else:
			print('FAILED',auth_pack)
		
		

	def connect(self):
		sock = socket.create_connection((self.host, self.port))
		sock.settimeout(None)
		self.sock = sock
		self.rf = sock.makefile("rb")
		self._next_seq_id = 0

		#解析server的握手包
		bdata = self.read_pack()
		self.handshake(bdata)

		#握手.发账号密码
		self.HandshakeResponse41()
		
