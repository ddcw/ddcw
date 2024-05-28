#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# write by ddcw @https://github.com/ddcw
# 分析mysql慢日志的, 

import sys,os
import datetime
import re
from decimal import Decimal

if len(sys.argv) <= 1:
	msg = "USAGE: python3 " + str(sys.argv[0]) + " /PATH/slow3314.log\n"
	sys.stdout.write(msg)
	sys.exit(1)

filename = sys.argv[1]

SLOWLOG_DICT = {} #取HASH,没必要, 直接把SQL作为key
ADDHOURS = datetime.timedelta(hours=8)
PATTERN_UH = re.compile(r"\[([^\[\]]+)\]")
PATTERN_KV = re.compile(r"(\w+):\s+([0-9.]+)")
with open(filename,'r') as f:
	log_time = None #日志记录时间, 基本上可以算是sql执行结束时间
	user_host = None #执行慢SQL的账号
	Query_time = None
	Lock_time = None
	Rows_sent = None
	Rows_examined = None # 服务端所产生的行数. 是可能大于表的总行数的. select * from db1.t1 limit 10 则为总行数+10
	extra_info = None #Thread_id Errno Bytes_received ...
	sql = ""
	NOT_BREAK_FLAG = True
	while NOT_BREAK_FLAG:
		data = f.readline()
		if data == '':
			NOT_BREAK_FLAG = False
		# Time: 
		if data[:8] == "# Time: " or not NOT_BREAK_FLAG:
			if log_time is not None: #记录上一条SQL
				if sql in SLOWLOG_DICT and SLOWLOG_DICT[sql]['user_host'] == user_host:
					SLOWLOG_DICT[sql]['log_time'].append(      log_time)
					SLOWLOG_DICT[sql]['Query_time'].append(    Query_time)
					SLOWLOG_DICT[sql]['Lock_time'].append(     Lock_time)
					SLOWLOG_DICT[sql]['Rows_sent'].append(     Rows_sent)
					SLOWLOG_DICT[sql]['Rows_examined'].append( Rows_examined)
					SLOWLOG_DICT[sql]['extra_info'].append(    extra_info)
				else:
					SLOWLOG_DICT[sql] = {}
					SLOWLOG_DICT[sql]['user_host']     = user_host
					SLOWLOG_DICT[sql]['log_time']      = [log_time]
					SLOWLOG_DICT[sql]['Query_time']    = [Query_time]
					SLOWLOG_DICT[sql]['Lock_time']     = [Lock_time]
					SLOWLOG_DICT[sql]['Rows_sent']     = [Rows_sent]
					SLOWLOG_DICT[sql]['Rows_examined'] = [Rows_examined]
					SLOWLOG_DICT[sql]['extra_info']    = [extra_info]
			elif data != "":
				log_time = data.split()[-1]
				if log_time[-1] == 'Z':
					log_time = datetime.datetime.strptime(log_time, "%Y-%m-%dT%H:%M:%S.%fZ") + ADDHOURS
				else:
					log_time = datetime.datetime.strptime(log_time, "%Y-%m-%dT%H:%M:%S.%f+08:00")
				#log_time = log_time..timestamp() # 转为float
			sql = ""
				
		# User@Host: 
		elif data[:13] == "# User@Host: ":
			user_host = "@".join(PATTERN_UH.findall(data))

		# Query_time: 
		elif data[:14] == "# Query_time: ":
			kv = {key: Decimal(value) for key, value in PATTERN_KV.findall(data)}
			Query_time = kv['Query_time']
			Lock_time = kv['Lock_time']
			Rows_sent = kv['Rows_sent']
			Rows_examined = kv['Rows_examined']
			# extra_info TODO

		elif data[:14] == "SET timestamp=":
			continue
		# Time mysqld刚启动时产生的header.
		elif data[:4] == "Time":
			log_time = None
		else: # 剩下的就是SQL了
			sql += data


# 输出慢日志信息了.
for sql in SLOWLOG_DICT:
	# 过滤规则
	if len(SLOWLOG_DICT[sql]['Query_time']) < 0:
		continue
	sys.stdout.write("\n")
	sys.stdout.write(f"{''.ljust(20)}{'TOTAL'.ljust(20)}{'MIN'.ljust(20)}{'MAX'.ljust(20)}{'AVG'.ljust(20)}\n")
	for k in ['Query_time','Lock_time','Rows_sent','Rows_examined']:
		_total = sum(SLOWLOG_DICT[sql][k])
		_min = min(SLOWLOG_DICT[sql][k])
		_max = max(SLOWLOG_DICT[sql][k])
		_avg = round(_total / len(SLOWLOG_DICT[sql][k]),6)
		sys.stdout.write(f"{k.ljust(20)}{str(_total).ljust(20)}{str(_min).ljust(20)}{str(_max).ljust(20)}{str(_avg).ljust(20)}\n")
	sys.stdout.write(f"EXECUTE_TIME:{len(SLOWLOG_DICT[sql]['Query_time'])}\n{sql}\n")
