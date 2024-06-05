#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# write by ddcw @https://github.com/ddcw
# mysqldump 导出进度查看脚本(python2写的, 问就是py3有编码问题)
# 用法: mysqldump | python mysqldump_rate.py --count 2000 --output-file=xxxx.sql

import sys,argparse
import time

def _argparse():
	parser = argparse.ArgumentParser(add_help=True, description='mysqldump导出速度查看, 感觉和拆分脚本合并一下也不错,导出的时候就顺便拆分了')
	parser.add_argument('--file', '-f' , type=argparse.FileType('r'),default=sys.stdin, dest='FILE',  help='mysqldump stream')
	parser.add_argument('--output-file','-o','-O',required=True, dest='OUTPUT_FILE',help="导出文件")
	parser.add_argument('--count','-c',dest='COUNT',help="表数量",default=999999)
	parser.add_argument('--version', action='store_true', dest="VERSION", default=False,  help='VERSION')

	if parser.parse_args().VERSION:
		print('VERSION: v0.1')
		sys.exit(1)

	return parser.parse_args()

if __name__ == '__main__':
	BG_TIME = time.time()
	parser = _argparse()
	f = parser.FILE # 换成f习惯点... -_-
	f2 = open(parser.OUTPUT_FILE,'w')
	COUNT = parser.COUNT
	CURRENT_TABLE = 0
	while True:
		data = f.readline()
		if data == "": #EOF
			break
		# 进度判断
		if data[:13] == "CREATE TABLE ":
			CURRENT_TABLE += 1
			msg = "[" + str(CURRENT_TABLE) + "/" + str(COUNT) + "]\t" + data.split()[-2]
			print(msg)
		f2.write(data)
	f2.close()
	msg = "\nCOST SECONDS: " + str(round(time.time()-BG_TIME,2)) + " s\n"
	print(msg)
