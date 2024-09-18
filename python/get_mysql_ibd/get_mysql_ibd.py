import struct,json,zlib
from ibd2sql.innodb_page_sdi import *
from ibd2sql import __version__
from ibd2sql.ibd2sql import ibd2sql
import sys,os



PAGE_NEW_INFIMUM = 99
if len(sys.argv)!=2:
	print('USAGE: python3 get_mysql_ibd.py /data/mysql.ibd')
	sys.exit(2)
filename = sys.argv[1]
if not os.path.exists(filename):
	print(filename,' not exists')
	sys.exit(1)
f = open(filename,'rb')
data = f.read(16384)
# fsp的记录对应general tablespace是没得用的, 但出于礼貌, 我们还是给它留2行代码
sdi_version,sdi_pageno = struct.unpack('>II',data[150+40*256:150+40*256+8])

# inode
f.seek(16384*2,0)
data = f.read(16384)
sdi_segment = data[50:50+192*2]
sdi_leaf_pageno = struct.unpack('>L',sdi_segment[192:][64:68])[0]

# SDI
dd = {}
while sdi_leaf_pageno < 4294967295:
	_ = f.seek(16384*sdi_leaf_pageno,0)
	data = f.read(16384)
	sdi_leaf_pageno = struct.unpack('>L',data[12:16])[0]
	offset = PAGE_NEW_INFIMUM + struct.unpack('>H',data[97:99])[0]
	while True:
		offset += struct.unpack('>h',data[offset-2:offset])[0] # 注意是有符号的. 但不涉及到数据修改, 其实也无所谓
		if offset > 16384 or offset == 112:
			break
		sdi_type,id = struct.unpack('>LQ',data[offset:offset+12])
		trx1,trx2,undo1,undo2,undo3 = struct.unpack('>LHLHB',data[offset+12:offset+25])
		trx = (trx1<<16) + trx2
		undo = (undo1<<24) + (undo2<<8) + undo3
		dunzip_len,dzip_len = struct.unpack('>LL',data[offset+25:offset+33])
		unzbdata = zlib.decompress(data[offset+33:offset+33+dzip_len])
		dic_info = json.loads(unzbdata.decode())
		dd[dic_info['dd_object']['name']] = dic_info

f.close()




class sdi2(sdi):
	def __init__(self,*args,**kwargs):
		super().__init__(*args,**kwargs)
		self.dd = kwargs['dd']
		self.table = TABLE()
		self._init_table()
		self.table._set_name()
	def get_dict(self):
		return self.dd

class ibd2sql2(ibd2sql):
	def init(self,):
		self.f = open(self.FILENAME,'rb')
		self.PAGE_ID = 2
		self.first_no_leaf_page = 82
		self.first_leaf_page = 0

for name in dd:
	try:
		aa = sdi2(b'\x00'*16384,dd=dd[name]) # 有空了再改, 先临时用着.... # 其实就是最后一个对象(mysql, 不是表, 即没得mysql.mysql)
	except:
		continue
	ddcw = ibd2sql2()
	#ddcw.DEBUG = True
	ddcw.FILENAME = filename
	ddcw.IS_PARTITION = True
	ddcw.table = aa.table
	#ddcw.DELETE = False # 不要deleted的数据
	ddcw.table.FOREIGN = False # 去掉外键, 外键的schema没有做替换, 还是依赖的mysql的哇
	ddcw.replace_schema('ddcw') # 替换schema,方便导入数据库
	ddcw._init_table_name()
	ddcw.init()
	ddcw.first_no_leaf_page = int(dict([ y.split('=') for y in dd[name]['dd_object']['indexes'][0]['se_private_data'].split(';')[:-1]])['root'])
	try:
		ddcw.init_first_leaf_page()
		print(ddcw.get_ddl()) # 打印DDL
		sql = ddcw.get_sql()
		if sql is not None:
			print(sql)  # 打印数据
	except:
		pass

