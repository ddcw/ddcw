#encoding:utf8
#!/usr/bin/env python



from pymysqlreplication import BinLogStreamReader
from kafka import KafkaProducer,KafkaConsumer,TopicPartition
from pymysqlreplication.row_event import (
    DeleteRowsEvent,
    UpdateRowsEvent,
    WriteRowsEvent,
    TableMapEvent,
)
from pymysqlreplication.event import (XidEvent,QueryEvent,RotateEvent,)
import json
import configparser
import pickle
import time
import datetime

config = configparser.ConfigParser()
config.read('conf.cnf')

MYSQL_SETTINGS = {
    "host": str(config.get('producer','host')),
    "port": int(config.get('producer','port')),
    "user": str(config.get('producer','user')),
    "passwd": str(config.get('producer','password')),
}

server_id=int(config.get('producer','server_id'))

only_schemas=str(config.get('producer','only_schemas'))
only_tables=str(config.get('producer','only_tables'))
ignored_schemas=str(config.get('producer','ignored_schemas'))
ignored_tables=str(config.get('producer','ignored_tables'))

bootstrap_servers=str(config.get('kafka','bootstrap_servers'))
my_topic=str(config.get('kafka','topic'))

consumer = KafkaConsumer(bootstrap_servers=bootstrap_servers, enable_auto_commit = True, auto_commit_interval_ms = 5000, )
consumer.assign([TopicPartition(topic=my_topic, partition=0),])

topic_partition_0=TopicPartition(topic=my_topic, partition=0)
offset_0=consumer.end_offsets([topic_partition_0])[topic_partition_0]
binlog_pos_flag=0 #为0的话 表示不指定binlog pos
if offset_0 >0:
	consumer.seek(TopicPartition(topic=my_topic, partition=0),offset_0-1)
	latest_binlog_pos=json.loads(next(consumer).value)["LOG_POSTION"] #message可能为空....., 我也不知道为啥  .  知道了,解析event的时候,每次会初始化value="" ...
	binlog_pos_flag=1

consumer.assign([TopicPartition(topic=my_topic, partition=1)])
topic_partition_1=TopicPartition(topic=my_topic, partition=1)
offset_1=consumer.end_offsets([topic_partition_1])[topic_partition_1]
binlog_file_flag=0
if offset_1> 0:
	consumer.seek(TopicPartition(topic=my_topic, partition=1),offset_1-1 )
	latest_binlog_file=json.loads(next(consumer).value)["DATA"]
	binlog_file_flag=1

#print(latest_binlog_pos,latest_binlog_file)

#处理特殊数据类型, 目前都只是转化为字符串.(MYSQL可以自动转换字符串为时间)
class MyJsonEncoder(json.JSONEncoder):
	def default(self,obj):
		if isinstance (obj, datetime.datetime ):
			return {"value":int(obj.timestamp()), "type":"datetime"}

def main():
	producer = KafkaProducer(bootstrap_servers=bootstrap_servers)
	if binlog_pos_flag == 1 and binlog_file_flag == 1:
		stream = BinLogStreamReader(connection_settings=MYSQL_SETTINGS,	server_id=server_id, blocking=True, resume_stream=True, log_file=latest_binlog_file, log_pos=latest_binlog_pos)
	else:
		stream = BinLogStreamReader(connection_settings=MYSQL_SETTINGS,	server_id=server_id, blocking=True, resume_stream=True, )
	
	

	for binlogevent in stream:
		value=""
		if isinstance(binlogevent, QueryEvent):
			#DDL语句  
			if binlogevent.query == "BEGIN":
				continue
			else:
				TYPE="DDL"
				TIMESTAMP=binlogevent.timestamp
				LOG_POSTION=binlogevent.packet.log_pos
				SCHEMA=binlogevent.schema
				DATA=binlogevent.query
				value={"TYPE":TYPE,"TIMESTAMP":TIMESTAMP,"LOG_POSTION":LOG_POSTION, "SCHEMA":bytes.decode(SCHEMA), "DATA":DATA}
					
		elif isinstance(binlogevent, TableMapEvent):
			TYPE="DATABASE"
			TIMESTAMP=binlogevent.timestamp
			LOG_POSTION=binlogevent.packet.log_pos
			SCHEMA=binlogevent.schema
			TABLE=binlogevent.table
			value={"TYPE":TYPE,"TIMESTAMP":TIMESTAMP,"LOG_POSTION":LOG_POSTION, "SCHEMA":SCHEMA, "TABLE":TABLE}
		elif isinstance(binlogevent, DeleteRowsEvent) or isinstance(binlogevent, UpdateRowsEvent) or isinstance(binlogevent, WriteRowsEvent):
			if isinstance(binlogevent, DeleteRowsEvent):
				TYPE="DELETE"
			elif isinstance(binlogevent, UpdateRowsEvent):
				TYPE="UPDATE"
			elif isinstance(binlogevent, WriteRowsEvent):
				TYPE="INSERT"
			TIMESTAMP=binlogevent.timestamp
			LOG_POSTION=binlogevent.packet.log_pos
			SCHEMA=binlogevent.schema
			TABLE=binlogevent.table
			DATA=binlogevent.rows
			value={"TYPE":TYPE,"TIMESTAMP":TIMESTAMP,"LOG_POSTION":LOG_POSTION, "SCHEMA":SCHEMA, "TABLE":TABLE, "DATA":DATA}
		elif isinstance(binlogevent, XidEvent):
			TYPE="XID"
			XID=binlogevent.xid
			TIMESTAMP=binlogevent.timestamp
			LOG_POSTION=binlogevent.packet.log_pos
			value={"TYPE":TYPE, "XID":XID, "TIMESTAMP":TIMESTAMP, "LOG_POSTION":LOG_POSTION}
		elif isinstance(binlogevent, RotateEvent):
			TYPE="BINLOG_FILE"
			DATA=binlogevent.next_binlog
			value={"TYPE":TYPE, "DATA":DATA}
			bytes_value = bytes(json.dumps(value),encoding = "utf8")
			producer.send(my_topic,value=bytes_value,key=b"mysqlbinlog", partition=1 )
			continue
		else:
			continue
			
		bytes_value = bytes(json.dumps(value,cls=MyJsonEncoder),encoding = "utf8", )
		#bytes_value = pickle.dumps(value) 转换后,都不认识是啥了....
		producer.send(my_topic,value=bytes_value,key=b"mysql",partition=0)

	stream.close()


if __name__ == "__main__":
	main()
