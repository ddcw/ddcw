# -*- coding: utf-8 -*-
#解析指定binlog文件生成ddl. 仅支持binlog > 4.0
#也可以使用mysqlbinlog解析(但是不完整...): mysqlbinlog /data/mysql_3308/mysqllog/binlog/m3308.0* | grep -i -E '^(CREATE |DROP |ALTER |RENAME |TRUNCATE |USE )'

import struct
import os,sys,glob
import datetime

QUERY_EVENT = 2 #ddl只有这一个event

def print_help():
	print('version: 0.1')
	print('example:')
	print(f'\t{sys.argv[0]} mysql-bin.0000022 [CHECK:BOOL]')
	print(f'\t{sys.argv[0]} mysql-bin.000002* [CHECK:BOOL]')
	print('')
	sys.exit(1)

if len(sys.argv) < 2 or sys.argv[1] in ['-h','--help','-help','-v','-V','--version','-version']:
	print_help()

files = glob.glob(sys.argv[1])
if len(files) == 0:
	print(f'{sys.argv[1]} not exists or have file')


checksum = True if len(sys.argv) > 2 else False 


def event_header(bdata):
	timestamp, event_type, server_id, event_size, log_pos, flags = struct.unpack("<LBLLLh",bdata[0:19])
	return {"timestamp":timestamp,'event_type':event_type,'server_id':server_id,'event_size':event_size,'log_pos':log_pos,'flags':flags,}

def parserfile(filename):
	with open(filename,'rb') as f:
		magic = f.read(4)
		if magic != b'\xfebin': #relay log
			f.seek(0,0)
		while True:
			bheader = f.read(19)
			if bheader == b'':
				break
			header = event_header(bheader)
			event_bdata = f.read(header['event_size']-19)
			if header['event_type'] == QUERY_EVENT:
				#print(event_bdata)
				slave_proxy_id, execution_time, schema_len, error_code, status_var_len = struct.unpack('<LLBHH',event_bdata[:13])
				#offset = 4+4+1+2+2 + status_var_len
				offset = 13 + status_var_len 
				schema = event_bdata[offset:offset+schema_len].decode()
				offset += schema_len + 1 #\x00
				if checksum:
					ddl = event_bdata[offset:-4].decode()
				else:
					ddl = event_bdata[offset:].decode()
				#print(schema,ddl)
				if ddl != 'BEGIN' and schema != '':
					print(f"#START:{f.tell()-header['event_size']}  SIZE:{header['event_size']} TIME:{datetime.datetime.fromtimestamp(header['timestamp'])}")
					print(f'USE {schema};')
					print(f'{ddl};')
					print('')
				
				
for binlogname in files:
	parserfile(binlogname)


