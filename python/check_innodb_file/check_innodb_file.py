import struct
import sys,os
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

			
def calculate_crc32c(data):
	crc = 0xFFFFFFFF
	for byte in data:
		crc = crc32_slice_table[(crc ^ byte) & 0xFF] ^ (crc >> 8)
	return crc ^ 0xFFFFFFFF


crc32_slice_table = create_crc32c_table()
filename = sys.argv[1]
if not os.path.exists(filename):
	print(f'USAGE: python sys.argv[0] xxx.ibd')
	sys.exit(1)
	
f = open(filename,'rb')
PAGENO = -1
while True:
	data = f.read(16384)
	PAGENO += 1
	if data == b'':
		break
	if data[:4] == b'\x00\x00\x00\x00'  and data[26:28] == b'\x00\x00':
		continue # 未使用的页
	checksum_field1 = struct.unpack('>L',data[:4])[0]
	checksum_field2 = struct.unpack('>L',data[-8:-4])[0]
	c1 = calculate_crc32c(data[4:26])
	c2 = calculate_crc32c(data[38:16384-8])
	#print('PAGENO:',PAGENO,"CHECKSUM:",checksum_field1,checksum_field2,(c1^c2)&(2**32-1))
	if checksum_field1 == checksum_field2 == (c1^c2)&(2**32-1):
		pass # 正常就不打印了, 不然太多
	else:
		print("BAD PAGE:",PAGENO)
