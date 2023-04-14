#解析mysql redo log 
#字节序为大端
import struct
import os

class LOG_HEADER(object):
	def __init__(self,bdata):
		"""
		LOG_HEADER_FORMAT       0 (LOG_HEADER_FORMAT_CURRENT 1)
		LOG_HEADER_PAD1         4
		LOG_HEADER_START_LSN    8
		LOG_HEADER_CREATOR      16
		LOG_HEADER_CREATOR_END  (LOG_HEADER_CREATOR + 32)
		LOG_HEADER_CREATOR_CURRENT      "MySQL " INNODB_VERSION_STR
		"""
		self.LOG_HEADER_FORMAT = struct.unpack('>L',bdata[:4])[0]
		self.LOG_HEADER_PAD1 = struct.unpack('>L',bdata[4:8])[0]
		self.LOG_HEADER_START_LSN = struct.unpack('>Q',bdata[8:16])[0]
		self.LOG_HEADER_CREATOR = bdata[16:16+32].split(b'\x00')[0].decode()
		#懒得校验结尾的trailer了.....

	def __str__(self):
		return f'format:{self.LOG_HEADER_FORMAT} creator:{self.LOG_HEADER_CREATOR} start_lsn:{self.LOG_HEADER_START_LSN}'


class LOG_CHECKPOINT(object):
	def __init__(self,bdata):
		"""
		LOG_CHECKPOINT_NO               0
		LOG_CHECKPOINT_LSN              8
		LOG_CHECKPOINT_OFFSET           16
		LOG_CHECKPOINT_LOG_BUF_SIZE     24
		"""
		#其实是uint32_t  但是 是大端, 所以用Q也行....
		self.LOG_CHECKPOINT_NO = struct.unpack('>Q',bdata[0:8])[0]  #Checkpoint number
		self.LOG_CHECKPOINT_LSN = struct.unpack('>Q',bdata[8:16])[0]
		self.LOG_CHECKPOINT_OFFSET = struct.unpack('>Q',bdata[16:24])[0]
		self.LOG_CHECKPOINT_LOG_BUF_SIZE = struct.unpack('>Q',bdata[24:32])[0] 

	def __str__(self):
		return f'chk no:{self.LOG_CHECKPOINT_NO}   chk_lsn:{self.LOG_CHECKPOINT_LSN}  chk_offset:{self.LOG_CHECKPOINT_OFFSET}  chk_buff:{self.LOG_CHECKPOINT_LOG_BUF_SIZE/1024/1024} MB'

#Bytes used by headers of log files are NOT included in lsn sequence
class LOG_BLOCK(object):
	def __init__(self,bdata):
		#LOG_BLOCK_HDR_SIZE 12
		"""
		LOG_BLOCK_HDR_NO        0
		LOG_BLOCK_HDR_DATA_LEN  4
		LOG_BLOCK_FIRST_REC_GROUP 6
		LOG_BLOCK_CHECKPOINT_NO 8
		"""
		self.LOG_BLOCK_HDR_NO = struct.unpack('>L',bdata[0:4])[0] #block id
		self.LOG_BLOCK_HDR_DATA_LEN = struct.unpack('>H',bdata[4:6])[0] #data length
		self.LOG_BLOCK_FIRST_REC_GROUP = struct.unpack('>H',bdata[6:8])[0] # 0 or LOG_BLOCK_HDR_SIZE (12)
		self.LOG_BLOCK_CHECKPOINT_NO = struct.unpack('>L',bdata[8:12])[0] #chk
		self.data = bdata[12:12+self.LOG_BLOCK_HDR_DATA_LEN-12-4] #减去block_hdr和trailer
		self.empty = True if bdata[:12] == int(0).to_bytes(12,'big') else False
		#self.leader = True if self.LOG_BLOCK_HDR_NO >> 31 > 0 else False
		#The highest bit is set to 1, if this is the first block in a call to fil_io (for possibly many consecutive blocks).
		if self.LOG_BLOCK_HDR_NO >> 31 > 0:
			self.leader = True
			self.LOG_BLOCK_HDR_NO -= 1<<31
		else:
			self.leader = False

	def __str__(self,):
		return f'block_id:{self.LOG_BLOCK_HDR_NO}{" L" if self.leader else "  "}  data_length:{self.LOG_BLOCK_HDR_DATA_LEN}  chk_no:{self.LOG_BLOCK_CHECKPOINT_NO}'


#For 1 - 8 bytes, the flag value must give the length also
def mtr_log(bdata):
	"""
	type         1  mlog_id_t
	space_id     4  space_id_t 
	page_no      4  page_no_t
	page_offset  4  ulint 
	len
	data
	"""
	pass
			


#storage/innobase/include/log0log.h
#lsn是不包含log header的, 所以计算的时候要减去2048 LSN = (OFFSET - 2048 + LOG_HEADER_START_LSN)
class mysql_redo(object):
	def __init__(self,filedir):
		"""
		LOG_HEADER       512*0 -- 512*0+512
		LOG_CHECKPOINT_1 512*1 -- 512*1+512 /*only defined in the first log file*/
		LOG_CHECKPOINT_2 512*3 -- 512*3+512
		LOG_BLOCK 512*n
		"""
		#LOG_FILE_HDR_SIZE 一共就是 2048

		filedir = os.path.abspath(filedir)
		self.filedir = filedir
		file_count = 0 #innodb_log_files_in_group
		try:
			filename_list = os.listdir(filedir)
			for x in filename_list:
				 file_count += 1 if len(x.split('ib_logfile')) == 2 else 0
		except Exception as e:
			return e
		self.file_count = file_count
			
		self.filename = f'{filedir}/ib_logfile0' #第一个redo文件
		self.filesize = os.path.getsize(self.filename) #redo文件大小
		self.max_blocks = int((self.filesize-2048)/512) #每个redo文件所能存储的block数量
		with open(self.filename,'rb') as f:
			self.log_header = LOG_HEADER(f.read(512))
			self.log_chk1 = LOG_CHECKPOINT(f.read(512))
			f.read(512)#留空
			self.log_chk2 = LOG_CHECKPOINT(f.read(512))
			self.first = True if self.log_chk1.LOG_CHECKPOINT_NO != 0 else False
			self.LOG_CHECKPOINT_LSN = max(self.log_chk2.LOG_CHECKPOINT_LSN,self.log_chk1.LOG_CHECKPOINT_LSN)
			self.LOG_CHECKPOINT_NO = max(self.log_chk2.LOG_CHECKPOINT_NO,self.log_chk1.LOG_CHECKPOINT_NO)
			self.LOG_CHECKPOINT_LOG_BUF_SIZE = self.log_chk2.LOG_CHECKPOINT_LOG_BUF_SIZE if self.log_chk2.LOG_CHECKPOINT_NO > self.log_chk1.LOG_CHECKPOINT_NO else self.log_chk1.LOG_CHECKPOINT_LOG_BUF_SIZE
			self.LOG_CHECKPOINT_OFFSET = self.log_chk2.LOG_CHECKPOINT_OFFSET if self.log_chk2.LOG_CHECKPOINT_NO > self.log_chk1.LOG_CHECKPOINT_NO else self.log_chk1.LOG_CHECKPOINT_OFFSET
			self.avg = 0 if self.LOG_CHECKPOINT_NO == 0 else round(self.LOG_CHECKPOINT_OFFSET/self.LOG_CHECKPOINT_NO/1024/1024,2) #平均每次刷redo数据量MB

	def __str__(self,):
		return f'LAST_CHK:{self.LOG_CHECKPOINT_LSN}  CHK_NO:{self.LOG_CHECKPOINT_NO}  REDO_BUFFER_SIZE:{self.LOG_CHECKPOINT_LOG_BUF_SIZE/1024/1024}MB  OFFSET:{self.LOG_CHECKPOINT_OFFSET}  AVG_WRITE:{self.avg}MB  BLOCKS:{int((self.LOG_CHECKPOINT_OFFSET-2048*(1+int(self.LOG_CHECKPOINT_OFFSET/self.filesize))+511)/512)}'

	def blocks(self,start_block=0,count=10):
		"""
		start_block : 从第N个block开始读 (默认0)
		count : 读多少个block (默认10)
		"""

		def _getblocks(filename,s_off,e_off):
			_t = []
			with open(filename,'rb') as f:
				f.seek(s_off)
				while s_off < e_off:
					_block = LOG_BLOCK(f.read(512))
					s_off += 512
					if _block.empty:
						break
					_block.lsn = f.tell() - 2048 + self.log_header.LOG_HEADER_START_LSN - 512 + _block.LOG_BLOCK_HDR_DATA_LEN #Log flushed up to
					_t.append(_block)
			return _t
				

		start_offset = 2048+2048*int(start_block/self.max_blocks)+start_block*512
		end_offset = start_offset + 512*count
		log_block = []

		while start_offset < end_offset:
			fileno = int(start_offset/self.filesize)
			filename = f'{self.filedir}/ib_logfile{fileno}'
			if int(end_offset/self.filesize) > int(start_offset/self.filesize): #超过一个文件
				log_block += _getblocks(filename,start_offset%self.filesize,self.filesize)
				start_offset += self.filesize - start_offset%self.filesize + 2048
				end_offset += 2048 #跳过header
			else:#最后一次
				log_block += _getblocks(filename,start_offset%self.filesize,end_offset%self.filesize)
				start_offset = end_offset
		return log_block
					

