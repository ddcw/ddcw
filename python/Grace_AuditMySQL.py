#!/usr/bin/env python3
#audit mysql, write by ddcw @https://github.com/ddcw
import socket,struct

def main():
	s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.ntohs(0x0800))
	try:
		while True:
			packet = s.recvfrom(65565)[0] #(bytes, address)
			ip_header = struct.unpack('!BBHHHBBH4s4s', packet[14:34]) #IP PRO
			source_ip,dest_ip = socket.inet_ntoa(ip_header[8]),socket.inet_ntoa(ip_header[9])
			iph_length = (ip_header[0] & 0xF) * 4

			if ip_header[6] == socket.IPPROTO_TCP: #ONLY FOR TCP
				tcp_header = struct.unpack('!HHLLBBHHH', packet[14+iph_length:14+iph_length+20]) #TCP PRO
				source_port,dest_port = tcp_header[0],tcp_header[1]
				tcp_length = (tcp_header[4] >> 4) * 4
				data_offset = 14 + iph_length + tcp_length
				data = packet[data_offset:]
				if dest_port == 3308 and data and data[4:5] == b'\x03': #match PORT and mysql query pack
					print(f"{source_ip}:{source_port} --> {dest_ip}:{dest_port}\t{data[5:].decode()}")

	except KeyboardInterrupt:
		pass

	finally:
		s.close()

if __name__ == "__main__":
	main()
