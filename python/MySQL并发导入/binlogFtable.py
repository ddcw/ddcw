#!/usr/bin/env python
# -*- coding: utf-8 -*-
# write by ddcw @https://github.com/ddcw
# 从binlog里面过滤出指定的表信息. 会破坏事务的完整性, 谨慎使用!!!

import sys,os
import re
import datetime,time
import errno
import argparse,glob
import struct

def _argparse():
	parser = argparse.ArgumentParser(add_help=True, description='从 binlog 提取出指定表出来')
	parser.add_argument('--version', '-v', '-V', action='store_true', dest="VERSION", default=False, help='版本信息')
	parser.add_argument('--database', dest="DATABASE", default="*", help='数据库')
	parser.add_argument('--table', dest="TABLE", default="*", help='表')
	parser.add_argument('--output-dir', dest="OUTPUT_DIR", default="", help='输出的目录')
	parser.add_argument("files", nargs="*", help="要提取的原始BINLOG文件")
	if parser.parse_args().VERSION:
		print('VERSION: v0.1')
		sys.exit(0)
	return parser.parse_args()

def mkdir_exists(dirname):
	try:
		os.makedirs(dirname)
	except OSError as e:
		if e.errno != errno.EEXIST:
			raise

def match_table(dbname,tablename):
	dtname = str(dbname) + "." + str(tablename)
	return True if re.search(PATTERN,dtname) else False

#把event写入binlog文件, 主要是修改POS信息
def write_event(event_header,event_payload,f):
	timestamp, event_type, server_id, event_size, log_pos, flags = struct.unpack("<LBLLLh",event_header[0:19])
	event_size = len(event_header) + len(event_payload)
	log_pos = f.tell() + event_size
	event_header = struct.pack("<LBLLLh", timestamp, event_type, server_id, event_size, log_pos, flags)
	f.write(event_header)
	f.write(event_payload)

def read_tablename_dbname(bdata):
	offset = 8 #table_id + flag
	dbname_length = struct.unpack('<B', bdata[offset:offset+1])[0]
	offset += 1
	dbname =  bdata[offset:offset+dbname_length].decode()
	offset += dbname_length + 1 #\x00结尾
	tablename_length = struct.unpack('<B', bdata[offset:offset+1])[0]
	offset += 1
	tablename =  bdata[offset:offset+tablename_length].decode()
	return dbname, tablename

def event_header(bdata):
	return 
	timestamp, event_type, server_id, event_size, log_pos, flags = struct.unpack("<LBLLLh",bdata[0:19])

if __name__ == '__main__':
	parser = _argparse()
	FILTER_DATABASE = parser.DATABASE
	FILTER_TABLE = parser.TABLE
	PATTERN = str(FILTER_DATABASE).replace("*",".*") + "\." + str(FILTER_TABLE).replace("*",".*")
	filelist = []
	for pattern in parser.files:
		filelist += glob.glob(pattern)
	filelist.sort() #其实没必要排序的
	OUTPUT_DIR = parser.OUTPUT_DIR if parser.OUTPUT_DIR != "" else "BinlogFtableByddcw_" + str(datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))
	OUTPUT_DIR = os.path.abspath(OUTPUT_DIR)
	mkdir_exists(OUTPUT_DIR)

	#开始读binlog匹配了
	for FILENAME_SOURCE in filelist:
		FILENAME_DEST = os.path.join(OUTPUT_DIR, os.path.basename(FILENAME_SOURCE))
		print(str(FILENAME_SOURCE)+" --> "+FILENAME_DEST)
		fs = open(FILENAME_SOURCE,'rb')
		fd = open(FILENAME_DEST,'wb')
		if fs.read(4) != b'\xfebin':
			f.seek(0,0) #relay log 就不需要跳过4字节开头了.
		fd.write(b'\xfebin')

		bdata_header = fs.read(19)
		timestamp, event_type, server_id, event_size, log_pos, flags = struct.unpack("<LBLLLh",bdata_header)
		bdata_payload = fs.read(event_size - 19)
		fd.write(bdata_header)
		fd.write(bdata_payload)
		

		CURRENT_TABLE = ""
		CURRENT_DATABASE = ""
		EVENT_LIST = [] #保存解析的BINLOG, 如果 >= 4 就表示有匹配成功的表了. 就写入文件
		while True:
			#read event_header
			bdata_header = fs.read(19)
			if bdata_header == b'' or len(bdata_header) < 19:
				break
			timestamp, event_type, server_id, event_size, log_pos, flags = struct.unpack("<LBLLLh",bdata_header)
			if event_type == 19: #table_map event
				CURRENT_TABLE_MAP_EVENT = []
				bdata_payload = fs.read(event_size - 19)
				CURRENT_DATABASE,CURRENT_TABLE = read_tablename_dbname(bdata_payload)
				if match_table(CURRENT_DATABASE, CURRENT_TABLE):
					EVENT_LIST.append((bdata_header,bdata_payload))
				else:
					fs.seek(log_pos,0)

			elif event_type == 16: #XID_EVENT
				bdata_payload = fs.read(event_size - 19)
				EVENT_LIST.append((bdata_header,bdata_payload))
				if len(EVENT_LIST) >= 4: #event数量足, 说明有匹配上的表
					for event in EVENT_LIST:
						write_event(event[0],event[1],fd)
				EVENT_LIST = [] #置空

			elif event_type == 33: #GTID_EVENT
				bdata_payload = fs.read(event_size - 19)
				EVENT_LIST.append((bdata_header,bdata_payload))

			elif event_type == 30 or event_type == 31 or event_type == 32: #ROW_EVENT
				if match_table(CURRENT_DATABASE, CURRENT_TABLE):
					bdata_payload = fs.read(event_size - 19)
					EVENT_LIST.append((bdata_header,bdata_payload))
				else:
					fs.seek(log_pos,0)

			elif event_type == 35: #给PREVIOUS_GTIDS_LOG_EVENT放个VIP通道 -_-
				bdata_payload = fs.read(event_size - 19)
				write_event(bdata_header,bdata_payload,fd)
			else:
				fs.seek(log_pos,0)

		fs.close()
		fd.close()
	print(OUTPUT_DIR)
