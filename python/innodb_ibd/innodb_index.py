#解析 FIL_PAGE_INDEX
import struct
import innodb_page_type
import innodb_file

import zlib,json

PAGE_SIZE = 16384

FIL_PAGE_DATA = 38
FIL_PAGE_DATA_END = 8

PAGE_NEW_INFIMUM = 99
PAGE_NEW_SUPREMUM = 112


PAGE_DIR_SLOT_MAX_N_OWNED = 8
PAGE_DIR_SLOT_MIN_N_OWNED = 4

REC_N_FIELDS_ONE_BYTE_MAX = 0x7F #超过(>)这个值, 就使用2字节 (就是第 1 bit位 标记是否使用2字节)

innodb_page_name = {}
for x in dir(innodb_page_type):
	if x[:2] != '__':
		innodb_page_name[getattr(innodb_page_type,x)] = x

def fseg_header(bdata):
	return struct.unpack('>LLH',bdata[:10])

def read_var_len(bdata,start):
	pass


#没找到sdi的结构, 但是发现它是压缩的, 所以我们使用暴力解压获取sdi数据吧....
#However, SDI data is compressed to reduce the storage footprint  https://dev.mysql.com/doc/refman/8.0/en/serialized-dictionary-information.html
#TODO sdi2ibd
def sdi_page_data(bdata):
	_sdi_offset = []
	isok = False
	for i in range(120,16384):
		if isok:
			break
		for j in range(i,16384):
			if isok:
				break
			try:
				_test = zlib.decompress(bdata[i:j])
				_sdi_offset.append(i)
				i += len(_test)
				if len(_sdi_offset) == 2:
					isok = True #break 2
				break
			except:
				pass
	sdi_info = [json.loads(zlib.decompress(bdata[_sdi_offset[0]:]).decode()), json.loads(zlib.decompress(bdata[_sdi_offset[1]:]).decode())]
	return sdi_info

#根据sdi信息返回表DDL语句
def get_ddl(data):
	ddl = f"CREATE {data[1]['dd_object_type']} {data[1]['dd_object']['schema_ref']}.{data[1]['dd_object']['name']}( \n"
	pk_list = []
	auto_key = None
	col_len = len(data[1]['dd_object']['columns']) - 2
	_col_len = 0
	coll = []
	for col in data[1]['dd_object']['columns']:
		if col['name'] in ['DB_TRX_ID','DB_ROLL_PTR']:
			continue
		if col['is_nullable']:
			ddl += f"{col['name']} {col['column_type_utf8']}"
		else:
			ddl += f"{col['name']} {col['column_type_utf8']} not null"
		_col_len += 1
		coll.append(col['name'])
		if col['is_auto_increment']:
			ddl += ' auto_increment,\n'
		elif _col_len < col_len:
			ddl += ',\n'
		else:
			ddl += ' \n'

	index_ddl = ''
	for i in data[1]['dd_object']['indexes']:
		name = "PRIMARY KEY" if i['name'] == 'PRIMARY' else  f"index {i['name']}"
		index_ddl += f",{name}("
		for x in i['elements']:
			if x['length'] < 4294967295:
				index_ddl += f"{coll[x['column_opx']]},"
		index_ddl = index_ddl[:-1] #去掉最后一个,
		index_ddl += ")"
	
	ddl += index_ddl
	ddl += f") engine={data[1]['dd_object']['engine']} comment='{data[1]['dd_object']['comment']}';"	
	return ddl

def get_rec_data(bdata,columns,index):
	rdata = []
	page0 = page_index(bdata)
	index_ = [] 
	for x in index['elements']:
		if x['length'] < 4294967295:
			index_.append(x['column_opx'])
	len_column = len(columns) - 2 #去掉DB_TRX_ID(6)  DB_ROLL_PTR(7)
	for x in page0.records:
		rec_header = rec_extra_header(bdata[x-5:x])
		if rec_header.deleted:
			#print('deleted')
			continue #删除的数据就不要了
		tdata = [ None for x in range(len_column) ]
		null_bitmask_size = int((len_column+7)/8)
		null_bitmask = int.from_bytes(bdata[x-null_bitmask_size-5:x-5],'big')
		toffset = x-5-null_bitmask_size
		doffset = x
		#print(x,toffset,doffset,null_bitmask)
		#read_key:
		for k in index_: #遍历索引字段
			ktype = columns[k]['type']
			if ktype in [16,]:#变长...
				ksize = bdata[toffset-1:toffset] #懒得考虑超过128的情况了...
				if ksize > REC_N_FIELDS_ONE_BYTE_MAX:
					ksize = bdata[toffset-2:toffset]
					toffset -= 1
				toffset -= 1
				#print(toffset)
				tdata[k] = bdata[doffset:doffset+ksize].decode()
				doffset += ksize
			elif ktype in [15,]: #date
				tdata[k] = bdata[doffset:doffset+3]
				doffset += 3

			elif ktype in [4,]: #DATA_BINARY 4字节 第一bit是记录正负
				_t = struct.unpack('>L',bdata[doffset:doffset+4])[0]
				tdata[k] = (_t&((1<<31)-1)) if _t&(1<<31) else -(_t&((1<<31)-1))
				#tdata[k] = bdata[doffset:doffset+4]
				doffset += 4

		doffset += 6 + 7
		#遍历其它数据,
		for k in range(len_column):
			if k in index_: #索引已经记录了数据了
				continue
			if null_bitmask&(1<<k): #空字段
				continue
			ktype = columns[k]['type']
			#print(columns[k]['name'],toffset)
			if ktype in [16,]:#变长...
				ksize = struct.unpack('>B',bdata[toffset-1:toffset])[0] #懒得考虑超过128的情况了...
				if ksize > REC_N_FIELDS_ONE_BYTE_MAX:
					ksize = struct.unpack('>H',bdata[toffset-2:toffset])[0]
					toffset -= 1
				toffset -= 1
				tdata[k] = bdata[doffset:doffset+ksize].decode()
				doffset += ksize
			elif ktype in [15,]: #date
				tdata[k] = bdata[doffset:doffset+3]
				doffset += 3

			elif ktype in [4,]: #DATA_BINARY 4字节
				_t = struct.unpack('>L',bdata[doffset:doffset+4])[0]
				tdata[k] = (_t&((1<<31)-1)) if _t&(1<<31) else -(_t&((1<<31)-1))
				#tdata[k] = bdata[doffset:doffset+4]
				doffset += 4
		rdata.append(tdata)
		#break
		
	return rdata
			

#数据类型 storage/innobase/include/data0type.h
def rec_data_cluster(filename): #主键索引必须显示主键, 
	"""
	filename: 文件名
	"""
	f = open(filename,'rb')
	f.seek(PAGE_SIZE*3,0)
	sdi_info = sdi_page_data(f.read(PAGE_SIZE))
	ddl = get_ddl(sdi_info)
	print(ddl)
	db_table = f'{sdi_info[1]["dd_object"]["schema_ref"]}.{sdi_info[1]["dd_object"]["name"]}'
	index = sdi_info[1]['dd_object']['indexes'][0]
	columns = sdi_info[1]['dd_object']['columns']
	root_page = int(index['se_private_data'].split('root=')[1].split(';')[0])
	#f.seek(PAGE_SIZE*root_page,0)
	#只需要找到第一个叶子节点, 然后解析叶子节点的数据即可. (inode不是就记录了第一个叶子节点么.....)
	f.seek(2*PAGE_SIZE,0)
	inode = innodb_file.inode(f.read(PAGE_SIZE)[38:PAGE_SIZE-8])
	leaf_page = 0
	for x in inode.index:
		if x['no_leaf'] == root_page:
			leaf_page = x['leaf']
			break
	
	rdata = [] #[(col1,col2),(col1,col2)] 
	next_page_number = leaf_page
	while True:
		if next_page_number == 4294967295:
			break
		#print('PAGE_NUM:',next_page_number)
		f.seek(next_page_number*PAGE_SIZE,0)
		page0 = page(f.read(PAGE_SIZE))
		next_page_number = page0.FIL_PAGE_NEXT
		rdata += get_rec_data(page0.bdata,columns,index)
		#break

	rdata_sql = []
	for x in rdata:
		_v = ''
		for j in x:
			_v += f'{j},' if isinstance(j,int) else f'"{j}",'
		_v = _v[:-1]
		_sql = f'insert into {db_table} values({_v});'
		rdata_sql.append(_sql)
	return rdata_sql


#storage/innobase/rem/rec.h
REC_INFO_MIN_REC_FLAG = 0x10
REC_INFO_DELETED_FLAG = 0x20
REC_N_OWNED_MASK = 0xF
REC_HEAP_NO_MASK = 0xFFF8
REC_NEXT_MASK = 0xFFFF
#REC_STATUS_ORDINARY 0
#REC_STATUS_NODE_PTR 1
#REC_STATUS_INFIMUM 2
#REC_STATUS_SUPREMUM 3
class rec_extra_header(object):
	def __init__(self,bdata):
		if len(bdata) != 5:
			return False
		fb = struct.unpack('>B',bdata[:1])[0]
		self.deleted = True if fb&REC_INFO_DELETED_FLAG else False  #是否被删除
		self.min_rec = True if fb&REC_INFO_MIN_REC_FLAG else False #if and only if the record is the first user record on a non-leaf
		self.owned = fb&REC_N_OWNED_MASK # 大于0表示这个rec是这组的第一个, 就是地址被记录在page_directory里面
		self.heap_no = struct.unpack('>H',bdata[1:3])[0]&REC_HEAP_NO_MASK #heap number, 0 min, 1 max other:rec
		self.record_type = struct.unpack('>H',bdata[1:3])[0]&((1<<3)-1) #0:rec 1:no-leaf 2:min 3:max
		self.next_record = struct.unpack('>H',bdata[3:5])[0]
	def __str__(self):
		return f'deleted:{self.deleted}  min_rec:{self.min_rec}  owned:{self.owned}  heap_no:{self.heap_no}  record_type:{self.record_type}  next_record:{self.next_record}'

class page(object):
	def __init__(self,bdata):
		if len(bdata) != PAGE_SIZE:
			return None

		self.FIL_PAGE_SPACE_OR_CHKSUM, self.FIL_PAGE_OFFSET, self.FIL_PAGE_PREV, self.FIL_PAGE_NEXT, self.FIL_PAGE_LSN, self.FIL_PAGE_TYPE, self.FIL_PAGE_FILE_FLUSH_LSN = struct.unpack('>4LQHQ',bdata[:34])
		self.FIL_PAGE_SPACE_ID = struct.unpack('>L',bdata[34:38])[0]
		
		self.CHECKSUM, self.FIL_PAGE_LSN = struct.unpack('>2L',bdata[-8:])
		self.bdata = bdata

	def fil_header(self):
		return f'PAGE_SPACE_ID:{self.FIL_PAGE_SPACE_ID}  PAGE_TYPE:{innodb_page_name[self.FIL_PAGE_TYPE]} PREV:{self.FIL_PAGE_PREV}  NEXT:{self.FIL_PAGE_NEXT}'


	def fil_trailer(self):
		return f'CHECKSUM:{self.CHECKSUM}  PAGE_LSN:{self.FIL_PAGE_LSN}'


class page_index(page):
	def __init__(self,bdata):
		super().__init__(bdata)


		self.cols = [] #字段类型列表.

		#PAGE_HEADER
		bdata = self.bdata[FIL_PAGE_DATA:PAGE_SIZE-FIL_PAGE_DATA_END]
		self.PAGE_N_DIR_SLOTS, self.PAGE_HEAP_TOP, self.PAGE_N_HEAP, self.PAGE_FREE, self.PAGE_GARBAGE, self.PAGE_LAST_INSERT, self.PAGE_DIRECTION, self.PAGE_N_DIRECTION, self.PAGE_N_RECS, self.PAGE_MAX_TRX_ID, self.PAGE_LEVEL, self.PAGE_INDEX_ID = struct.unpack('>9HQHQ',bdata[:36])
		self.PAGE_BTR_SEG_LEAF = fseg_header(bdata[36:46])
		self.PAGE_BTR_SEG_TOP = fseg_header(bdata[46:56])


		#PAGE_DIRECTORY (这两字节指向的数据位置, 不包含数据前面的 5-byte header  就是REC_N_NEW_EXTRA_BYTES)
		page_directorys = []
		for x in range(int(PAGE_SIZE/2)):
			tdata = struct.unpack('>H',self.bdata[-(2+FIL_PAGE_DATA_END+x*2):-(FIL_PAGE_DATA_END+x*2)])[0]
			page_directorys.append(tdata)
			if tdata == PAGE_NEW_SUPREMUM: 
				break #slot遍历完成
		self.page_directorys = page_directorys



		#RECORDS(PAGE_DATA)  innodb_default_row_format
		offset = self.page_directorys[:1][0] #第一字段, 虚拟的...
		records = []
		while True:
			record_type = self.bdata[offset-3:offset-2]
			if record_type == b'\x03' or record_type == b'': #00 普通rec(leaf),  01 no_leaf   02 min_rec  03 max_rec
				break
			records.append(offset)
			offset += struct.unpack('>H',self.bdata[offset-2:offset])[0]
		records.remove(PAGE_NEW_INFIMUM) #去掉第一个页(虚拟的页,你把握不住)
		self.records = records


	def get_record(self,rec_offset):
		"""
		根据用户给的偏移量返回对于的数据
		"""
		pass

	def find_data_with_index(index_value):
		"""
		根据用户给的index值查找数据 找page, 然后通过二分法找rec(利用slot)
		"""
		pass


	def record(self):
		return f'RECORDS:{len(self.records)}'

	def page_header(self):
		return f'SLOTS:{self.PAGE_N_DIR_SLOTS}  PAGE_LEVEL:{self.PAGE_LEVEL}  INDEX_ID:{self.PAGE_INDEX_ID}  RECORDS:{self.PAGE_N_RECS}  PAGE_HEAP_TOP:{self.PAGE_HEAP_TOP}  PAGE_GARBAGE(deleted):{self.PAGE_GARBAGE}  PAGE_FREE:{self.PAGE_FREE}'


	def page_directory(self):
		return f'SLOTS:{len(self.page_directorys)}   MAX:{self.page_directorys[-1:]}  MIN:{self.page_directorys[:1]}'
