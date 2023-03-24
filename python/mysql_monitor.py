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

class mmonitor(object): 
	def __init__(self):
		self.host = '0.0.0.0'
		self.port = 3306
		self.server = ('192.168.101.21',3308,)
		self.cert = '/data/mysql_3306/mysqldata/server-cert.pem'
		self.key = '/data/mysql_3306/mysqldata/server-key.pem'
		
	def handler_msg(self,rf,sock,f):
		#print(f'{f} start')
		while True:
			bdata = read_pack(rf)
			sock.sendall(bdata)
			print(f'{f}',btoint(bdata[3:4]),bdata)

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
		
		t1 = Process(target=self.handler_msg,args=(client_rf,sock,'C->S: ')) #监控客户端数据, 然后发往server端
		t2 = Process(target=self.handler_msg,args=(server_rf,conn,'S->C: '))
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
