import struct
import os

def listevent(filename='m3308.001014',):
	el = []
	with open(filename,'rb') as f:
		magic = f.read(4)
		if magic != b'\xfebin':
			return []
		while True:
			header = f.read(19)
			if len(header) == 19:
				timestamp, event_type, server_id, event_size, log_pos, flags = struct.unpack("<LBLLLh",header[0:19])
				el.append({'timestamp':timestamp,'start_pos':f.tell()-19,'end_pos':log_pos,'size':event_size,'event_type':event_type})
				event_body = f.read(event_size-19)
			else:
				print('endsize:',f.tell(),'event_count',len(el))
				break
		return el

def mevent_type(filename='m3308.001014',start_pos=4,new_value=250):
	f = os.open(filename, os.O_RDWR|os.O_CREAT, 0o644)
	os.lseek(f, start_pos+4, 0)
	os.write(f, struct.pack('<B',new_value)) 
	os.close(f)
	return True

def read_event(filename='m3308.001014',start_pos=4,max_size=100000):
	with open(filename,'rb') as f:
		f.seek(start_pos,0)
		header = f.read(19)
		timestamp, event_type, server_id, event_size, log_pos, flags = struct.unpack("<LBLLLh",header[0:19])
		if event_size < max_size:
			event_body = f.read(event_size-19)
			return {'timestamp':timestamp,'event_type':event_type,'server_id':server_id,'event_size':event_size,'log_pos':log_pos,'flags':flags,'event_body':event_body}
		else:
			return None
	
