#@ddcw https://github.com/ddcw
#参考: https://cloud.tencent.com/developer/article/2237558
import argparse,glob,struct,datetime,time
import sys,os

def _argparse():
	parser = argparse.ArgumentParser(add_help=True, description='Analyzing the binlog of MySQL 8.0/5.7')
	parser.add_argument('--version', '-v', '-V', action='store_true', dest="VERSION", default=False, help='Show version')
	parser.add_argument("--detail", action="store_true", dest="DETAIL", default=False, help="show detail for every file")
	parser.add_argument("--relay-log",  action="store_true", dest="ISRELAY", default=False, help="for relay log")
	parser.add_argument("files", nargs="*", help="binlog/relay log list. support RE")
	if parser.parse_args().VERSION:
		print('VERSION: v0.2')
		sys.exit(0)
	return parser.parse_args()

class cbinlog(object):
	def __init__(self,):
		self.name = ''
		self.delete = 0
		self.update = 0
		self.insert = 0
		self.trx = 0
		self.table_map = {}
	
	def __str__(self,):
		if self.name != '':
			print(f'FILENAME: {self.name}')
		print(f'delete: {self.delete}')
		print(f'update: {self.update}')
		print(f'insert: {self.insert}')
		print(f'total:  {self.delete+self.update+self.insert}')
		print(f'trx:    {self.trx}')
		if len(self.table_map) > 0:
			print('detail:')
			for table_name in self.table_map:
				print(f"{table_name}: \ttotal:{self.table_map[table_name][0]}\tdelete:{self.table_map[table_name][1]}\tinsert{self.table_map[table_name][2]}\tupdate:{self.table_map[table_name][3]}\ttotal_size:{self.table_map[table_name][4]}")
		return ''
	
	def __add__(self,other):
		if isinstance(other, cbinlog):
			ncbinlog = cbinlog()
			ncbinlog.delete = self.delete + other.delete
			ncbinlog.update = self.update + other.update
			ncbinlog.insert = self.insert + other.insert
			ncbinlog.trx = self.trx + other.trx
			ncbinlog.table_map = self.table_map
			for table_name in other.table_map:
				if table_name in ncbinlog.table_map:
					ncbinlog.table_map[table_name] = [ other.table_map[table_name][i]+ncbinlog.table_map[table_name][i] for i in range(5) ]
				else:
					ncbinlog.table_map[table_name] = other.table_map[table_name]
			return ncbinlog
		else:
			raise ValueError("Can't add cbinlog with non-cbinlog type")

def btoint(bdata,t='little'):
	return int.from_bytes(bdata,t)

def event_header(bdata):
	timestamp, event_type, server_id, event_size, log_pos, flags = struct.unpack("<LBLLLh",bdata[0:19])
	return {"timestamp":timestamp,'event_type':event_type,'server_id':server_id,'event_size':event_size,'log_pos':log_pos,'flags':flags,}

def table_map_event_onlyname(bdata):
	offset = 8
	database_length = btoint(bdata[offset:offset+1])
	offset +=1
	database_name = bdata[offset:offset+database_length].decode() #0x00 结尾
	offset += database_length + 1
	table_length = btoint(bdata[offset:offset+1])
	offset +=1
	table_name = bdata[offset:offset+table_length].decode()
	return f'{database_name}.{table_name}'

def analyze_binlog(filename,isrelay):
	tcbinlog = cbinlog()
	tcbinlog.name = filename
	with open(filename,'rb') as f:
		if not isrelay:
			magic = f.read(4)
			if magic != b'\xfebin':
				print(f'{filename} not binlog')
				return tcbinlog
		current_table_name = ''
		while True:
			try:
				common_header = event_header(f.read(19))
			except:
				break
			if common_header == b'':
				break
			event_bdata = f.read(common_header['event_size']-19)

			if common_header['event_type'] == 19: #table_map event
				table_name = table_map_event_onlyname(event_bdata)
				current_table_name = table_name
				if table_name in tcbinlog.table_map:
					tcbinlog.table_map[table_name][0] += 1
				else:
					#总操作次数, delete,insert,update, total_size(bytes)
					tcbinlog.table_map[table_name] = [1,0,0,0,0]
			elif common_header['event_type'] == 16: #XID_EVENT
				tcbinlog.trx += 1
			elif common_header['event_type'] == 30:
				tcbinlog.insert += 1
				tcbinlog.table_map[current_table_name][2] += 1
				tcbinlog.table_map[current_table_name][4] += common_header['event_size']-19
			elif common_header['event_type'] == 31:
				tcbinlog.update += 1
				tcbinlog.table_map[current_table_name][3] += 1
				tcbinlog.table_map[current_table_name][4] += common_header['event_size']-19
			elif common_header['event_type'] == 32:
				tcbinlog.delete += 1
				tcbinlog.table_map[current_table_name][1] += 1
				tcbinlog.table_map[current_table_name][4] += common_header['event_size']-19
	return tcbinlog
				


if __name__ == '__main__':
	parser = _argparse()
	filelist = []
	for pattern in parser.files:
		filelist += glob.glob(pattern)
	fileset = set(filelist)
	if len(fileset) > 0:
		print('FILE LIST:')
		for x in fileset:
			print(x)
		print('')
	else:
		print('At least one binlog file')
		sys.exit(1)

	rcbinlog = cbinlog()
	for filename in fileset:
		tcbinlog = analyze_binlog(filename,parser.ISRELAY)
		if parser.DETAIL:
			print(tcbinlog)
		rcbinlog = rcbinlog + tcbinlog
	print('The summary results are as follows:')
	print(rcbinlog)
		
