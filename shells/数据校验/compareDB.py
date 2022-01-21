#!/usr/bin/env python3
#比较数据一致性的
import cx_Oracle
import pymysql
import psycopg2 
import configparser
import pandas
import datacompy
from sqlalchemy import create_engine

#获取配置文件信息
config = configparser.ConfigParser()
config.read('db.ini')
SOURCE_DB=config.get('DATA','source')
TARGET_DB=config.get('DATA','target')
PROCESS_COUNT=config.get('DATA','process') #并行度, TODO
RESULT_0=config.get('DATA','result_0') #不一致的数据内容就会记录到这个文件里面
RESULT_1=config.get('DATA','result_1') #目标差的数据行
PK=config.get('DATA','pk')
SOURCE_SQL=config.get('DATA','sql_source')
TARGET_SQL=config.get('DATA','sql_target')



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

sql=SOURCE_SQL
print("源端拉取数据..")
df_source=pandas.read_sql_query(SOURCE_SQL,get_engine(SOURCE_DB))
print("源端总行数: ",len(df_source))
print("目标端拉取数据..")
df_target=pandas.read_sql_query(TARGET_SQL,get_engine(TARGET_DB))
print("目标端总行数: ",len(df_target))
print("")

c = datacompy.Compare(df_source, df_target, join_columns=[PK])
data_inconsistency=c.all_mismatch()  #数据不一致的行
data_dest_lost=c.df1_unq_rows #目标表缺少的数据行 (原表独有的数据行)
data_dest_uniq=c.df2_unq_rows #目标独有的数据行, 目标多出来的数据行


if len(data_inconsistency) > 0:
	print("\n数据不一致的行有 {n} 条/行 概览如下: (详情见文件{RESULT_0})".format(n=len(data_inconsistency), RESULT_0=RESULT_0))
	print(data_inconsistency)
	data_inconsistency.to_csv(RESULT_0, header=True, index=False)
else:
	print("\n源端目标端数据一致(不代表目标端与源端数据行数一致)")

if len(data_dest_lost) > 0:
	print("\n目标端差 {n} 条/行数据 概览如下:(详情见文件{RESULT_1})".format(n=len(data_dest_lost), RESULT_1=RESULT_1))
	print(data_dest_lost)
	data_dest_lost.to_csv(RESULT_1, header=True, index=False)

if len(data_dest_uniq) > 0:
	print("\n目标端多了 {n} 条/行数据 概览如下:".format(n=len(data_dest_uniq)))
	print(data_dest_uniq)

