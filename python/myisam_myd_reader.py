#!/usr/bin/env python3
# write by ddcw @https://github.com/ddcw
# 读mysql myisam的myd文件的. 简单的读, 所以不考虑很多信息
import struct

class MYD_READER(object):
	def __init__(self,filename):
		self.f = open(filename,'rb')
	
	def read_int(self,n,signed=True):
		return int.from_bytes(self.f.read(n),'little',signed=signed)

	def read_header(self,n):
		return self.f.read(n)

	def read_varchar(self):
		return self.f.read(self.read_int(1)).decode()

	def read_blob(self,):
		return self.f.read(self.read_int(2)).decode()

	def read_float(self,):
		return struct.unpack('f',self.f.read(4))[0]

	def read_double(self,):
		return struct.unpack('d',self.f.read(8))[0]

	def read_date(self):
		data = self.read_int(3,False)
		year = int(data/(16*32))
		month = int((data-year*16*32)/32)
		day = data - (year*16*32) - (month*32)
		return f"{year}-{month}-{day}"

	def read_datetime(self,):
		"""同ibd里面的datetime, 详情见ibd2sql/innodb_page.py"""
		bdata = self.f.read(5)
		idata = int.from_bytes(bdata[:5],'big')
		year_month = ((idata & ((1 << 17) - 1) << 22) >> 22)
		year = int(year_month/13)
		month = int(year_month%13)
		day = ((idata & ((1 << 5) - 1) << 17) >> 17)
		hour = ((idata & ((1 << 5) - 1) << 12) >> 12)
		minute = ((idata & ((1 << 6) - 1) << 6) >> 6)
		second = (idata& ((1 << 6) - 1))
		return f'{year}-{month}-{day} {hour}:{minute}:{second}'

	def read_time(self,):
		bdata = self.f.read(3)
		idata = int.from_bytes(bdata[:3],'big')
		hour = ((idata & ((1 << 10) - 1) << 12) >> 12)
		minute = (idata & ((1 << 6) - 1) << 6) >> 6
		second = (idata& ((1 << 6) - 1))
		return f'{hour}:{minute}:{second}'

	def read_timestamp(self):
		return self.read_int(4)

	def read_year(self):
		return 1900 + self.read_int(1)

	def read_enum(self):
		pass

	def read_set(self):
		pass

	def read_decimal(self,t1,t2):
		pass # 只做简单的数据类型解析, 因为要精简.

	def read_binary(self,n):
		return "0x"+"".join([ hex(x).split('0x')[-1] for x in self.f.read(n) ])

	def read_varbinary(self):
		return "0x"+"".join([ hex(x).split('0x')[-1] for x in self.f.read(self.read_int(1,False)) ])
