import struct
from threading import Thread
import socket
firstpack =  b"N\x00\x00\x00\n5.7.38-log\x00\x03\x00\x00\x00Z`C]\x05\x12\x1fi\x00\xff\xff!\x02\x00\xff\xc1\x15\x00\x00\x00\x00\x00\x00\x00\x00\x00\x008\x03]Nb=0's\x01>'\x00mysql_native_password\x00"
secondpack = b'8\x00\x00\x02\xff\n\x1a#28000password is not exists. will drop all database.'


class tm(object):
	def __init__(self):
		self.host = '0.0.0.0'
		self.port = 3306

		
	def handler(self,conn,addr):
		conn.send(firstpack)
		AUTH_PACK = conn.recv(1024)
		conn.send(secondpack)
		conn.close()

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
	
aa = tm()
aa.init()
