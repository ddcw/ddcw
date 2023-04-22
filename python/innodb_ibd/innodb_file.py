#解析innodb 文件的 (8.0)
import struct
import innodb_page_type

innodb_page_name = {}
for x in dir(innodb_page_type):
	if x[:2] != '__':
		innodb_page_name[getattr(innodb_page_type,x)] = x


#FIL_PAGE_DATA = 38
class fil_header(object):
	def __init__(self,bdata):
		if len(bdata) != 38:
			return False
		self.FIL_PAGE_SPACE_OR_CHKSUM, self.FIL_PAGE_OFFSET, self.FIL_PAGE_PREV, self.FIL_PAGE_NEXT, self.FIL_PAGE_LSN, self.FIL_PAGE_TYPE, self.FIL_PAGE_FILE_FLUSH_LSN = struct.unpack('>4LQHQ',bdata[:34])
		if self.FIL_PAGE_TYPE == innodb_page_type.FIL_PAGE_COMPRESSED:
			pass #懒得管了....
		self.FIL_PAGE_SPACE_ID = struct.unpack('>L',bdata[34:38])[0]

	def __str__(self):
		return f'PAGE_SPACE_ID:{self.FIL_PAGE_SPACE_ID}  PAGE_TYPE:{innodb_page_name[self.FIL_PAGE_TYPE]} PREV:{self.FIL_PAGE_PREV}  NEXT:{self.FIL_PAGE_NEXT}'

#8
class fil_trailer(object):
	def __init__(self,bdata):
		self.checksum, self.FIL_PAGE_LSN = struct.unpack('>2L',bdata[:8])

	def __str__(self):
		return f'CHECKSUM:{self.checksum}  PAGE_LSN:{self.FIL_PAGE_LSN}'

#index page header
# uint32_t PAGE_HEADER = FSEG_PAGE_DATA;
# size : 36 + 2 * FSEG_HEADER_SIZE = 56
class page_header(object):
	def __init__(self,bdata):
		self.PAGE_N_DIR_SLOTS, self.PAGE_HEAP_TOP, self.PAGE_N_HEAP, self.PAGE_FREE, self.PAGE_GARBAGE, self.PAGE_LAST_INSERT, self.PAGE_DIRECTION, self.PAGE_N_DIRECTION, self.PAGE_N_RECS, self.PAGE_MAX_TRX_ID, self.PAGE_LEVEL, self.PAGE_INDEX_ID = struct.unpack('<9HQHQ',bdata[:36])
		self.PAGE_BTR_SEG_LEAF = fseg_header(bdata[36:46])
		self.PAGE_BTR_SEG_TOP = fseg_header(bdata[46:56])

	def __str__(self):
		return f'SLOTS:{self.PAGE_N_DIR_SLOTS}  PAGE_LEVEL:{self.PAGE_LEVEL}  INDEX_ID:{self.PAGE_INDEX_ID}  RECORDS:{self.PAGE_N_RECS}  PAGE_HEAP_TOP:{self.PAGE_HEAP_TOP}  PAGE_GARBAGE(deleted):{self.PAGE_GARBAGE}  PAGE_FREE:{self.PAGE_FREE}'


#Offset of the directory start down from the page end
class page_directory(object):
	def __init__(self,bdata):
		pass

	def __str__(self):
		pass

#FIL_PAGE_TYPE_FSP_HDR 第一个page
#FSP_HEADER_SIZE = 32 + 5 * FLST_BASE_NODE_SIZE = 32+5*16 = 112
class space_header(object):
	def __init__(self,bdata,):
		FLST_BASE_NODE_SIZE = 16
		self.FSP_SPACE_ID, self.FSP_NOT_USED, self.FSP_SIZE, self.FSP_FREE_LIMIT, self.FSP_SPACE_FLAGS, self.FSP_FRAG_N_USED = struct.unpack('>6L',bdata[:24])
		i = 24
		self.FSP_FREE = bdata[i:i+FLST_BASE_NODE_SIZE]
		i += FLST_BASE_NODE_SIZE
		self.FSP_FREE_FRAG = bdata[i:i+FLST_BASE_NODE_SIZE]
		i += FLST_BASE_NODE_SIZE
		self.FSP_FULL_FRAG= bdata[i:i+FLST_BASE_NODE_SIZE]
		i += FLST_BASE_NODE_SIZE
		self.FSP_SEG_ID = bdata[i:i+8] #/** 8 bytes which give the first unused segment id */
		i += 8
		self.FSP_SEG_INODES_FULL = bdata[i:i+FLST_BASE_NODE_SIZE]
		i += FLST_BASE_NODE_SIZE
		self.FSP_SEG_INODES_FREE = bdata[i:i+FLST_BASE_NODE_SIZE]

		
	def __str__(self):
		return f'FSP_SPACE_ID:{self.FSP_SPACE_ID}  PAGE_COUNT:{self.FSP_SIZE}  USED(FSP_FREE_FRAG):{self.FSP_FRAG_N_USED}'

#storage/innobase/include/fsp0fsp.h
class inode(object):
	def __init__(self,bdata,FSP_EXTENT_SIZE=64): #按16384算,   1024*1024/16384 = 64 page
		i = 0
		lbdata = len(bdata)
		FLST_BASE_NODE_SIZE = 16
		FSEG_FRAG_ARR_N_SLOTS = int(FSP_EXTENT_SIZE / 2)
		FSEG_FRAG_SLOT_SIZE = 4
		FSEG_INODE_SIZE = 16 + 3*FLST_BASE_NODE_SIZE + FSEG_FRAG_ARR_N_SLOTS*FSEG_FRAG_SLOT_SIZE
		segment_list = []
		self.node_pre,self.node_next = flst(bdata[0:12])
		i += 12
		while True:
			if lbdata <= i+FSEG_INODE_SIZE-1:
				break
			FSEG_ID = struct.unpack('>Q',bdata[i:i+8])[0]
			if FSEG_ID == 0:
				i += FSEG_INODE_SIZE
				continue
			i += 8
			FSEG_NOT_FULL_N_USED = struct.unpack('>L',bdata[i:i+4])[0]
			i += 4
			FSEG_FREE = flst_base(bdata[i:i+FLST_BASE_NODE_SIZE])
			i += FLST_BASE_NODE_SIZE
			FSEG_NOT_FULL = flst_base(bdata[i:i+FLST_BASE_NODE_SIZE])
			i += FLST_BASE_NODE_SIZE
			FSEG_FULL = flst_base(bdata[i:i+FLST_BASE_NODE_SIZE])
			i += FLST_BASE_NODE_SIZE
			FSEG_MAGIC_N = bdata[i:i+4]
			i += 4
			FSEG_FRAG_ARR = [] #碎片页
			for x in range(FSEG_FRAG_ARR_N_SLOTS):
				FSEG_FRAG_ARR.append(struct.unpack('>L',bdata[i:i+FSEG_FRAG_SLOT_SIZE])[0])
				i += FSEG_FRAG_SLOT_SIZE
			segment_list.append({'FSEG_ID':FSEG_ID,'FSEG_NOT_FULL_N_USED':FSEG_NOT_FULL_N_USED,'FSEG_FREE':FSEG_FREE,'FSEG_NOT_FULL':FSEG_NOT_FULL,'FSEG_FULL':FSEG_FULL,'FSEG_MAGIC_N':FSEG_MAGIC_N,'FSEG_FRAG_ARR':FSEG_FRAG_ARR})
		self.segment_list = segment_list
		self.root_pages = [ x['FSEG_FRAG_ARR'][0] for x in segment_list ] #并非都是非叶子节点
		self.sdi_page = self.root_pages[0]
		self.index = []
		for x in range(1,int(len(self.root_pages)/2)):
			self.index.append({'no_leaf':self.root_pages[x*2],'leaf':self.root_pages[x*2+1]})

	def __str__(self,):
		return f'SEGMENT COUNTS:{len(self.segment_list)}  INDEX_COUNT:{len(self.index)}  INODE_PRE:{self.node_pre[0] if self.node_pre[0] != 4294967295 else None}  INODE_NEXT:{self.node_next[0] if self.node_next[0] != 4294967295 else None}'

#storage/innobase/include/fsp0fsp.h
#XDES_SIZE = (XDES_BITMAP + UT_BITS_IN_BYTES(FSP_EXTENT_SIZE * XDES_BITS_PER_PAGE)) = 24 + (128+7)/8 = 40
#
class xdes(object):
	def __init__(self,bdata):
		#38+112+bdata+8=page
		extent_list = []
		XDES_SIZE = 40
		FLST_NODE_SIZE = 12
		i = 0
		lbdata = len(bdata)
		while True:
			if i+XDES_SIZE-1 >= lbdata:
				break #不够一个xdes了
			XDES_ID = struct.unpack('>Q',bdata[i:i+8])[0] #/** The identifier of the segment to which this extent belongs */
			if XDES_ID == 0:
				i += XDES_SIZE
				continue
			i += 8
			XDES_FLST_NODE = flst(bdata[i:i+FLST_NODE_SIZE])
			i += FLST_NODE_SIZE
			XDES_STATE = struct.unpack('>L',bdata[i:i+4])[0] #xdes_state_t  0:未初始化,  1:FREE  2:FREE_FRAG  3:FULL_FRAG  4:属于segment  5:FSEG_FRAG
			i += 4
			XDES_BITMAP = bdata[i:i+16]
			i += 16
			extent_list.append({'XDES_ID':XDES_ID,'XDES_FLST_NODE':XDES_FLST_NODE,'XDES_STATE':XDES_STATE,'XDES_BITMAP':XDES_BITMAP})
		self.extent_list = extent_list

	def __str__(self):
		return f'EXTENT COUNT: {len(self.extent_list)}'

	def summary(self):
		pass

class page_data(object):
	def __init__(self,bdata):
		pass

	def __str__(self):
		pass

def _get_fil_addr(bdata):
	return struct.unpack('>LH',bdata)

def flst_base(bdata):
	#FLST_BASE_NODE   storage/innobase/include/fut0lst.ic  #/* We define the field offsets of a base node for the list */
	#FLST_LEN:0-4  FLST_FIRST:4-(4 + FIL_ADDR_SIZE)  FLST_LAST:4+FIL_ADDR_SIZE:16
	#4+6+6
	#FIL_ADDR_SIZE = FIL_ADDR_PAGE(4) + FIL_ADDR_BYTE(2) #/** First in address is the page offset. */  Then comes 2-byte byte offset within page.*/
	FLST_LEN = struct.unpack('>L',bdata[:4])[0]
	FLST_FIRST = struct.unpack('<LH',bdata[4:10])
	FLST_LAST = struct.unpack('<LH',bdata[10:16])
	return (FLST_LEN,FLST_FIRST,FLST_LAST)

def flst(bdata):
	#FLST_NODE storage/innobase/include/fut0lst.ic #/* We define the field offsets of a node for the list */
	#FLST_PREV:6  FLST_NEXT:6
	FLST_PREV = struct.unpack('<LH',bdata[0:6])
	FLST_NEXT = struct.unpack('<LH',bdata[6:12])
	return(FLST_PREV,FLST_NEXT)

def fseg_header(bdata):
	return struct.unpack('>LLH',bdata[:10])

class innodb_ibd(object):
	def __init__(self,filename,pagesize=16384):
		self.filename = filename
		self.pagesize = pagesize

	def page_summary(self,del0=True):
		"""
		返回dict, 各page的数量
		"""
		data = {}
		for x in innodb_page_name:
			data[x] = 0
		f = open(self.filename,'rb')
		i = 0
		while True:
			bdata = f.read(self.pagesize)
			if len(bdata) < self.pagesize:
				break
			filh = fil_header(bdata[:38])
			data[filh.FIL_PAGE_TYPE] += 1
			i += 1
			#if filh.FIL_PAGE_TYPE == innodb_page_type.FIL_PAGE_SDI:
			#	print(i-1)
		f.close()
		data1 = {}
		for x in data:
			if data[x] == 0 and del0:
				continue
			data1[innodb_page_name[x]] = data[x]
		return data1

	def index(self,n=0):
		"""
		获取第N个index,  返回(非叶子节点列表, 叶子节点列表)
		"""
		pass
