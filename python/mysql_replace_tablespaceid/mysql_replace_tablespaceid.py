#!/usr/bin/env python
# -*- coding: utf-8 -*-
# write by ddcw
# innodb 表空间中的 space_id的替换
# 表空间id位于34-38 大端字节序

PAGE_SIZE = 16384
import sys,struct,os
args = len(sys.argv)
if args == 2:
	with open(sys.argv[1],'rb') as f:
		data = f.read(PAGE_SIZE) 
		space_id = struct.unpack('>L',data[34:38])[0]
		msg = "TABLESPACE ID: " + str(space_id) + '\n'
		sys.stdout.write(msg)
		sys.exit()
elif args == 4:
	filename = sys.argv[1]
	space_id = int(sys.argv[2])
	filename2 = sys.argv[3]
	if not os.path.exists(filename):
		msg = filename + " IS NOT EXISTS.\n"
		sys.stdout.write(msg)
		sys.exit(1)
	elif int(os.stat(filename).st_size % PAGE_SIZE) != 0:
		msg = filename + " Maybe not mysql's ibd file\n"
		sys.stdout.write(msg)
		sys.exit(2)
	if os.path.exists(filename2):
		msg = filename2 + " IS EXISTS. Please rename it\n"
		sys.stdout.write(msg)
		sys.exit(3)
else:
	msg = "\nExample: \npython " + sys.argv[0] + " test.ibd\npython " + sys.argv[0] + " test.ibd 123456 new_test.ibd\n\n"
	sys.stdout.write(msg)
	sys.exit(4)

def create_crc32c_table():
	poly = 0x82f63b78
	table = []
	for i in range(256):
		crc = i
		for _ in range(8):
			if crc & 1:
				crc = (crc >> 1) ^ poly
			else:
				crc >>= 1
		table.append(crc)
	return table

crc32_slice_table = create_crc32c_table()
def calculate_crc32c(data):
	crc = 0xFFFFFFFF
	for byte in bytearray(data): # for PY2
		crc = crc32_slice_table[(crc ^ byte) & 0xFF] ^ (crc >> 8)
	return crc ^ 0xFFFFFFFF

def replace_crc32(data):
	c1 = calculate_crc32c(data[4:26])
	c2 = calculate_crc32c(data[38:PAGE_SIZE-8])
	cb = struct.pack('>L',(c1^c2)&(2**32-1))
	data = cb + data[4:PAGE_SIZE-8] + cb + data[PAGE_SIZE-4:]
	return data



f2 = open(filename2,'wb')
SPACE_ID = struct.pack('>L',space_id)
with open(filename, 'rb') as f:
	# FSP 38-42 (SPACE_HEADER:4 is SPACE ID) 
	data = f.read(PAGE_SIZE)
	data = data[:34] + SPACE_ID + SPACE_ID + data[42:]
	data = replace_crc32(data)
	f2.write(data)
	while True:
		data = f.read(PAGE_SIZE)
		if data == b'':
			break
		if data[34:38] != b'\x00\x00\x00\x00':
			data = replace_crc32(data[:34] + SPACE_ID + data[38:])
		f2.write(data)

f2.flush()
f2.close()
msg = 'Write to filename: ' + filename2 + '\n'
sys.stdout.write(msg)
