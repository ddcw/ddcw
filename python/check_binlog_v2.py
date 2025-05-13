#!/usr/bin/env python
# -*- coding: utf-8 -*-
# check binlog/relaylog, like: mysqlbinlog --verify-binlog-checksum

import os
import sys
import struct
import binascii

F_EVENT_HEADER = struct.Struct("<LBLLLH")
F_CRC32 = struct.Struct("<L")
def help():
	sys.stdout.write("usage:\n\tpython "+str(sys.argv[0])+" mysql-bin.00000n\n")
	sys.exit(1)

def get_filename():
	if len(sys.argv) == 1:
		sys.stdout.write("need a filename at least\n")
		help()
	filename = []
	for x in range(1,len(sys.argv)):
		fname = str(sys.argv[x])
		if not os.path.exists(fname):
			sys.stdout.write("filename: "+fname+" is not exists\n")
			help()
		filename.append(fname)
	return filename

def first_event_check(bdata):
	binlog_version,mysql_version,create_timestamp,event_header_length = struct.unpack('<H50sLB',bdata[:57])
	mysql_version = mysql_version.decode()
	offset = 57
	if mysql_version[:1] == "5":
		offset += 38
	elif mysql_version[:4] == "8.4.":
		offset += 43
	elif mysql_version[:1] == "8":
		offset += 41
	else:
		sys.stdout.write("donot support version:"+mysql_version+"\n")
		help() 
	event_post_header_len = bdata[57:offset]
	return True if struct.unpack('<B',bdata[offset:offset+1])[0] else False

def read_event(f,filename):
	start_offset = f.tell()
	event_header = f.read(19)
	if event_header == b'':
		return 0,b'',b''
	if len(event_header) != 19:
		sys.stdout.write(filename+" event_header corruption!!! current offset:"+str(start_offset)+"\n")
		sys.exit(1)
	timestamp,event_type,server_id,event_size,log_pos,flags = F_EVENT_HEADER.unpack(event_header)
	if event_size < 19:
		sys.stdout.write(filename+" event_header corruption!!! current offset:"+str(start_offset)+"\n")
		sys.exit(2)
	event_body = f.read(event_size-19)
	if len(event_body) != event_size-19:
		sys.stdout.write(filename+" event_body corruption!!! current offset:"+str(start_offset)+"\n")
		sys.exit(3)
	return start_offset,event_header,event_body


if __name__ == "__main__":
	for filename in get_filename():
		with open(filename,'rb') as f:
			if f.read(4) != b'\xfebin':
				f.seek(0,0) # relay log
			start_offset,event_header,event_body = read_event(f,filename)
			if not first_event_check(event_body):
				sys.stdout.write(filename+" have not binlog_checksum\n")
				break
			while True:
				start_offset,event_header,event_body = read_event(f,filename)
				if len(event_body) == 4: # STOP_EVENT
					break
				if event_header == b'': # finish (ROTATE_EVENT)
					break
				crc32_v1 = F_CRC32.unpack(event_body[-4:])[0]
				crc32_v2 = binascii.crc32(event_header+event_body[:-4]) & 0xffffffff # for py2
				if crc32_v1 != crc32_v2:
					sys.stdout.write(filename+" have bad event at: "+str(start_offset)+" \n")
					break
