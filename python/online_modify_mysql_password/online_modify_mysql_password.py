#!/usr/bin/env python
# -*- coding: utf-8 -*-
# writen by ddcw @https://github.com/ddcw
# 在线修改mysql密码的工具. 仅支持 mysql_native_password 插件的

import os
import sys
import struct
import hashlib
import binascii
import argparse

def _argparse():
	parser = argparse.ArgumentParser(add_help=False, description='在线修改mysqld进程的脚本')
	parser.add_argument('--help', '-h', action='store_true', dest="HELP", default=False,  help='show help')
	parser.add_argument('--password', '-p', dest="PASSWORD",  help='mysql new password')
	parser.add_argument('--old-password', dest="OLD_PASSWORD",  help='last modify password')
	parser.add_argument('--pid', dest="PID", help='mysql pid', type=int)
	parser.add_argument('--user', dest="USER", help='mysql account (user@host, root@localhost)')
	if parser.parse_args().HELP:
		parser.print_help()
		print('Example:')
		print(f'python3 f{sys.argv[0]} --user root@localhost')
		print(f'python3 f{sys.argv[0]} --user root@localhost --password 123456')
		print(f'python3 f{sys.argv[0]} --user root@localhost --password 123456 --pid `pidof mysqld`')
		sys.exit(0)
	if parser.parse_args().USER is None:
		print('必须使用 --user 指定用户')
		sys.exit(10)
	return parser.parse_args()

def encode_password(NEW_PASSWORD):
	return hashlib.sha1(hashlib.sha1(NEW_PASSWORD.encode()).digest()).digest()

# 在内存中查找某个关键词
def find_data_in_mem(pid,key):
	keysize = len(key)
	with open(f'/proc/{pid}/maps','r') as f:
		maps = f.readlines()
	
	result = []
	with open(f'/proc/{pid}/mem','rb') as f:
		for line in maps:
			addr = line.split()[0]
			_flags = line.split()[1]
			if _flags != 'rw-p':
				continue
			start_addr,stop_addr = addr.split('-')
			start_addr = int(start_addr,16)
			stop_addr  = int(stop_addr ,16)
			f.seek(start_addr,0)
			data = f.read(stop_addr-start_addr)
			offset = 0
			while True:
				offset = data.find(key,offset)
				if offset != -1:
					result.append([start_addr,stop_addr,offset])
					offset += keysize
				else:
					break
	return result

# 设置新密码, 是直接将旧密码改为新密码, 如果多个用户的密码是一样的, 则都会修改, 不修改mysql.user等信息
def set_new_password(OLD_PASSWORD,NEW_PASSWORD,pid):
	maps = find_data_in_mem(pid,OLD_PASSWORD)
	if len(maps) == 0:
		print('可能之前已经修改过了, 可以使用--old-password 指定上一次的密码')
		sys.exit(1)
	with open(f'/proc/{pid}/mem','r+b') as f:
		for start,stop,offset in maps:
			f.seek(start+offset-20,0)
			data = f.read(20)
			if data[-4:] != b'\x00\x00\x00\x00':
				continue
			# 5.7 255, 4, 0, 0, 0, 0
			# 8.0 41, 0, 0, 0, 0, 0, 0, 0
			print([ x for x in data ])
			f.seek(start+offset,0)
			f.write(NEW_PASSWORD)
	print(f'set new password succuss! ({binascii.hexlify(NEW_PASSWORD).decode()})')
		


def get_pid(): # 获取mysqld进程的pid
	pid = []
	for entry in os.listdir('/proc'):
		if not entry.isdigit():
			continue
		try:
			comm = '/proc/'+str(entry)+'/comm'
			with open(comm,'r') as f:
				if f.read() == 'mysqld\n':
					pid.append(entry)
		except:
			pass
	return pid



if __name__ == "__main__":
	parser = _argparse()
	user,host = parser.USER.split('@')
	flags = struct.pack('<B',len(host)) + host.encode() + struct.pack('<B',len(user)) + user.encode()
	PIDS = get_pid()
	pid = 0
	if parser.PID is not None:
		if str(parser.PID) in PIDS:
			pid = parser.PID
		else:
			print(f'pid:{parser.PID} not exists {PIDS}')
			sys.exit(0)
	elif len(PIDS) == 1:
		pid = PIDS[0]
	elif len(PIDS) == 0:
		print('当前不存在mysqld进程')
		sys.exit(2)
	else:
		print(f'当前存在多个mysqld进程, 请指定一个')
		sys.exit(3)
	MODIFY_PASSWORD = False # 是否要修改密码, 如果没有指定密码, 则仅查看即可. 若指定了密码, 则为强制修改
	NEW_PASSWORD = b''
	if parser.PASSWORD is not None:
		NEW_PASSWORD = encode_password(parser.PASSWORD)
		MODIFY_PASSWORD = True
	if parser.OLD_PASSWORD is not None:
		set_new_password(bytes.fromhex(parser.OLD_PASSWORD),NEW_PASSWORD,pid,)
		sys.exit(0)
	# 查看当前的密码
	maps = find_data_in_mem(pid,flags)
	if len(maps) == 0:
		print('没找到...')
		sys.exit(1)
	with open(f'/proc/{pid}/mem','rb') as f:
		for start,stop,offset in maps:
			f.seek(start,0)
			data = f.read(stop-start)
			MATCHED = True
			offset += len(flags)
			for i in range(29): # 29个权限
				if data[offset:offset+1] != b'\x01':
					MATCHED = False
					break
				else:
					offset += 2
			if not MATCHED:
				continue
			# 然后就是ssl,max_conn之类的信息
			for i in range(8):
				vsize = struct.unpack('<B',data[offset:offset+1])[0]
				offset += 1 + vsize
			# 然后就是mysql_native_password了
			vsize = struct.unpack('<B',data[offset:offset+1])[0]
			plugins = data[offset+1:offset+1+vsize].decode()
			offset += 1 + vsize
			if plugins != 'mysql_native_password':
				continue
			# 最后就是密码(password_expired之类的就不管了. 没必要)
			vsize = struct.unpack('<B',data[offset:offset+1])[0] # 肯定得是41, 就懒得验证了
			old_password = data[offset+1:offset+1+vsize].decode()
			print(f'{parser.USER} password:{old_password}  {start}-{stop}:{offset}') # mysql.user的信息
			if MODIFY_PASSWORD: # 要修改的密码实际上是二进制的, 修改page的是没用的
				set_new_password(bytes.fromhex(old_password[1:]),NEW_PASSWORD,pid,)
				# mysql.user也修改下, 不然再次修改的时候,就找不到位置了. 算逑!
				#with open(f'/proc/{pid}/mem','r+b') as fw:
				#	fw.seek(start+offset+1,0)
				#	fw.write(NEW_PASSWORD)
			break

			
