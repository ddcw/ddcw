#!/usr/bin/env python
# -*- coding: utf-8 -*-
# write by ddcw @https://github.com/ddcw
# 解析undo log的

import argparse
import struct
import os,sys

class bdata_buffer(object):
	def __init__(self,bdata):
		self.bdata = bdata
		self.offset = 0
	def read(self,n):
		data = self.bdata[self.offset:self.offset+n]
		self.offset += n
		return data
	def readn(self,n):
		return self.bdata[self.offset:self.offset+n]

def mach_read_next_compressed(tdata):
	val = struct.unpack('>B',tdata.readn(1))[0]
	if val < 0x80:
		val = struct.unpack('>B',tdata.read(1))[0]
	elif val < 0xC0:
		val = struct.unpack('>H',tdata.read(2))[0] & 0x3FFF
	elif val < 0xE0:
		val2,val1 = struct.unpack('>HB',tdata.read(3))
		val = ((val2<<8)+val1) & 0x1FFFFF
	elif val < 0xF0:
		val = struct.unpack('>L',tdata.read(4))[0] & 0xFFFFFFF
	elif val < 0xF8:
		tdata.read(1)
		val = struct.unpack('>L',tdata.read(4))[0]
	elif val < 0xFC:
		val = (struct.unpack('>H',tdata.read(2))[0] & 0x3FF) | 0xFFFFFC00
		
	elif val < 0xFE:
		val2,val1 = struct.unpack('>HB',tdata.read(3))
		valt = (val2<<8)+val1
		val = (valt & 0x1FFFF) | 0xFFFE0000;
	else:
		val = (((struct.unpack('>L',tdata.read(4))[0])<<8)>>8) | 0xFF000000
	return val

# 花里胡哨的存储
def mach_read_next_much_compressed(tdata):
	val = struct.unpack('>B',tdata.readn(1))[0]
	if val < 0x80:
		#pass
		val = struct.unpack('>B',tdata.read(1))[0]
	elif val < 0xC0:
		val = struct.unpack('>H',tdata.read(2))[0] & 0x3FFF
	elif val < 0xE0:
		val2,val1 = struct.unpack('>HB',tdata.read(3))
		val = ((val2<<8)+val1) & 0x1FFFFF
	elif val < 0xF0:
		val = struct.unpack('>L',tdata.read(4))[0] & 0xFFFFFFF
	elif val < 0xF8:
		tdata.read(1)
		val = struct.unpack('>L',tdata.read(4))[0]
	elif val < 0xFC:
		val = (struct.unpack('>H',tdata.read(2))[0] & 0x3FF) | 0xFFFFFC00
		
	elif val < 0xFE:
		val2,val1 = struct.unpack('>HB',tdata.read(3))
		valt = (val2<<8)+val1
		val = (valt & 0x1FFFF) | 0xFFFE0000;
	elif val == 0xFE:
		val = (((struct.unpack('>L',tdata.read(4))[0])<<8)>>8) | 0xFF000000
	else:
		tdata.read(1)
		val = mach_read_next_much_compressed(tdata)
		val <<= 32
		val |= mach_read_next_compressed(tdata)
	return val

UNDO_LOG_SEGMENT_STAT = [
None,
'TRX_UNDO_ACTIVE',
'TRX_UNDO_CACHED',
'TRX_UNDO_TO_FREE',
'TRX_UNDO_TO_PURGE',
'TRX_UNDO_PREPARED_80028',
'TRX_UNDO_PREPARED',
'TRX_UNDO_PREPARED_IN_TC'
]
UNDO_LOG_SEGEMT_TYPE = [
None,
'TRX_UNDO_INSERT',
'TRX_UNDO_UPDATE' # update+delete
]
UNDO_LOG_TYPE = {11:'TRX_UNDO_INSERT_REC',12:'TRX_UNDO_UPD_EXIST_REC',13:'TRX_UNDO_UPD_DEL_REC',14:'TRX_UNDO_DEL_MARK_REC',16:'TRX_UNDO_CMPL_INFO_MULT',64:'TRX_UNDO_MODIFY_BLOB',128:'TRX_UNDO_UPD_EXTERN'}
UNDO_LOG_FLAG = {1:'TRX_UNDO_INSERT_OP',2:'TRX_UNDO_MODIFY_OP'}

def undo_log_parse(bdata,f):
	print(struct.unpack('>B',bdata[2:3]))

def inode_page(bdata):
	return # 懒得打印了, 太多了
	data = bdata_buffer(bdata)
	FIL_PAGE_SPACE_OR_CHKSUM, FIL_PAGE_OFFSET, FIL_PAGE_PREV, FIL_PAGE_NEXT, FIL_PAGE_LSN, FIL_PAGE_TYPE, FIL_PAGE_FILE_FLUSH_LSN, FIL_PAGE_SPACE_ID = struct.unpack('>4LQHQL',data.read(38))
	print(f"[INODE]PAGE TYPE:{FIL_PAGE_TYPE}")
	INODE_PRE_PAGE,INODE_PRE_OFFSET,INODE_NEXT_PAGE,INODE_NEXT_OFFSET  = struct.unpack('>LHLH',data.read(12))
	print(f"[INODE] PRE:{INODE_PRE_PAGE}:{INODE_PRE_OFFSET}  NEXT:{INODE_NEXT_PAGE}:{INODE_NEXT_OFFSET}")
	FLST_BASE_NODE = "LLHLH" # LENGTH,FIRST_PAGE,FIRST_OFFSET,LAST_PAGE,LAST_OFFSET
	for _ in range(85):
		FSEG_ID = struct.unpack('>Q',data.read(8))
		FSEG_NOT_FULL_N_USED = struct.unpack('>L',data.read(4))
		FSEG_FREE     = struct.unpack(f'>{FLST_BASE_NODE}',data.read(16))
		FSEG_NOT_FULL = struct.unpack(f'>{FLST_BASE_NODE}',data.read(16))
		FSEG_FULL     = struct.unpack(f'>{FLST_BASE_NODE}',data.read(16))
		FSEG_MAGIC    = struct.unpack('>L',data.read(4))
		FSEG_FRAG_ARR = struct.unpack('>32L',data.read(32*4))
		print(f"[INODE] FSEG_ID:{FSEG_ID}")
		print(f"[INODE] FSEG_NOT_FULL_N_USED:{FSEG_NOT_FULL_N_USED}")
		print(f"[INODE] FSEG_FREE:{FSEG_FREE}")
		print(f"[INODE] FSEG_NOT_FULL:{FSEG_NOT_FULL}")
		print(f"[INODE] FSEG_FULL:{FSEG_FULL}")
		print(f"[INODE] FSEG_MAGIC:{FSEG_MAGIC} (? 97937874)")
		print(f"[INODE] FSEG_FRAG_ARR:{FSEG_FRAG_ARR}")

def rseg_array_page(bdata):
	#data = bdata_buffer(bdata)
	array_version,array_size = struct.unpack('>2L',bdata[38:46])
	array_fseg_header = struct.unpack('>LLH',bdata[46:56]) # space_id,page_id,page_offset
	array_slot = struct.unpack('>128L',bdata[56:56+128*4])
	#print(array_slot)
	print("[RSEG_ARRAY] array_fseg_header:",array_fseg_header)
	print("[RSEG_ARRAY] array_slot:",array_slot)
	return array_slot

def sys_page(bdata):
	# TRX_RSEG_N_SLOTS = (UNIV_PAGE_SIZE / 16) = 1024
	# TRX_RSEG_SLOT_SIZE = 4
	rseg_max_size,rseg_history_size = struct.unpack('>2L',bdata[38:46])
	rseg_history = struct.unpack('>LLHLH',bdata[46:62])
	space_id,page_id,offset = struct.unpack('>2LH',bdata[62:72])
	undo_slot = struct.unpack('>1024L',bdata[72:72+4*1024])
	print(f"[SYS] rseg_max_size:{rseg_max_size}")
	print(f"[SYS] rseg_history_size:{rseg_history_size}")
	print(f"[SYS] rseg_history:{rseg_history}")
	print(f"[SYS] space_id:page_id {space_id}:{page_id}")
	print(f"[SYS] offset: {offset}")
	print(f"[SYS] undo_slot:{undo_slot}")

def _argparse():
	parser = argparse.ArgumentParser(add_help=True, description='解析mysql的undo文件的脚本 https://github.com/ddcw')
	parser.add_argument('--rollptr', '-r', dest="ROLLPTR", default=-1, type=int,  help='要解析的rollptr')
	parser.add_argument(dest='FILENAME', help='undo filename', nargs='?')
	return parser.parse_args()

if __name__ == '__main__':
	parser = _argparse()
	filename = parser.FILENAME
	if filename is None or not os.path.exists(filename): # 只考虑一个undo文件的情况
		sys.stderr.write(f"\nno file {filename}\n\n")
		sys.exit(1)
	
	if parser.ROLLPTR > -1:
		rolll_ptr = parser.ROLLPTR
		offset = rolll_ptr & 0xFFFF
		page_no = (rolll_ptr>>16) & 0xFFFFFFFF
		rseg_id = (rolll_ptr>>48) & 0x7F
		is_insert = True if rolll_ptr>>55 == 1 else False
		if rseg_id != int(filename.split('_')[-1]):
			sys.stderr.write(f"\nno 这个rollptr({rolll_ptr})不在这个undo里面\n\n")
			sys.exit(1)
		with open(filename,'rb') as f:
			f.seek(page_no*16384,0)
			data = f.read(16384)
			end_offset = struct.unpack('>H',data[offset:offset+2])[0]
			print(f"PAGENO:{page_no}  OFFSET:{offset} --> {end_offset}  rseg_id:{rseg_id}  is_insert:{is_insert}")
			print("DATA:",data[offset+2:end_offset-2])
		sys.exit(0)
	# 完整的解析这个undo文件
	f = open(filename,'rb')
	# FIL_PAGE_TYPE_FSP_HDR  好像没必要解析
	# FIL_PAGE_IBUF_BITMAP 从来都没解析过...
	# FIL_PAGE_INODE 页没必要 -_-
	f.seek(16384*3,0) # 21:FIL_PAGE_TYPE_RSEG_ARRAY
	bdata = f.read(16384)
	array_version,array_size = struct.unpack('>2L',bdata[38:46])
	array_fseg_header = struct.unpack('>LLH',bdata[46:56]) # space_id,page_id,page_offset
	array_slot = struct.unpack('>128L',bdata[56:56+128*4])
	print(f"[ROLLBACK SEGMENT] VERSION     : {hex(array_version)}")
	print(f"[ROLLBACK SEGMENT] SIZE        : {array_size}")
	print(f"[ROLLBACK SEGMENT] SPACE_ID    : {array_fseg_header[0]}")
	print(f"[ROLLBACK SEGMENT] PAGE_ID     : {array_fseg_header[1]}")
	print(f"[ROLLBACK SEGMENT] PAGE_OFFSET : {array_fseg_header[2]}")
	#print(f"[ROLLBACK SEGMENT] SLOT PAGE   : {array_slot}")

	for slot in array_slot:
		f.seek(slot*16384,0)
		bdata = f.read(16384) # 6:FIL_PAGE_TYPE_SYS
		rseg_max_size,rseg_history_size = struct.unpack('>2L',bdata[38:46])
		rseg_history = struct.unpack('>LLHLH',bdata[46:62])
		space_id,page_id,offset = struct.unpack('>2LH',bdata[62:72])
		undo_slot = struct.unpack('>1024L',bdata[72:72+4*1024])
		undo_slot_var = [ ]
		for x in undo_slot:
			if x != 4294967295:
				undo_slot_var.append(x)
		print(f"\t[UNDO SEGMENT] CURRENT PAGE:{slot}")
		print(f"\t[UNDO SEGMENT] MAX_SIZE:{rseg_max_size}")
		print(f"\t[UNDO SEGMENT] HISTORY_SIZE:{rseg_history_size}")
		print(f"\t[UNDO SEGMENT] HISTORY:{rseg_history}")
		print(f"\t[UNDO SEGMENT] SPACE_ID:{space_id}")
		print(f"\t[UNDO SEGMENT] PAGE_ID:{page_id} (inode)")
		print(f"\t[UNDO SEGMENT] PAGE_OFFSET:{offset}")
		#print(f"[UNDO SEGMENT] SLOT PAGE:{undo_slot_var} (去除无效页(4294967295))")
		for undo_page in undo_slot_var:
			f.seek(undo_page*16384,0)
			bdata = f.read(16384) # 2:FIL_PAGE_UNDO_LOG
			# fil header
			FIL_PAGE_SPACE_OR_CHKSUM, FIL_PAGE_OFFSET, FIL_PAGE_PREV, FIL_PAGE_NEXT, FIL_PAGE_LSN, FIL_PAGE_TYPE, FIL_PAGE_FILE_FLUSH_LSN, FIL_PAGE_SPACE_ID = struct.unpack('>4LQHQL',bdata[:38])
			# undo page header
			undo_page_type,undo_page_start,undo_page_free = struct.unpack('>3H',bdata[38:44])
			undo_page_node = struct.unpack('>LHLH',bdata[44:56])
			# undo segment header 仅第一个undo log有 同一时刻只能由一个事务所有, 但是可能记录多个事务的信息
			trx_undo_state,trx_undo_last_log = struct.unpack('>HH',bdata[56:60])
			trx_undo_fseg_header = struct.unpack('>LLH',bdata[60:70])
			trx_undo_page_list = struct.unpack('>LLHLH',bdata[70:86])
			print(f"\t\t[UNDO LOG] CURRENT PAGE: {undo_page}")
			print(f"\t\t[UNDO LOG] PAGE_TYPE   : {undo_page_type} ({UNDO_LOG_SEGEMT_TYPE[undo_page_type]})")
			print(f"\t\t[UNDO LOG] PAGE_START  : {undo_page_start}") # 开始位置
			print(f"\t\t[UNDO LOG] PAGE_FREE   : {undo_page_free}")  # 结束位置, 遇到这个offset表示结束了
			print(f"\t\t[UNDO LOG] PAGE_NODE   : {undo_page_node}")
			print(f"\t\t[UNDO LOG] TRX_UNDO_STATE       : {trx_undo_state} ({UNDO_LOG_SEGMENT_STAT[trx_undo_state]})")
			print(f"\t\t[UNDO LOG] TRX_UNDO_LAST_LOG    : {trx_undo_last_log}")
			print(f"\t\t[UNDO LOG] TRX_UNDO_FSEG_HEADER : {trx_undo_fseg_header}")
			print(f"\t\t[UNDO LOG] TRX_UNDO_PAGE_LIST   : {trx_undo_page_list}")

			# undo log header (86-->276)
			undo_log_header = bdata[86:276]


			if undo_page_start == undo_page_free:
				continue
			# 仅解析部分
			not_end = True 
			undo_log_start_offset = undo_page_start
			while not_end:
				undo_log_end_offset = struct.unpack('>H',bdata[undo_log_start_offset:undo_page_start+2])[0]
				not_end = False if undo_log_end_offset == undo_page_free else True
				tdata = bdata_buffer(bdata[undo_log_start_offset:undo_log_end_offset][2:-2])
				#tdata.offset = 2
				undo_log_type_flag = struct.unpack('>B',tdata.read(1))[0]
				undo_log_type = undo_log_type_flag&0x0F # bit 0-3
				undo_log_flag = (undo_log_type_flag>>4)& 0x03 # bit 4-5
				if undo_log_type_flag & 64: #TRX_UNDO_MODIFY_BLOB
					undo_rec_flags = struct.unpack('>B',tdata.read(1))[0]
				undo_no = mach_read_next_much_compressed(tdata)
				table_id = mach_read_next_much_compressed(tdata)
				print(f'\t\t\t[UNDO DATA]',bdata[undo_log_start_offset:undo_log_end_offset])
				print(f'\t\t\t[UNDO DATA] TYPE: {undo_log_type} ({UNDO_LOG_TYPE[undo_log_type]})')
				print(f'\t\t\t[UNDO DATA] FLAG: {undo_log_flag}')# ({UNDO_LOG_FLAG[undo_log_flag]})')
				print(f'\t\t\t[UNDO DATA] UNDO NO  : {undo_no}')
				print(f'\t\t\t[UNDO DATA] TABLE ID : {table_id}')
				print(f'\t\t\t[UNDO DATA] REST_DATA: {tdata.bdata[tdata.offset:]}')
				#undo_log_parse(tdata,f) # 把文件描述一并丢过去
				#trx_undo_trx_id,trx_undo_trx_no,trx_undo_del_marks,trx_undo_log_start,trx_undo_flags,trx_undo_dict_trans,trx_undo_table_id,trx_undo_next_log,trx_undo_prev_log = struct.unpack('>QQHHBBQHH',tdata[0:34])
				#trx_undo_history_node = struct.unpack('>LHLH',tdata[34:46])
				if undo_page_node[2] == FIL_PAGE_SPACE_ID:
					undo_log_start_offset = undo_page_node[2]
				else:
					not_end = False # 跨FILE的哒咩


	f.close()
