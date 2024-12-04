#!/usr/bin/env python
# -*- coding: utf-8 -*-
# write by ddcw @https://github.com/ddcw
# 提取mysqlbinlog中的DDL的脚本. 之前那个版本太丑了, 不好看, 于是写一版新的, 用法和之前一样.

import sys
import os
import struct
ARGV = sys.argv
# 用法:
def USAGE():
	msg = "\nUSAGE:\n\t python " + str(ARGV[0]) + " /PATH/mysql-bin.000002*\n\n"
	sys.stdout.write(msg)
	sys.exit(1)

def GET_DDL_FROM_BINLOG(filename):
	with open(filename,'rb') as f:
		magic = f.read(4)
		msg = "\n\n-- 开始解析BINLOG: " + str(filename) + "\n"
		if magic != b'\xfebin': #relay log
			f.seek(0,0)
			msg = "-- 开始解析relay log: " + str(filename) + "\n"
		sys.stdout.write(msg)
		CHECKSUM = False
		while True:
			event_header_bdata = f.read(19)
			if event_header_bdata == b'':
				break
			timestamp, event_type, server_id, event_size, log_pos, flags = struct.unpack("<LBLLLh",event_header_bdata[0:19])
			event_bdata = f.read(event_size-19)
			if event_type == 15: # FORMAT_DESCRIPTION_EVENT
				aa = FORMAT_DESC_EVENT(event_bdata)
				CHECKSUM = aa.init()
			elif event_type == 2: # QUERY_EVENT
				if CHECKSUM:
					qe = QUERY_EVENT(event_bdata[:-4])
				else:
					qe = QUERY_EVENT(event_bdata)
				qe.init()
				if qe.query == "BEGIN": # continue就没必要打印了
					continue
				msg = "\nuse `" + str(qe.dbname) + "`\n" + str(qe.query) + ";\n"
				sys.stdout.write(msg)
			elif event_type == 3: # STOP_EVENT
				break
			


class EVENT(object):
	def __init__(self,bdata):
		self.offset = 0
		self.bdata = bdata
		self.size = len(bdata)
	def read(self,n):
		if self.offset + n > self.size:
			return None
		data = self.bdata[self.offset:self.offset+n]
		self.offset += n
		return data
	def read_uint(self,n): # 全是little
		data = self.read(n)
		if data is None:
			return data
		#tdata = [ x for x in data ] # only py3
		sn = ">"+str(n)+"B"
		tdata = struct.unpack(sn,data)
		rdata = 0
		for x in range(n):
			rdata += tdata[x]<<((x)*8)
		return rdata

class FORMAT_DESC_EVENT(EVENT):
	def __init__(self,bdata):
		super(FORMAT_DESC_EVENT,self).__init__(bdata)
	def init(self,):
		self.binlog_version = self.read_uint(2)
		self.mysql_version = self.read(50).decode()
		self.create_timestamp = self.read_uint(4)
		self.event_header_length = self.read_uint(1)
		if self.mysql_version[:1] == "5":
			self.event_post_header_len = self.read(38)
		elif self.mysql_version[:4] == "8.4.":
			self.event_post_header_len = self.read(43) # FOR MYSQL 8.4
		elif self.mysql_version[:1] == "8":
			self.event_post_header_len = self.read(41)
		self.checksum_alg = self.read_uint(1)
		msg = "-- MYSQL_VERSION:" + str(self.mysql_version) + " BINLOG_VERSION:" + str(self.binlog_version) + " CHECKSUM:" + str(self.checksum_alg)  + "\n"
		sys.stdout.write(msg)
		if self.checksum_alg:
			return True

class QUERY_EVENT(EVENT):
	def __init__(self,bdata):
		super(QUERY_EVENT,self).__init__(bdata)
	def init(self,):
		self.thread_id = self.read_uint(4)
		self.query_exec_time = self.read_uint(4)
		db_len = self.read_uint(1)
		self.error_code = self.read_uint(2)
		status_vars_len = self.read_uint(2)
		self.status_vars = self.read(status_vars_len)
		self.dbname = self.read(db_len).decode()
		self.read(1)
		self.query = self.read(len(self.bdata)-self.offset).decode()

if __name__ == "__main__":
	if len(ARGV) < 2:
		USAGE()
	for x in ARGV[1:]:
		if str(x).upper().find('-H') >= 0:
			USAGE()
	READED_FILENAME = []
	for filename in ARGV[1:]:
		CONTINUE_FLAG = False
		msg = ''
		if filename in READED_FILENAME:
			msg += "\n文件(" + filename + ")已经解析过了\n"
			CONTINUE_FLAG = True
		READED_FILENAME.append(filename)
		if not os.path.exists(filename):
			msg += "文件(" + filename + ")不存在\n"
			CONTINUE_FLAG = True
		if CONTINUE_FLAG:
			sys.stdout.write(msg)
			continue
		else:
			GET_DDL_FROM_BINLOG(filename)
	if len(READED_FILENAME) == 0:
		USAGE()
