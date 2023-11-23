#!/usr/bin/env python3
#write by ddcw @https://github.com/ddcw
from multiprocessing import Process,Queue
from datetime import datetime, timedelta
#from threading import Thread
#from queue import Queue
import os,sys,pymysql
import yaml,time
import random
import signal

SPECIAL_VAR='_VARFORBENCMYSQLBYDDCW_'
DATE_FORMAT = "%Y-%m-%d %H:%M:%S"
#速度如下. 计算时间的时候, 可以减去这个常量(各种var的时间加起来)
#emoji: 33428.11
#int: 703623.31
#datetime: 333671.23
#zh: 33632.85
#en: 53800.98

#生成随机整数
def getgen_int(start,stop):
	while True:
		yield(random.randint(start,stop))

#生成随机datetime
def getgen_datetime(start,stop):
	start = datetime.strptime(start, DATE_FORMAT)
	stop = datetime.strptime(stop, DATE_FORMAT)
	rangesecond = int((stop - start).total_seconds())
	while True:
		yield(start + timedelta(seconds=random.randint(0,rangesecond)))

#生成随机中文
def getgen_zh(start,stop):
	while True:
		yield ''.join(chr(random.randint(0x4E00, 0x9FFF)) for _ in range(random.randint(start,stop)))
		
#生成随机英文
def getgen_en(start,stop):
	strings = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
	while True:
		yield ''.join(random.choice(strings) for _ in range(random.randint(start,stop)))

#生成随机表情(就79个,其它的表情懒得找)
def getgen_emoji(start,stop):
	while True:
		yield ''.join(chr(random.randint(0x1F600, 0x1F64F)) for _ in range(random.randint(start,stop)))

def getgen_custom(start,stop):
	while True:
		yield ''.join(chr(random.randint(start[0], start[1])) for _ in range(random.randint(stop[0],stop[1])))

def getgen_range(start,step):
	while True:
		yield start
		start += step

def conn_mysql(minfo:dict)->tuple:
	try:
		conn = pymysql.connect(**minfo)
		return True,conn
	except Exception as e:
		print(e)
		return False,str(e)

#根据TRX['rw']['var']生成字典变量(gen), 每个线程就第一次初始化一下
def var_to_gen(VAR,):
	dd = {}
	for var_name,var_type,var_start,var_stop in VAR:
		ff = f'dd[var_name] = getgen_{var_type}(var_start,var_stop)'
		exec(ff)
	return dd

#返回一次var值
def var_to_dict(VAR):
	dd = {}
	for var in VAR:
		dd[var] = next(VAR[var])
	return dd

#根据TRX['rw']['sql']['value']生成相关字典
def var_to_set(vard,var):
	return tuple( vard[x] for x in var )
	

def workbench(TRX,DB,q,RUNTIME):
	status,conn = conn_mysql(DB)
	errors = 0
	qeuries = 0
	trx = 0
	response = []
	BT_TIME = time.time()
	stoptime = RUNTIME + time.time()
	VARGEN = var_to_gen(TRX['var'])
	sqllist = []
	for _sql in TRX['sql']:
		sql = _sql['statement']
		if 'value' in _sql:
			HAVE_VARIABLES = True
			_vars = _sql['value']
		else:
			HAVE_VARIABLES = False
			_vars = []
		sqllist.append([sql,HAVE_VARIABLES,_vars])
	while time.time() < stoptime:
		#初始化变量信息
		vardict = var_to_dict(VARGEN)
		start_time = time.time()
		conn.begin()
		cursor = conn.cursor()
		for sql,HAVE_VARIABLES,value in sqllist:
			try:
				if HAVE_VARIABLES:
					cursor.execute(sql,var_to_set(vardict,value))
				else:
					cursor.execute(sql)
				data = cursor.fetchall()
				qeuries += 1
			except:
				cursor.execute('rollback;')
				errors += 1
				break
		cursor.close()
		conn.commit()
		stop_time = time.time()
		trx += 1
		response.append(stop_time-start_time)
	q.put([errors,qeuries,trx,sum(response),max(response),min(response)])
		

def showProgress(q,p,rt):
	errors = 0
	trx = 0
	queries = 0
	response = 0
	max_time = []
	min_time = []
	for x in range(p):
		rsp = q.get()
		errors += rsp[0]
		queries += rsp[1]
		trx += rsp[2]
		response += rsp[3]
		max_time.append(rsp[4])
		min_time.append(rsp[5])
	tps = round(trx/rt,2)
	qps = round(queries/rt,2)
	maxr = round(max(max_time)*1000,2)
	minr = round(min(min_time)*1000,2)
	avgr = round(response*1000/trx,2)
	errorr = round(errors/rt,2)
	print(f"thr:{p:<8}\t{tps:<12}\t{qps:<12}\t{avgr:<12}\t{maxr:<12}\t{minr:<12}\t{errorr}")
	#print('errors',round(errors/rt,2),'max',round(max(max_time),2),'min',round(min(min_time),2),'avg',round(sum(response)*1000/trx,2),'TPS',round(trx/rt,2),'QPS', round(queries/rt,2) )
		

if __name__ == '__main__':
	if len(sys.argv) <= 1:
		print(f'python {sys.argv[0]} xxx.yaml')
		sys.exit(0)

	conf_filename = sys.argv[1]
	if os.path.exists(conf_filename):
		with open(conf_filename, 'r', encoding="utf-8") as f:
			inf_data =  f.read()
		conf = yaml.load(inf_data,Loader=yaml.Loader)
	else:
		print(f'{sys.argv[0]} does not exist')
		sys.exit(1)

	q = Queue()
	global p
	def signal_handler(signum, frame):
		for pro in p:
			try:
				p[pro].terminate()
			except:
				pass
		sys.exit(2)
	signal.signal(signal.SIGUSR1, signal_handler)
	signal.signal(signal.SIGINT, signal_handler)
	print("THREADS     \tTPS         \tQPS         \tAVG(ms)     \tMAX(ms)     \tMIN(ms)     \tERRORS")
	p = {}
	for parallel in range(conf['GLOBAL']['START'],conf['GLOBAL']['STOP'],conf['GLOBAL']['STEP']):
		for x in range(parallel):
			p[x] = Process(target=workbench,args=(conf['TRX'][0],conf['GLOBAL']['DB'],q,conf['GLOBAL']['RUNTIME']))
		for x in range(parallel):
			p[x].start()
		for x in range(parallel):
			p[x].join()
		showProgress(q,parallel,conf['GLOBAL']['RUNTIME'])
