import struct
from threading import Thread
from multiprocessing import Process
import socket
import time
import sys
import ssl

def btoint(bdata,t='little'):
        return int.from_bytes(bdata,t)

def read_pack(rf):
	pack_header = rf.read(4)
	if len(pack_header) < 4:
		print(pack_header,' bye!')
		sys.exit(2)
	btrl, btrh, packet_seq = struct.unpack("<HBB", pack_header)
	pack_size = btrl + (btrh << 16)
	bdata = rf.read(pack_size)
	return pack_header+bdata

def _lenenc_int_unpack(data):
	i = struct.unpack('<B',data[:1])[0]
	if i == 0xfc:
		return 3,struct.unpack('<H',data[1:3])[0]
	elif i == 0xfd:
		return 4,struct.unpack('<I',data[1:3]+b'0x00')[0]
	elif i == 0xfe:
		return 9,struct.unpack('<Q',data[1:9])[0]
	elif i < 0xfc:
		return 1, i
	else:
		return -1,-1

def _lenenc_int_pack(i):
	if i < 0xFB:
		return bytes([i])
	elif i < (1 << 16):
		return b"\xfc" + struct.pack("<H", i)
	elif i < (1 << 24):
		return b"\xfd" + struct.pack("<I", i)[:3]
	elif i < (1 << 64):
		return b"\xfe" + struct.pack("<Q", i)
	else:
		return 0x00

# 匹配哪些字段需要脱敏, 比如我们只用看是否有phone字段
def match_column(data):
	# 懒得解析ColumnDefinition41 了,直接find吧...
	return True if data.find(b'phone') > 0 else False

# 开始脱敏
def datamask_01(bdata,col_mask,column_count):
	data = []
	offset = 4
	for i in range(column_count):
		x,size = _lenenc_int_unpack(bdata[offset:][:4])
		offset += x
		tdata = bdata[offset:offset+size]
		if col_mask & (1<<i) > 0: # 匹配上了,那就脱敏吧..
			tdata = tdata[:2]+b"****"+tdata[-2:]
		data.append(tdata)
		offset += size
	# 重新封包
	rdata = b''.join([ _lenenc_int_pack(len(x))+x for x in data])
	rdata = struct.pack('<L',len(rdata))[:3] + bdata[3:4] + rdata
	return rdata

class mmonitor(object): 
	def __init__(self):
		self.host = '0.0.0.0'
		self.port = 3306
		self.server = ('192.168.101.21',3314,)
		self.cert = '/data/mysql_3314/mysqldata/server-cert.pem'
		self.key = '/data/mysql_3314/mysqldata/server-key.pem'
		
	def handler_msg(self,rf,sock,f):
		while True:
			bdata = read_pack(rf)
			sock.sendall(bdata)
			#print(f'{f}',btoint(bdata[3:4]),bdata)

	def handler_msg_toclient(self,rf,sock,f):
		while True:
			bdata = read_pack(rf)
			print(bdata)
			if bdata[:4] == b'\x01\x00\x00\x01' and len(bdata) <= 7: # column count
				sock.sendall(bdata)
				_,column_count = _lenenc_int_unpack(bdata[4:])
				col_mask = 0
				# 匹配字段
				for i in range(column_count):
					bdata = read_pack(rf)
					sock.sendall(bdata)
					if match_column(bdata):
						col_mask |= (1<<i)
				# 读取字段数据并脱敏返回
				while True:
					bdata = read_pack(rf)
					if bdata[4] == 0xfe and len(bdata) == 11: #EOF 
						sock.sendall(bdata)
						break
					print(bdata,col_mask,column_count,'XXXXXXXXXXXXXXXx')
					bdata = datamask_01(bdata,col_mask,column_count)
					sock.sendall(bdata)
				
			else:
				sock.sendall(bdata)

	def handler(self,conn,addr):
		sock = socket.create_connection((self.server[0], self.server[1]))
		server_rf = sock.makefile('rb')
		bdata = read_pack(server_rf)
		conn.sendall(bdata)
		print('S->C: ',btoint(bdata[3:4]),bdata)

		client_rf = conn.makefile('rb')
		bdata = read_pack(client_rf)
		print('C->S: ',btoint(bdata[3:4]),bdata)
		sock.sendall(bdata)

		if len(bdata) < 38: #封装为SSL (32+4)
			#print('SSL')
			#封装客户端的SSL (因为相对于client, 这是server角色)
			context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
			context.load_cert_chain(certfile=self.cert, keyfile=self.key)
			conn = context.wrap_socket(conn, server_side=True)
			client_rf = conn.makefile('rb')

			#封装到server的SSL
			sock = ssl.wrap_socket(sock)
			server_rf = sock.makefile('rb')
		
		t1 = Process(target=self.handler_msg,args=(client_rf,sock,'C->S: '))
		t2 = Process(target=self.handler_msg_toclient,args=(server_rf,conn,'S->C: '))
		t1.start()
		t2.start()
		t1.join()
		t2.join()

	def init(self):
		socket_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		socket_server.bind((self.host, self.port))
		socket_server.listen(12345) #设置连接数
		self.socket_server = socket_server

		accept_client_thread = Thread(target=self.accept_client,)
		accept_client_thread.start()
		accept_client_thread.join()
		
	def accept_client(self,):
		while True:
			conn, addr = self.socket_server.accept()
			p = Process(target=self.handler,args=(conn,addr),)
			p.start()
	
aa = mmonitor()
aa.init()
