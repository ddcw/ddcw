#!/usr/bin/env python
# -*- coding: utf-8 -*-
#解析binlog得到事务大小, python2和python3 均适用
# binlog_cache_size 对4KB取整
# python binlog_trx_4kf.py  mysql-bin.000002

import argparse,glob,struct,datetime,time
import sys,os

def _argparse():
	parser = argparse.ArgumentParser(add_help=True, description='解析binlog/relay log 获取事务大小')
	parser.add_argument('--version', '-v', '-V', action='store_true', dest="VERSION", default=False, help='Show version')
	parser.add_argument("files", nargs="*", help="binlog/relay log list. support RE")
	if parser.parse_args().VERSION:
		print('VERSION: v0.2')
		sys.exit(0)
	return parser.parse_args()

def gettrxfrombinlog(filename,TRX,MAX_TRX):
	offset = 0
	with open(filename,'rb') as f:
		if f.read(4) != b'\xfebin':
			f.seek(0,0)
		while True:
			bdata = f.read(19)
			if bdata == b'':
				break
			timestamp, event_type, server_id, event_size, log_pos, flags = struct.unpack("<LBLLLh",bdata[0:19])
			f.seek(event_size-19,1) #数据就不读了
			if event_type == 33: #BEGIN GTID_EVENT
				offset = f.tell()
			elif event_type == 16: #commit XID_EVENT
				size = f.tell() - offset
				size = int(size/4096)
				if size > MAX_TRX:
					TRX[MAX_TRX] += 1
				else:
					TRX[size] += 1
	return TRX

if __name__ == '__main__':
	parser = _argparse()
	filelist = []
	for pattern in parser.files:
		filelist += glob.glob(pattern)
	fileset = set(filelist)
	if len(fileset) == 0:
		print('At least one binlog file')
		sys.exit(1)
	
	MAX_TRX = 1*256 #256 * 4KB
	TRX = [ 0 for x in range(MAX_TRX) ] #初始化事务大小列表. 对1KB取整
	TRX.append(0) #添加超过范围的计数
	for filename in fileset:
		TRX = gettrxfrombinlog(filename,TRX,MAX_TRX)
	for idx,val in enumerate(TRX):
		if val>0:
			print(str((idx+1)*4) + " KB以内的事务数量: " + str(val) if idx < MAX_TRX else "超过 " + str(idx*4) + " KB的事务数量: " + str(val)) #python2如果收到的是元组的话, 就不支持中文
