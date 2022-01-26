#!/usr/bin/env python3
#比较数据一致性的
import cx_Oracle
import pymysql
import psycopg2 
import configparser
import pandas
import datacompy
import time
import gc
import threading
from sqlalchemy import create_engine

#获取配置文件信息
config = configparser.ConfigParser()
config.read('db.ini')
SOURCE_DB=config.get('DATA','source')
TARGET_DB=config.get('DATA','target')
PROCESS_COUNT=config.get('DATA','process') #并行度, TODO
RESULT_0=config.get('DATA','result_0') #不一致的数据内容就会记录到这个文件里面
RESULT_1=config.get('DATA','result_1') #一致的数据内容就会记录到这个文件里面
PK=config.get('DATA','pk')
SOURCE_SQL=config.get('DATA','sql_source')
if ' where ' in SOURCE_SQL.lower():
	SOURCE_SQL_FORMAT = str(SOURCE_SQL) + " and "
else:
	SOURCE_SQL_FORMAT = SOURCE_SQL + " where "
TARGET_SQL=config.get('DATA','sql_target')
if ' where ' in TARGET_SQL.lower():
	TARGET_SQL_FORMAT = str(TARGET_SQL) + " and "
else:
	TARGET_SQL_FORMAT = TARGET_SQL + " where "
TWO_COMPARE=config.get('DATA','two_compare')
COMPARE_PERSENT=int(config.get('DATA','COMPARE_PERSENT'))
COMPARE_ROWS=int(config.get('DATA','COMPARE_ROWS'))
#SOURCE_PK=config.get('DATA','pk_source')
#TARGET_PK=config.get('DATA','pk_target')

#SOURCE_SQL="select id,name from t1 where id>10;"
#TARGET_SQL="select id,name from t1 where id>10;"


def get_engine(db):
	if db[0:5] == 'MYSQL' or db[0:11] == 'TDSQL-MYSQL' or db[0:5] == 'HOTDB':
		db_host = config.get(db,'db_host')
		db_port = config.get(db,'db_port')
		db_user = config.get(db,'db_user')
		db_password = config.get(db,'db_password')
		db_name = config.get(db,'db_name')
		engine = create_engine('mysql+pymysql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}'.format(db_host=db_host, db_port=db_port, db_user=db_user, db_password=db_password, db_name=db_name))
	elif db[0:6] == 'ORACLE':
		db_host = config.get(db,'db_host')
		db_port = config.get(db,'db_port')
		db_user = config.get(db,'db_user')
		db_password = config.get(db,'db_password')
		db_servername = config.get(db,'db_servername')
		engine = create_engine('oracle+cx_oracle://{db_user}:{db_password}@{db_host}:{db_port}/?service_name={db_servername}'.format(db_host=db_host, db_port=db_port, db_user=db_user, db_password=db_password, db_servername=db_servername))
	elif db[0:10] == "POSTGRESQL":
		db_host = config.get(db,'db_host')
		db_port = config.get(db,'db_port')
		db_user = config.get(db,'db_user')
		db_password = config.get(db,'db_password')
		db_name = config.get(db,'db_name')
		engine = create_engine('postgresql+psycopg2://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}'.format(db_host=db_host, db_port=db_port, db_user=db_user, db_password=db_password, db_name=db_name))
	else:
		engine = "暂时不支持其它类型的数据库"
		return FALSE
	return engine

SOURCE_ENGINE=get_engine(SOURCE_DB)
TARGET_ENGINE=get_engine(TARGET_DB)
begin_time=time.time()
t1=begin_time 
print("获取源端数据中...",end='',flush=True) #flush=True 表示直接输出, 不缓存, 不然屏幕还是可能不显示
df_source=pandas.read_sql_query(SOURCE_SQL,SOURCE_ENGINE)
t2=time.time()
print(" (耗时: {n} 秒) ".format(n=round((t2-t1),2)))

print("获取目标端数据中... ",end="",flush=True)
df_target=pandas.read_sql_query(TARGET_SQL,TARGET_ENGINE)
t3=time.time()
print(" (耗时: {n} 秒) ".format(n=round((t3-t2),2)))
print("源端总行数: ",len(df_source))
print("目标端总行数: ",len(df_target))
print("")


c = datacompy.Compare(df_source, df_target, join_columns=[PK])
t4=time.time()
df_source_len = len(df_source)
del df_source,df_target #释放变量 
gc.collect() #回收内存
data_inconsistency=c.all_mismatch()  #数据不一致的行
data_inconsistency_count = len(data_inconsistency)
#data_dest_lost=c.df1_unq_rows #目标表缺少的数据行 (原表独有的数据行)
#data_dest_uniq=c.df2_unq_rows #目标独有的数据行, 目标多出来的数据行


#比较两次, 第二次的差异和第一次的差异取交集就是可能不一致的行
def get_key():
	for row in data_inconsistency.itertuples():
		yield getattr(row,PK)
def compare_db_2(process_n) :
	global data_inconsistency_count
	#global data_inconsistency2
	while True:
		try:
			pk_value = next(aa)
		except:
			return 
		source_sql =  SOURCE_SQL_FORMAT + " " + PK + " = " + str(pk_value)
		df_s_1 = pandas.read_sql_query(source_sql,SOURCE_ENGINE)
		target_sql =  TARGET_SQL_FORMAT + " " + PK + " = " + str(pk_value)
		df_t_1 = pandas.read_sql_query(target_sql,TARGET_ENGINE)
		c3 = datacompy.Compare(df_s_1, df_t_1, join_columns=[PK])
		bu_pi_pei_de_hangshu = len(c3.all_mismatch())
		#print(target_sql)
		if bu_pi_pei_de_hangshu == 0 :
			continue
		else:
			threadLock.acquire()
			data_inconsistency_count += bu_pi_pei_de_hangshu
			#data_inconsistency2.append(c3.all_mismatch())
			threadLock.release()


aa=get_key()
		
if TWO_COMPARE == "1" and len(data_inconsistency) > 0 :
	print("第一次比较一致性耗时: {n} 秒".format(n=round((t4-t3),2)))
	print("第一次比较总耗时: {n} 秒".format(n=round((t4-t1),2)))
	print("第一次对比不一致的行数为: {n}".format(n=len(data_inconsistency)))
	print("\n\n")
	print("正在进行第二次比较")
	
	if round(len(data_inconsistency)) < round(df_source_len/100*COMPARE_PERSENT) and round(len(data_inconsistency)) < COMPARE_ROWS :
		#print("开始跑多线程 ",PROCESS_COUNT)
		#待优化, 这效率太低了....
		print("不一致数据量较小({n}), 将只比较不一致的数据".format(n=data_inconsistency_count))
		threadLock  = threading.Lock()
		data_inconsistency_count = 0
		t7=time.time()
		thread_list={}
		#data_inconsistency2 = data_inconsistency.drop(index=data_inconsistency.index)
		for process in range(1,int(PROCESS_COUNT)):
			thread_list[process]=threading.Thread(target=compare_db_2,args=(process,))
		for process in range(1,int(PROCESS_COUNT)):
			thread_list[process].start()
		for process in range(1,int(PROCESS_COUNT)):
			thread_list[process].join()
		t8=time.time()
		print("第二次比较总耗时: {n}".format(n=round((t8-t7),2)))
	else:
		print("开始拉取源端数据..",end="",flush=True)
		df_source=pandas.read_sql_query(SOURCE_SQL,SOURCE_ENGINE)
		t6=time.time()
		print(" (耗时: {n} 秒) ".format(n=round((t6-t4),2)))
		print("开始拉取目标端数据..",end="",flush=True)
		df_target=pandas.read_sql_query(TARGET_SQL,TARGET_ENGINE)
		t7=time.time()
		print(" (耗时: {n} 秒) ".format(n=round((t7-t6),2)))
		print("数据拉取完成, 开始进行第二次对比..")
		c2 = datacompy.Compare(df_source, df_target, join_columns=[PK])
		data_inconsistency2 = c2.all_mismatch()
		c3 = datacompy.Compare(data_inconsistency,data_inconsistency2,join_columns=[PK])
		data_inconsistency = c3.intersect_rows
		t8=time.time()
		print("第二次比较一致性耗时: {n}".format(n=round((t8-t7),2)))
		print("第二次比较总耗时: {n}".format(n=round((t8-t4),2)))
		data_inconsistency_count = len(data_inconsistency)

if len(data_inconsistency) > 0:
	print("\n最终数据不一致的行有 {n} 条/行 ".format(n=data_inconsistency_count))
	#print("\n数据不一致的行有 {n} 条/行 概览如下: (详情见文件{RESULT_0})".format(n=len(data_inconsistency), RESULT_0=RESULT_0))
	#print(data_inconsistency[PK])
	#data_inconsistency.to_csv(RESULT_0, header=True, index=False)
else:
	print("\n源端目标端数据一致(不代表目标端与源端数据行数一致)")

#if len(data_dest_lost) > 0:
#	print("\n目标端差 {n} 条/行数据 概览如下:(详情见文件{RESULT_1})".format(n=len(data_dest_lost), RESULT_1=RESULT_1))
#	print(data_dest_lost)
#	data_dest_lost.to_csv(RESULT_1, header=True, index=False)
#
#if len(data_dest_uniq) > 0:
#	print("\n目标端多了 {n} 条/行数据 概览如下:".format(n=len(data_dest_uniq)))
#	print(data_dest_uniq)
#
print("\n总耗时: {n} 秒".format(n=round((time.time()-begin_time),2)))
