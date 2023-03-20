import struct
from threading import Thread
import socket
import time
import testpymysql

def btoint(bdata,t='little'):
        return int.from_bytes(bdata,t)

def read_pack(rf):
	pack_header = rf.read(4)
	if len(pack_header) < 4:
		print(pack_header,' bye!')
		exit(2)
	btrl, btrh, packet_seq = struct.unpack("<HBB", pack_header)
	pack_size = btrl + (btrh << 16)
	bdata = rf.read(pack_size)
	if bdata.find(b'/*ddcw_read*/') == -1:
		return pack_header+bdata,False
	else:
		return pack_header+bdata,True

class mrw(object): 
	def __init__(self):
		self.host = '0.0.0.0'
		self.port = 3306
		self.w = ('192.168.101.21',3308,)
		self.r = (('192.168.101.21',3308,'root','123456'), ('192.168.101.19',3306,'root','123456'))
		self.length = len(self.r)
		self.ri = []
		for x in range(self.length):
			aa = testpymysql.mysql()
			aa.host = self.r[x][0]
			aa.port = self.r[x][1]
			aa.user = self.r[x][2]
			aa.password = self.r[x][3]
			aa.connect()
			self.ri.append([aa.sock,aa.rf])
			
	def hashread(self,client_sock,server_sock,): 
		rf = client_sock.makefile('rb')
		while True:
			bdata,status = read_pack(rf)
			#print('seq:',btoint(bdata[3:4]),bdata[4:5],bdata)
			if status:
				mid = hash(time.time())%self.length
				ts = self.ri[mid]
				ts[0].sendall(bdata)
				eof = 0
				tdata = b''
				seq = 1
				while eof <2:
					data,status = read_pack(ts[1])
					if data[4:5] == b'\xfe':
						eof += 1
						if eof == 1:
							continue
					data = bytearray(data)
					data[3:4] = struct.pack('<B',seq)
					if eof == 2:
						data[0:3] = b'\x07\x00\x00'
						data += b'\x00\x00'
					#print('seq:',btoint(data[3:4]),data[4:5],data)
					client_sock.sendall(data)
					seq += 1
			else:
				server_sock.sendall(bdata)

	def handler(self,conn,addr):
		#连接SERVER
		sock = socket.create_connection((self.w[0], self.w[1]))
		sock.settimeout(None)
		
		#1个监控conn发来的数据,然后转发, 一个监控server发来的数据, 然后转发
		t1 = Thread(target=self.hashread,args=(conn,sock))
		t2 = Thread(target=self.hashread,args=(sock,conn,))
		t1.start()
		t2.start()
		t1.join()
		t2.join()

	def init(self):
		socket_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		socket_server.bind((self.host, self.port))
		socket_server.listen(151)
		self.socket_server = socket_server

		accept_client_thread = Thread(target=self.accept_client,daemon=True)
		accept_client_thread.start()
		accept_client_thread.join()
		
	def accept_client(self,):
		while True:
			conn, addr = self.socket_server.accept()
			thread = Thread(target=self.handler,args=(conn,addr),daemon=True)
			thread.start()
	
aa = mrw()
aa.init()
