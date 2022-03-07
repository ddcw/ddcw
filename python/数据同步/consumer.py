#!/usr/bin/env python3
from kafka import KafkaConsumer,TopicPartition
import configparser
import os
import json
import time
import pickle
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker


config = configparser.ConfigParser()
config.read('conf.cnf')
bootstrap_servers=str(config.get('kafka','bootstrap_servers'))
my_topic=str(config.get('kafka','topic'))
dbfile=str(config.get('consumer','dbfile'))
dbtype=str(config.get('consumer','dbtype'))
host=str(config.get('consumer','host'))
port=int(config.get('consumer','port'))
user=str(config.get('consumer','user'))
password=str(config.get('consumer','password'))
service_name=str(config.get('consumer','service_name'))

remap_schema_rule=json.loads(config.get('consumer','remap_schema'))
remap_table_rule=json.loads(config.get('consumer','remap_table'))

def get_engine():
	if dbtype == 'mysql' :
		engine = create_engine('mysql+pymysql://{db_user}:{db_password}@{db_host}:{db_port}'.format(db_host=host, db_port=port, db_user=user, db_password=password, ))
	elif dbtype == 'oracle':
		engine = create_engine('oracle+cx_oracle://{db_user}:{db_password}@{db_host}:{db_port}/?service_name={db_servername}'.format(db_host=host, db_port=port, db_user=user, db_password=password, db_servername=service_name))
	elif dbtype == "postgresql":
		engine = create_engine('postgresql+psycopg2://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}'.format(db_host=host, db_port=port, db_user=user, db_password=password, ))
	else:
		engine = "暂时不支持其它类型的数据库"
		return False
	return engine

engine=get_engine()
session = sessionmaker(bind=engine)()


fd = os.open(dbfile,os.O_WRONLY | os.O_CREAT)
with open(dbfile, "rb") as f1:
	try:
		last_line = f1.readlines()[-1]
		latest_offset=json.loads(last_line)["offset"]
	except:
		latest_offset=-1
	

f = open(fd, 'a')


consumer = KafkaConsumer( bootstrap_servers=bootstrap_servers, enable_auto_commit = True, auto_commit_interval_ms = 5000,)
consumer.assign([TopicPartition(topic=my_topic, partition=0),])

consumer.seek(TopicPartition(topic=my_topic, partition=0), latest_offset+1) 

#做库和表的转换
def remap_schema(schema):
	try:
		return remap_schema_rule[schema]
	except :
		return schema

def remap_table(table):
	try:
		return remap_table_rule[table]
	except :
		return table


#传入dict 返回k=v的数据, 会做部分数据类型转换 目前支持date (char和int数据库自己支持, mysql还支持date隐式转换)
#timestamp to date参考  time.strftime("%Y-%m-%d %H:%M:%S",time.localtime(1646364730))  
#oracle to_date参考 TO_DATE('2022-03-03 8:30:25', 'YYYY-MM-DD HH:MI:SS')
#用逗号做分割, oracle中update set 只能用 逗号 分割,,,,   mysql的话 and 好像也行.... 
def get_kv(obj):
	value=""
	for x in obj:
		col_name=x
		col_value=obj[x]
		try:
			if col_value["type"] == "datetime" :
				date_format = time.strftime("%Y-%m-%d %H:%M:%S",time.localtime(col_value["value"]))
				if dbtype == "oracle":
					value += " , "+ str(col_name) +" = to_date('"+ str(date_format) + "','YYYY-MM-DD HH24:MI:SS')"
				else:
					value += " , " + str(col_name) + "='" + str(date_format) + "'"
		except:
			value += " , " + str(col_name) + "='" + str(col_value) + "'"
	value=value[2:]
	return value

#用and做分割, 
def get_kv_and(obj):
	value=""
	for x in obj:
		col_name=x
		col_value=obj[x]
		try:
			if col_value["type"] == "datetime" :
				date_format = time.strftime("%Y-%m-%d %H:%M:%S",time.localtime(col_value["value"]))
				if dbtype == "oracle":
					value += " AND "+ str(col_name) +" = to_date('"+ str(date_format) + "','YYYY-MM-DD HH24:MI:SS')"
				else:
					value += " AND " + str(col_name) + "='" + str(date_format) + "'"
		except:
			value += " AND " + str(col_name) + "='" + str(col_value) + "'"
	value=value[4:]
	return value
def get_cols(obj):
	value=""
	for x in obj:
		value += ", "+ str(x)
	value=value[1:]
	return value

#传入dict 返回字符串
def get_values(obj):
	value=""
	for x in obj:
		try:
			if x["type"] == "datetime" :
				date_format = time.strftime("%Y-%m-%d %H:%M:%S",time.localtime(x["value"])) 
				if dbtype == "oracle":
					value += ", to_date('"+ str(date_format) + "','YYYY-MM-DD HH24:MI:SS')"
				else:
					value += ", '" + str(date_format) + "'"
			else:
				pass
				
		except:
			value += ", '"+ str(x) + "'"
	value=value[1:]
	return value


sql=""
session.begin()
for msg in consumer:
	TYPE=json.loads(msg.value)["TYPE"]
	if TYPE == "XID":
		message={"xid":json.loads(msg.value)["XID"],"offset":msg.offset,"time":time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())}
		session.commit()
		f.write(json.dumps(message)+'\n')
		f.flush()
		session.begin()
		sql=""
	elif TYPE == "INSERT":
		for mydict in json.loads(msg.value)["DATA"]:
			schema_table = remap_schema(json.loads(msg.value)["SCHEMA"])+"."+remap_table(json.loads(msg.value)["TABLE"])
			columns = get_cols(mydict["values"].keys())
			values = get_values(mydict["values"].values())
			sql = "INSERT INTO %s ( %s ) VALUES ( %s )" % (schema_table, columns, values)
			session.execute(sql)
			#print(sql)
	elif TYPE == "DELETE":
		for mydict in json.loads(msg.value)["DATA"]:
			schema_table = remap_schema(json.loads(msg.value)["SCHEMA"])+"."+remap_table(json.loads(msg.value)["TABLE"])
			#where = ' AND '.join(['%s=%s' %(x, mydict["values"][x]) for x in mydict["values"]])
			where = get_kv_and(mydict["values"])
			sql = "DELETE FROM %s WHERE %s " %(schema_table, where)
			session.execute(sql)
			#print(sql)
	elif TYPE == "UPDATE":
		for mydict in json.loads(msg.value)["DATA"]:
			schema_table = remap_schema(json.loads(msg.value)["SCHEMA"])+"."+remap_table(json.loads(msg.value)["TABLE"])
			columns = get_kv(mydict["after_values"])
			where = get_kv_and(mydict["before_values"])
			sql = "UPDATE %s SET %s WHERE %s " %(schema_table, columns, where)
			session.execute(sql)
			#print(sql)
	elif TYPE == "DDL":
		DDL = json.loads(msg.value)["DATA"]
		schema = remap_schema(json.loads(msg.value)["SCHEMA"])
		message={"DDL":DDL,"offset":msg.offset,"time":time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())}
		session.commit()
		session.execute("use {schema}; ".format(schema=schema,))
		session.execute(DDL)
		session.commit()
		f.write(json.dumps(message)+'\n')
		f.flush()
		sql=""
		session.begin()
		#print(DDL)
	else:
		pass

#f.close()
