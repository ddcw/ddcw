#!/usr/bin/env python
# -*- coding: utf-8 -*-
# write by ddcw @https://github.com/ddcw
# 拆分 mysqldump 导出的.sql文件 (仅支持库表级过滤)
# 本脚本没有恢复 会话变量, 所以不建议使用 source

import sys,os
import re
import datetime,time
import errno
import argparse,glob

# 解析参数
def _argparse():
	parser = argparse.ArgumentParser(add_help=True, description='拆分 mysqldump 导出的.sql文件.')
	parser.add_argument('--version', '-v', '-V', action='store_true', dest="VERSION", default=False, help='版本信息')
	parser.add_argument('--database', dest="DATABASE", default="*", help='只导入的数据库')
	parser.add_argument('--table', dest="TABLE", default="*", help='只导入的表')
	parser.add_argument('--output-dir', dest="OUTPUT_DIR", default="", help='输出的目录')
	#parser.add_argument('--parallel', dest="PARALLEL", default=4, help='导入并发度')
	parser.add_argument('--presql', dest="PRESQL", default="",  help='每个.sql文件开头部分, 比如 set sql_log_bin=off; set names utf8mb4')
	#parser.add_argument('--postsql', dest="POSTSQL",  help='每个.sql文件结尾部分, 比如 set sql_log_bin=on;')
	#parser.add_argument('--mysqlbin', dest="MYSQLBIN", default="mysql -c ", help='导入时, 使用的mysql命令')
	parser.add_argument('--file', dest="FILENAME", default="", help='要拆分的 mysqldump.sql 文件')
	parser.add_argument('--log-file', dest="LOG_FILENAME", default="", help='日志')
	parser.add_argument("files", nargs="*", help="要拆分的 mysqldump.sql 文件")
	if parser.parse_args().VERSION:
		print('VERSION: v0.1')
		sys.exit(0)
	return parser.parse_args()

#匹配表是否符合要求的
def match_table(dbname,tablename):
	dtname = str(dbname) + "." + tablename
	return True if re.search(PATTERN,dtname) else False

def log(*args):
	msg = str(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")) + " " + " ".join([ str(x) for x in args ]) + "\n"
	print(msg[:-1])
	LOG_FD.write(msg)

def read_header(f):
	client_version = "unknown"
	server_version = "unknown"
	gtid = "" # 兼容5.7
	master_info = ""
	header = ""
	while True:
		old_offset = f.tell()
		data = f.readline()
		if data[:17] == "-- Server version":
			server_version = data.split()[-1:][0]
		elif data[:14] == "-- MySQL dump ":
			client_version = data.split()[5]
		elif data[:21] == "-- GTID state at the ":
			tdata = ""
			f.seek(old_offset,0)
			while True:
				_data = f.readline()
				tdata += _data
				if _data[-2:] == ";\n":
					break
			gtid = tdata
		elif data[:21] == "-- Position to start ":
			tdata = ""
			f.seek(old_offset,0)
			while True:
				_data = f.readline()
				tdata += _data
				if _data[-2:] == ";\n":
					break
			master_info = tdata
		elif data[:3] == "/*!" or data[:4] == "SET ":
			header += data
		elif data[:20] == "-- Current Database:":
			f.seek(old_offset,0)
			break
	return header,client_version,server_version,gtid,master_info

def read_view(f,header,db):
	view_name = "views" + "/" + str(db) + ".sql"
	with open(view_name, 'w') as fd:
		fd.write(header)
		fd.write("USE `"+db+"`;\n")
		while True:
			old_offset = f.tell()
			data = f.readline()
			if data[:3] == "-- " and data[:4] != "-- F":
				f.seek(old_offset,0)
				break
			fd.write(data)

def read_routine(f,header,db):
	routine_filename = "routines"+"/"+str(db)+".sql"
	with open(routine_filename, 'w') as fd:
		fd.write(header)
		data = f.readline()
		data += f.readline()
		fd.write("USE `"+db+"`;\n")
		fd.write(data)
		while True:
			old_offset = f.tell()
			data = f.readline()
			if data[:3] == "--\n":
				#f.seek(old_offset,0)
				break
			elif data[:6] == "SET @@": #issue 2
				break
			fd.write(data)

def read_event(f,header,db):
	event_filename = "events/"+db+".sql"
	with open(event_filename, 'w') as fd:
		fd.write(header)
		data = f.readline()
		data += f.readline()
		fd.write("USE `"+db+"`;\n")
		fd.write(data)
		while True:
			data = f.readline()
			fd.write(data)
			if data == "DELIMITER ;\n" or data[:3] == "--\n":
				break
				
		#data = f.readline()

class NULLPASS(object):
	def __init__(self,*args):
		pass
	def write(self,*args):
		pass

def read_table(f,header,db):
	data = f.readline()
	table_name = re.compile("`(.+)`").findall(data)[0]
	data += "--\n" + f.readline()
	filename = "dbs/" + db + "/" + table_name + ".sql"
	with open(filename,'w') as fd:
		if not match_table(db,table_name):
			#log(db+"."+table_name+" NOT MATCH "+PATTERN+" SKIP IT!")
			fd = NULLPASS()
		fd.write(header)
		fd.write(data)
		fd.write("USE `"+db+"`;")
		#读表结构
		while True:
			data = f.readline()
			fd.write(data)
			if data == "--\n":
				break

		#读数据
		old_offset = f.tell()
		data = f.readline()
		if data[:26] == "-- Dumping data for table ":
			data += f.readline() + f.readline()
			fd.write(data)
			while True:
				data = f.readline()
				fd.write(data)
				if data == "--\n": #可能有触发器, 所以不能以UNLOCK TABLES;结束
					break
				elif data[:3] == "-- ":
					break
		else:
			f.seek(old_offset,0)
	return True
				

# 建目录
def mkdir_exists(dirname):
	try:
		os.makedirs(dirname)
	except OSError as e:
		if e.errno != errno.EEXIST:
			raise

if __name__ == '__main__':
	START_TIME = time.time()
	parser = _argparse()
	FILTER_DATABASE = parser.DATABASE
	FILTER_TABLE = parser.TABLE
	PATTERN = str(FILTER_DATABASE).replace("*",".*") + "\." + str(FILTER_TABLE).replace("*",".*")
	filelist = []
	for pattern in parser.files:
		filelist += glob.glob(pattern)
	fileset = filelist
	FILENAME = parser.FILENAME if parser.FILENAME != "" and os.path.exists(parser.FILENAME) else ""
	FILENAME = fileset[0] if len(fileset) >= 1 and FILENAME == "" and os.path.exists(fileset[0]) else ""
	if FILENAME == "":
		print('At least one binlog file')
		sys.exit(1)

	FILENAME = os.path.abspath(FILENAME) # 设置为绝对路径, 因为后面要切换rootdir
	LOG_FILENAME = "SplitMysqlDumpSQL.log" if parser.LOG_FILENAME == "" else parser.LOG_FILENAME
	LOG_FILENAME = os.path.abspath(LOG_FILENAME)

	OUTPUT_DIR = parser.OUTPUT_DIR if parser.OUTPUT_DIR != "" else "splitByddcw_" + str(datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))
	OUTPUT_DIR = os.path.abspath(OUTPUT_DIR)
	#print("READ FILENAME: "+FILENAME+" OUTPUT_DIR: "+OUTPUT_DIR)
	mkdir_exists(OUTPUT_DIR)
	# 不检查空间是否足够了(lazy), 要自行检查(要求1.1倍.sql文件大小)

	# 创建相关目录
	os.chdir(OUTPUT_DIR) # 切换工作目录, 懒得去拼接目录了....
	mkdir_exists("dbs")       #库表信息
	mkdir_exists("events")    #event
	#mkdir_exists("triggers")  #触发器
	mkdir_exists("routines")  #存储过程和函数
	mkdir_exists("views")      #单独的view(Final view structure)  不含Temporary table structure for view

	f = open(FILENAME,'r')
	LOG_FD = open(LOG_FILENAME,'a')
	CREATE_DB_FD = open('dbs/create.sql','w') #建库语句
	FILE_HEADER,client_version,server_version,gtid_info,master_info = read_header(f)
	CREATE_DB_FD.write(FILE_HEADER)
	CREATE_DB_FD.write("\n")
	FILE_HEADER = "-- AUTO SPLIT MYSQLDUMP FILE BY DDCW @https://github.com/ddcw\n" + FILE_HEADER + "\n" + parser.PRESQL + "\n"
	_msg = "CLIENT_VERSION: " + client_version + "  SERVER_VERSION: " + server_version + "FILE_HEADER:\n" + FILE_HEADER
	log(_msg)
	# 写change master
	if master_info != "":
		_master_file = "dbs/master_info.txt"
		with open(_master_file, 'w') as _mf:
			_mf.write(master_info)

	# 读库表信息
	CURRENT_DB = ""
	TABLE_COUNT = 0
	WARNING_COUNT = 0
	while True:
		old_offset = f.tell()
		data = f.readline()
		if data == "": #读完了.
			break
		elif data[:20] == "-- Current Database:":
			CURRENT_DB = re.compile("`(.+)`").findall(data)[0]
			_dirname = "dbs/" + str(CURRENT_DB)
			mkdir_exists(_dirname)
		elif data[:16] == "CREATE DATABASE ":
			CREATE_DB_FD.write(data)
		#CREATE TABLE, INSERT, CREATE TRIGGER, CREATE VIEW
		elif data[:28] == "-- Table structure for table" or data[:36] == "-- Temporary view structure for view" or data[:37] == "-- Temporary table structure for view":
			TABLE_COUNT += 1
			f.seek(old_offset,0)
			table_name = re.compile("`(.+)`").findall(data)[0]
			log("READ TABLE FOR "+CURRENT_DB+"."+table_name,'BEGIN')
			_st = time.time()
			read_table(f,FILE_HEADER,CURRENT_DB)
			_et = time.time()
			log("READ TABLE FOR "+CURRENT_DB+"."+table_name,"FINISH.","COST TIME: "+ str(round((_et-_st),2)) +" seconds")

		#READ EVENT
		elif data[:31] == "-- Dumping events for database ":
			CURRENT_DB = re.compile("'(.+)'").findall(data)[0]
			f.seek(old_offset,0)
			log("READ EVENT FOR DATABASE "+CURRENT_DB+" BEGIN")
			_st = time.time()
			read_event(f,FILE_HEADER,CURRENT_DB)
			_et = time.time()
			log("READ EVENT FOR DATABASE "+CURRENT_DB+" FINISH","COST TIME: "+ str(round((_et-_st),2)) +" seconds")
			

		#READ ROUTINE
		elif data[:33] == "-- Dumping routines for database ":
			CURRENT_DB = re.compile("'(.+)'").findall(data)[0]
			f.seek(old_offset,0)
			log("READ ROUTINE FOR DATABASE "+CURRENT_DB+" BEGIN")
			_st = time.time()
			read_routine(f,FILE_HEADER,CURRENT_DB)
			_et = time.time()
			log("READ ROUTINE FOR DATABASE "+CURRENT_DB+" FINISH","COST TIME: "+ str(round((_et-_st),2)) +" seconds")

		#READ VIEW
		elif data[:33] == "-- Final view structure for view ":
			f.seek(old_offset,0)
			log("READ VIEW FOR DATABASE "+CURRENT_DB+" BEGIN")
			_st = time.time()
			read_view(f,FILE_HEADER,CURRENT_DB)
			_et = time.time()
			log("READ VIEW FOR DATABASE "+CURRENT_DB+" FINISH","COST TIME: "+ str(round((_et-_st),2)) +" seconds")

		elif data[:21] == "-- GTID state at the ":
			tdata = ""
			f.seek(old_offset,0)
			log("READ GTID PURGED")
			while True:
				_data = f.readline()
				tdata += _data
				if _data[-2:] == ";\n":
					break
			gtid_info += tdata
		elif data[:26] == "-- Dumping data for table ": #系统库, 主要是统计信息
			# ONLY FOR MYSQL 8.x
			_filename = "dbs/special.sql"
			with open(_filename,'a') as fd:
				fd.write(FILE_HEADER)
				fd.write("\n")
				fd.write(data)
				fd.write("USE `"+CURRENT_DB+"`;\n")
				while True:
					_old_offset = f.tell()
					data = f.readline()
					if data[:3] == "-- ":
						f.seek(_old_offset,0)
						break
					fd.write(data)
		elif data[:20] == "-- Dump completed on":
			log("READ ALL FINISH")
			break
		elif data[:4] == "USE " or data == "\n" or data == "--\n":
			pass
		elif data[:3] == "/*!" or data[:4] == "SET ": #跳过结尾的注释和一些set
			pass
		else:
			WARNING_COUNT += 1
			log("========== SKIP ==========\n"+data)


	# 写 gtid信息, 5.7 在结尾, 所以后写
	if gtid_info != "":
		_gtid_file = "dbs/gtid.sql"
		with open(_gtid_file, 'w') as _mf:
			_mf.write(FILE_HEADER)
			_mf.write("\n")
			_mf.write(gtid_info)
	STOP_TIME = time.time()
	log("FILENAME     :",FILENAME)
	log("OUTPUT_DIR   :",OUTPUT_DIR)
	log("LOG_FILENAME :",LOG_FILENAME)
	log("COST TIME    :",str(round((STOP_TIME - START_TIME),2)), "SECONDS.  TABLES COUNT:",TABLE_COUNT)
	log("WARNING      :",WARNING_COUNT)
	f.close()
	LOG_FD.close()
	CREATE_DB_FD.close()
