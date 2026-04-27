#!/usr/bin/env python3
# mysql: checksum table tblname;

import datetime
import argparse
import binascii
import struct
import time
import sys

def _argparse():
	parser = argparse.ArgumentParser(add_help=False,description="实现mysql的checksum table功能,可自行扩展到其它数据库")
	parser.add_argument("--help",action="store_true",dest="HELP",default=False,help="show help")
	parser.add_argument("--version","-v",action="store_true",dest="VERSION",default=False,help="show version")
	parser.add_argument("--host","-h",dest="HOST",default='127.0.0.1',help="mysql server host")
	parser.add_argument("--port","-P",dest="PORT",type=int,default=3306,help="mysql server port")
	parser.add_argument("--user","-u",dest="USER",default='root',help="mysql user")
	parser.add_argument("--password","-p",dest="PASSWORD",help="mysql user's password")
	parser.add_argument("--databases","-d","-D",dest="DATABASE",help="default database")
	parser.add_argument("--table-schema","--schema",dest="SCHEMA_NAME",help="table_schema(mysql's database name)")
	parser.add_argument("--table-name","--table","--name",dest="TABLE_NAME",help="table_name")
	parser.add_argument("--parallel",dest="PARALLEL",type=int,help="parallel")
	if parser.parse_args().VERSION:
		print('checksum_table_mysql v0.1_beta')
		sys.exit(0)
	if parser.parse_args().HELP:
		parser.print_help()
		sys.exit(0)
	parser = parser.parse_args()
	return parser
	

# mysql协议返回的数据都是char格式,所以还得转为二进制去计算
def int8tobdata(data):
	return struct.pack('<b',data)

def uint8tobdata(data):
	return struct.pack('<B',data)

def int16tobdata(data):
	return struct.pack('<h',data)

def uint16tobdata(data):
	return struct.pack('<H',data)

def int24tobdata(data):
	return data.to_bytes(3,'little',signed=True)

def uint24tobdata(data):
	return data.to_bytes(3,'little',signed=False)

def int32tobdata(data):
	return struct.pack('<l',data)

def uint32tobdata(data):
	return struct.pack('<L',data)

def int64tobdata(data):
	return struct.pack('<q',data)

def uint64tobdata(data):
	return struct.pack('<Q',data)

def float2bdata(data):
	return struct.pack('f',data)

def double2bdata(data):
	return struct.pack('d',data)

def map_decimal(n):
	return [ [4,9] for _ in range(n//9) ] + ([[ ((n%9)+1)//2 if n%9 < 7 else 4,n%9 ]] if n%9 > 0 else [])

# p1:整数 p2:小数
def decimal2bdata(data,p1,p2,p11,p22):
	rdata = b''
	if isinstance(data,str):
		dp1,dp2 = data.split('.')
	else:
		if p11 == 0:
			dp1 = ""
			dp2 = f"{data:f}".split('.')[1]
		elif p22 == 0:
			dp1 = f"{data:f}"
			dp2 = ""
		else:
			dp1,dp2 = f"{data:f}".split('.')
	signed = False
	if dp1.startswith('-'):
		dp1 = dp1[1:]
		signed = True
	dp1 = dp1.rjust(p11,'0')
	dp2 = dp2.ljust(p22,'0')
	dp = dp1 + dp2
	c = 0
	for x in p1+p2:
		t = dp[c:c+x[1]]
		c += x[1]
		rdata += int(t).to_bytes(x[0],'big')
	rdata = bytearray(rdata)
	rdata[0] |= 128
	if signed:
		rdata = bytes(b^0xff for b in rdata)
	return rdata

def enum2bdata(data,m):
	if isinstance(data,bytes):
		return data
	return m[data]

def set2bdata(data,m,p):
	rdata = 0
	for x in data.split(','):
		if x == '':
			break
		rdata|=m[x]
	return rdata.to_bytes((p+7)//8,'big')[::-1]

def date2bdata(data):
	if isinstance(data,int):
		return b'\x00\x00\x00'
	elif isinstance(data,str): # python的datetime的Year不能是0
		year,month,day = [ int(x) for x in data.split('-') ] 
		year = year << 9
		month = month << 5
	else:
		year = data.year << 9
		month = data.month << 5
		day = data.day
	#return struct.pack('>L',signed|year|month|day)[1:] # 符号位固定为1,即均为正日期
	rdata = bytearray(struct.pack('<L',year|month|day)[:-1])
	return rdata
	#return struct.pack('>L',year|month|day)[1:][::-1] # 存储上有符号, 实际上没使用...

# 时间相关的都是大端字节序(没得字节序)
def timestamp2bdata(data,pad=None):
	# 整数部分4字节, 加上小数部分(填充为固定的字节)
	if isinstance(data,str): # fix python no datetime when '0000-00-00 00:00:00'
		return struct.pack('>L',0) + int(0).to_bytes(pad,'big') if pad is not None else b''
	return struct.pack('>L',int(data.timestamp())) + data.microsecond.to_bytes(pad,'big') if pad is not None else b''

def time2bdata(data,pad=None):
	# 整数部分3字节, 加上小数部分
	#if isinstance(data,str): 时间的0也是有意义的
	#	return b'\x00\x00\x00'+int(0).to_bytes(pad,'big') if pad is not None else b''
	seconds = data.seconds
	microseconds = str(data.microseconds)
	if data.days < 0:
		signed = 0<<23
		seconds = 86400 - seconds
	else:
		signed = 1<<23
	second = seconds%60
	minute = ((seconds%3600)//60)<<6
	hour = (seconds//3600)<<12
	if data.days >=0:
		return (signed|hour|minute|second).to_bytes(3,'big') + int(microseconds[:pad*2]).to_bytes(pad,'big') if pad is not None and pad != 0 else b''
	else:
		return (2**24-2**23-(hour|minute|second)).to_bytes(3,'big') + int(microseconds).to_bytes(pad,'big') if pad is not None else b''

def datetime2bdata(data,pad=None):
	if isinstance(data,str): # datetime是固定有符号位的...
		return b'\x80\x00\x00\x00\x00'+int(0).to_bytes(pad,'big') if pad is not None else b''
	signed = 1<<39
	year_month = (data.year*13+data.month)<<22
	day = data.day<<17
	hour = data.hour<<12
	minute = data.minute<<6
	second = data.second
	return (signed|year_month|day|hour|minute|second).to_bytes(5,'big') + data.microsecond.to_bytes(pad,'big') if pad is not None else b''

def year2bdata(data):
	return uint8tobdata(data-1900)

def encodegbk(data):
	return data.encode('gbk')

def encodeutf8(data):
	return data.encode('utf-8')

def encodebig5(data):
	return data.encode('big5')

def encodelatin1(data):
	return data.encode('latin1')

def encodelatin2(data):
	return data.encode('iso8859-2')

def encodelatin5(data):
	return data.encode('iso8859-9')

def encodelatin7(data):
	return data.encode('iso8859-13')

class MYSQL_CHECKSUM(object):
	def __init__(self,conn,table_schema,table_name):
		self.conn = conn
		self.table_schema = table_schema
		self.table_name = table_name
		self.pack_record = False
		self.column_count = 0
		self.last_null_bit_pos = 0
		self.init()

	def init(self,pack_record=False):
		"""初始化字段相关信息 order by ORDINAL_POSITION"""
		sql = f"select COLUMN_NAME,IS_NULLABLE,DATA_TYPE,COLUMN_TYPE,CHARACTER_SET_NAME,NUMERIC_PRECISION,NUMERIC_SCALE,DATETIME_PRECISION,CHARACTER_OCTET_LENGTH,COLUMN_DEFAULT from information_schema.columns where table_schema='{self.table_schema}' and table_name='{self.table_name}' order by ORDINAL_POSITION asc;"
		cursor = self.conn.cursor()
		cursor.execute(sql)
		columns = cursor.fetchall()
		cursor.close()
		self.columns = []
		self.column_count = len(columns)
		for col in columns:
			column = {}
			column['name'],column['nullable'],column['type'],column['col_type'],column['charset'],column['num_p'],column['num_s'],column['datetime_p'],column['pad'],column['default'] = col
			column['encode'] = None
			column['args'] = []
			column['is_binary'] = False
			column['wherenull'] = None # 定长类型为null时使用的默认值
			# 数字类型
			if column['type'] == 'int':
				column['encode'] = uint32tobdata if column['col_type'].endswith('unsigned') else int32tobdata
				column['wherenull'] = 0
			elif column['type'] == 'tinyint':
				column['encode'] = uint8tobdata if column['col_type'].endswith('unsigned') else int8tobdata
				column['wherenull'] = 0
			elif column['type'] == 'smallint':
				column['encode'] = uint16tobdata if column['col_type'].endswith('unsigned') else int16tobdata
				column['wherenull'] = 0
			elif column['type'] == 'mediumint':
				column['encode'] = uint24tobdata if column['col_type'].endswith('unsigned') else int24tobdata
				column['wherenull'] = 0
			elif column['type'] == 'bigint':
				column['encode'] = uint64tobdata if column['col_type'].endswith('unsigned') else int64tobdata
				column['wherenull'] = 0
			elif column['type'] == 'float':
				column['encode'] = float2bdata
				column['wherenull'] = 0
			elif column['type'] == 'double':
				column['encode'] = double2bdata
				column['wherenull'] = 0
			elif column['type'] == 'decimal':
				column['encode'] = decimal2bdata
				p1 = map_decimal(column['num_p']-column['num_s'])
				_ = p1.reverse()
				p2 = map_decimal(column['num_s'])
				column['args'] = [p1, p2,column['num_p']-column['num_s'],column['num_s']]
				column['wherenull'] = '0.0'
			# 时间类型
			elif column['type'] == 'timestamp': # now() when default
				column['encode'] = timestamp2bdata
				column['args'] = [(column['datetime_p']+1)//2]
				column['wherenull'] = '0'
			elif column['type'] == 'date':
				column['encode'] = date2bdata
				column['wherenull'] = 0
			elif column['type'] == 'time':
				column['encode'] = time2bdata
				column['args'] = [(column['datetime_p']+1)//2]
				column['wherenull'] = datetime.timedelta(seconds=0)
			elif column['type'] == 'datetime':
				column['encode'] = datetime2bdata
				column['args'] = [(column['datetime_p']+1)//2]
				column['wherenull'] = '0'
			elif column['type'] == 'year':
				column['encode'] = year2bdata
				column['wherenull'] = 1900
			# enum/set使用的是position而不是实际值
			elif column['type'] == 'enum':
				column['encode'] = enum2bdata
				tdata = [s.strip("'") for s in column['col_type'][5:-1].split(',')]
				tl = len(tdata)
				t2data = {}
				for i in range(tl):
					t2data[tdata[i]] = (i+1).to_bytes((tl+255)//256,'big')
				column['args'] = [t2data]
				column['wherenull'] = b'\x00'*((tl+255)//256)
			elif column['type'] == 'set':
				column['encode'] = set2bdata
				tdata = [s.strip("'") for s in column['col_type'][4:-1].split(',')]
				tl = len(tdata)
				t2data = {}
				for i in range(tl):
					t2data[tdata[i]] = 1<<i
				column['args'] = [t2data,tl]
				column['wherenull'] = ''
			# 字符类型涉及到编码
			elif column['type'] in ['char','varchar','enum','longtext','mediumtext','set','text','tinytext','json']:
				if column['type'] != 'char':
					self.pack_record = True
				# 太小众的编码我们就不写了,毕竟本脚本只是script,而不是proj
				if column['charset'] in ['utf8mb4','utf8','utf8mb3','ascii']:
					column['encode'] = encodeutf8
				elif column['charset'] == 'latin1':
					column['encode'] = encodelatin1
				elif column['charset'] == 'latin2':
					column['encode'] = encodelatin2
				elif column['charset'] == 'latin5':
					column['encode'] = encodelatin5
				elif column['charset'] == 'latin7':
					column['encode'] = encodelatin7
				elif column['charset'] == 'gbk':
					column['encode'] = encodegbk
				elif column['charset'] == 'big5':
					column['encode'] = encodebig5
				elif column['type'] == 'json': # 虽然dd里面记录的collation_id=63,但实际上是使用的utf8
					column['encode'] = encodeutf8
				else:
					print('unknown charset',column['charset'])
					raise('unknown charset',column['charset'])
				if column['type'] == 'json': # {m_ptr = 0x7f7dc40ae2d0 "null", m_length = 4, m_charset = 0x6c77420 <my_charset_utf8mb4_bin>, m_alloced_length = 8
					column['wherenull'] = 'null' # 没想到吧,json是null字符串
			# 二进制类型不需要编码 
			elif column['type'] in ['blob','tinyblob','mediumblob','longblob','varbinary','binary','bit','geometry','point','linestring','polygon','geomcollection','multipoint','multilinestring','multipolygon','geometrycollection']:
				if column['type'] not in ['binary','bit']:
					self.pack_record = True
				column['is_binary'] = True
				if column['type'] == 'binary':
					column['wherenull'] = b'\x00'*column['pad']
				elif column['type'] == 'bit':
					column['wherenull'] = b'\x00'*column['num_p']
			# 其它类型目前不支持
			else:
				print("unknown type "+column['type'])
				raise "unknown type "+column['type']
			self.columns.append(column)
			if column['nullable'] == 'YES':
				self.last_null_bit_pos += 1

			# 填充默认值, 定长需要补全, char使用' '填充, 如果字段为null,则使用默认值,若默认值为null则跳过
		cursor = self.conn.cursor()
		cursor.execute(f"select ROW_FORMAT,CREATE_OPTIONS from information_schema.tables where table_schema='{self.table_schema}' and table_name='{self.table_name}';")
		data = cursor.fetchall()
		cursor.close()
		# if (create_info->row_type == ROW_TYPE_DYNAMIC) create_info->table_options |= HA_OPTION_PACK_RECORD
		if data[0][1] is not None and data[0][1].find('row_format=DYNAMIC') >= 0: # 显式定义row_format=DYNAMIC
			self.pack_record = True
		if data[0][0] == 'Fixed':
			self.pack_record = False

		#self.null_bytes = (self.last_null_bit_pos+7)//8
		self.last_null_bit_pos += 0 if self.pack_record else 1
		self.null_bytes = (self.last_null_bit_pos+7)//8
		self.last_null_bit_pos &= 7

	def is_view(self): # 视图的没必要校验,当然也可以校验,但意义不大...
		cursor = self.conn.cursor()
		cursor.execute(f"select table_schema,table_name,table_type from information_schema.tables where table_schema='{self.table_schema}' and table_name='{self.table_name}' and table_type='BASE TABLE'")
		data = cursor.fetchall()
		cursor.close()
		return True if len(data) == 0 else False

	def get_checksum(self,pack_record=None):
		"""
			如果有varchar/text等变长类型, 则pack_record=True
			如果显示定义的row_format=dynamic, 则则pack_record=True
			但有些数据库不管这个显示定义.... 所以我们得支持手动选择...
		"""
		if self.is_view():
			return {'checksum':'NULL','crc32sum':'NULL','row_count':'NULL'}
		crc = 0
		row_count = 0
		cursor = self.conn.cursor()
		cursor.execute(f"select {','.join([ '`'+x['name']+'`' for x in self.columns ])} from `{self.table_schema}`.`{self.table_name}`")
		if pack_record is None:
			pack_record = self.pack_record
		# 可以cn负责取数,worker负责crc32,最后在汇总下
		last_null_bit_pos = self.last_null_bit_pos
		null_bytes = self.null_bytes
		null_mask = 256 -  (1 << last_null_bit_pos)
		while True: # fetchone不支持多线程, 就没法并发了, 后面我自己写个支持并发的吧..
			row = cursor.fetchone()
			if row is None:
				break
			row_count += 1
			row_crc32 = 0
			# calc null_bitmask
			null_org = -1 if pack_record else 0
			null_bitmask_int = 2**(null_bytes*8)-1
			for x in range(self.column_count):
				if self.columns[x]['nullable'] == 'YES':
					null_org += 1
					if row[x] is not None:
						null_bitmask_int -= 1<<null_org
			
			null_bitmask_bin = bytearray(null_bitmask_int.to_bytes(null_bytes,'little'))
			if null_bytes:
				null_bitmask_bin[null_bytes-1] |= null_mask
				if not pack_record:
					null_bitmask_bin[0] |= 1
			row_crc32 = binascii.crc32(null_bitmask_bin)
			#print('\nINIT_CRC32:',row_crc32,null_bitmask_bin,null_bytes)
			# calc crc32
			for x in range(self.column_count): # char需要pad
				if self.columns[x]['type'] == 'char':
					if row[x] is None: # char即使是null,也会使用' '填充
						data = ' '*self.columns[x]['pad']
					else:
						data = row[x].ljust(self.columns[x]['pad'])
				elif row[x] is None: # 定长字符存在为空时使用默认值的情况
					data = self.columns[x]['wherenull']
				else:
					data = row[x]
				if data is None: # varchar之类的为null就看默认值, 默认值为空就跳过
					if self.columns[x]['default'] is None:
						continue
					else:
						data = self.columns[x]['default']
				#print(data,self.columns[x]['encode'](data,*self.columns[x]['args']) if  not self.columns[x]['is_binary'] else data )
				row_crc32 = binascii.crc32(self.columns[x]['encode'](data,*self.columns[x]['args']) if not self.columns[x]['is_binary'] else data,row_crc32)
				#print(row_crc32,data,self.columns[x]['encode'](data,*self.columns[x]['args']))
			crc += row_crc32
		cursor.close()
		return {'checksum':crc&4294967295,'crc32sum':crc,'row_count':row_count}

if __name__ == '__main__':
	parser = _argparse()
	# 本版本是mysql的, 所以驱动使用mysql的, 其它的请自行替换
	import pymysql
	conn = pymysql.connect(
		host=parser.HOST,
		port=parser.PORT,
		user=parser.USER,
		password=parser.PASSWORD,
		database=parser.DATABASE
	)
	# 如果没有指定table-schema或者table-name的话,就从数据库里面获取.
	schema_table = []
	if parser.SCHEMA_NAME is None and parser.DATABASE is not None:
		parser.SCHEMA_NAME = parser.DATABASE
	if parser.SCHEMA_NAME is None or parser.TABLE_NAME is None:
		where = ""
		if parser.SCHEMA_NAME is None and parser.TABLE_NAME is not None:
			where = f"table_name='{parser.TABLE_NAME}'"
		elif parser.SCHEMA_NAME is not None and parser.TABLE_NAME is None:
			where = f"table_schema='{parser.SCHEMA_NAME}'"
		else:
			where = f"table_schema='{parser.SCHEMA_NAME}' and table_name='{parser.TABLE_NAME}'"
		sql = f"select table_schema,table_name from information_schema.tables where {where}"
		cursor = conn.cursor()
		cursor.execute(sql)
		data = cursor.fetchall()
		for x1,x2 in data:
			schema_table.append([x1,x2])
		cursor.close()
	else:
		# 校验表是否存在
		cursor = conn.cursor()
		cursor.execute(f"select table_schema,table_name from information_schema.tables where table_schema='{parser.SCHEMA_NAME}' and table_name='{parser.TABLE_NAME}'")
		data = cursor.fetchall()
		if len(data) == 0:
			print(f"{parser.SCHEMA_NAME}.{parser.TABLE_NAME} 不存在")
			sys.exit(1)
		schema_table.append([parser.SCHEMA_NAME,parser.TABLE_NAME])
	for schema,table in schema_table:
		print(f"Table:{schema}.{table}\t",end='',flush=True)
		start_time = time.time()
		aa = MYSQL_CHECKSUM(conn,schema,table)
		rs = aa.get_checksum()
		print(f"Checksum:{rs['checksum']}\tTotal_Checksum:{rs['crc32sum']}\tRows:{rs['row_count']}\tCost:{round(time.time()-start_time,2)} sec")
	conn.close()
