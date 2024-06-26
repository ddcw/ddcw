#!/usr/bin/env python
# write by ddcw https://github.com/ddcw
# 一个脚本, 用来记录做过的事情, 和安排.
# 只使用内置Python模块
# 理由: 外包,没得专门的系统来管理, 全靠记忆力.... 
# 只支持本地访问, 不支持远程访问(简单一点)
# 使用方法: python3 miniWorkNote.py  然后浏览器访问即可
# 数据存储在 .db (sqlite3) 文件, 最开始打算不使用数据库的, 但修改不方便, 就还是整了一个
# 还会保留一份SQL文件. 方便写入其它数据库
# 界面设计
"""
----NOTE------------------------PLAN----------
|  worktime          |  变更时间(计划时间)    |
|  工作内存简述      |  变更内容              |
|  详情              |  对接人                |
|                    |                        |
|  ADD  FLUSH        |  ADD  FLUSH            |
-----------------------------------------------
|  本周周报   上周周报                        |
-----------------------------------------------
| WORK 1  改|详|删   | PLAN 1   详|完成       |
| WORK 2  改|详|删   | PLAN 2   详|完成       |
| WORK 3  改|详|删   | PLAN 3   详|完成       |
| WORK 4  改|详|删   |                        |
"""
# CHAGE LOG
# at 2024.06.21 init
# at 2024.06.26 finish

# 变量名.
BIND_HOST = '192.168.101.21'   # 监听的ip
BIND_PORT = 80                 # 监听的端口
DB_FILE   = 'miniWorkNote.db'  # 保存数据的db文件, sqlite3
SQL_FILE  = 'miniWorkNote.sql' # 保存数据的sql, 含DDL. like REDO
SAVE_DAYS = 3650000            # 保存天数. (还没实现...)

# 表结构定义
MINIWN_DDL = ["""
create table work(
    work_id bigint primary key, -- 使用时间戳作为ID吧(为了兼容性,就不使用comment了)
    work_author varchar(255) default 'ddcw', -- 相关人员 
    work_dt datetime, -- 修改时间
    work_status varchar(20), -- 完成/未完成/异常/已删除
    work_si varchar(255), -- 简述
    work_detail text, -- 详情
    work_other varchar(255) -- 保留字段
);
""","""
create table plan(
    plan_id bigint primary key,
    plan_author varchar(255) default 'ddcw',
    plan_dt datetime, -- 变更时间
    plan_update datetime, -- 这行数据的修改时间, 可以当作是完成时间
    plan_status varchar(20), -- 状态, 完成之后要手动设置为已完成. (已完成/未完成/异常)
    plan_contact, -- 对接人
    plan_si varchar(255), -- 任务内容
    plan_detail varchar(255), -- 任务内容
    plan_other varchar(255) -- 保留字段
);
"""
]

import os,sys,signal
import datetime
import time
import sqlite3
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
import threading
import urllib.parse
import json

# 做全局初始化
if os.path.exists(SQL_FILE):
	SQL_FD = open(SQL_FILE,'a')
else:
	SQL_FD = open(SQL_FILE,'w')
	# 更新下基础DDL
	for ddl in MINIWN_DDL:
		SQL_FD.write(ddl)
	SQL_FD.write('\n') # 再来个换行, 好看点
	SQL_FD.flush()

if os.path.exists(DB_FILE):
	CONN = sqlite3.connect(DB_FILE)
else: # 不存在的话, 就初始化表结构
	CONN = sqlite3.connect(DB_FILE)
	for ddl in MINIWN_DDL:
		cursor = CONN.cursor()
		cursor.execute(ddl)
		CONN.commit()

# 捕获15信号量, 做conn和fd的关闭
def signal_15_handler(sig,frame):
	print("将自动退出")
	CONN.commit()
	CONN.close()
	SQL_FD.flush()
	SQL_FD.close()
	print("已保存退出")
	sys.exit(1)

signal.signal(signal.SIGTERM, signal_15_handler) # kill -15
signal.signal(signal.SIGINT, signal_15_handler)  # ctrl+c


def runsql(sql):
	try:
		cursor = CONN.cursor()
		cursor.execute(sql)
		data = cursor.fetchall()
		status = True
		sql += f"{';' if data[-1:] != ';' else ''}" + "\n"
		if sql[:7].upper() != "SELECT ":
			SQL_FD.write(sql)
	except Exception as e:
		status = False
		data = str(e)
		sql = "-- /* MAY BE ERROR " + data + " */" + sql + f"{';' if data[-1:] != ';' else ''}" + "\n"
		SQL_FD.write(sql)
	SQL_FD.flush()
	return status,data

# 啊哈! sqlite3不支持多线程
#class ThreadingSimpleServer(ThreadingMixIn, HTTPServer):
#	pass

class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
	def do_GET(self):
		url_components = urllib.parse.urlparse(self.path)
		query = urllib.parse.parse_qs(url_components.query)
		path = url_components.path
		if path == '/work':
			#self.handle_work_request(query)
			self.handle_html_request()
		elif path == '/plan':
			#self.handle_work_plan(query)
			self.handle_html_request()
		else:
			self.handle_html_request()

	def do_POST(self):
		content_length = int(self.headers['Content-Length'])
		post_data = self.rfile.read(content_length)
		data = json.loads(post_data)
		print('PATH',self.path,"收到的数据:",data)
		if self.path == '/work':
			# 判断action
			if data['action'] == 'add': # 新增
				if data['work_dt'] == '':
					data['work_dt'] = str(datetime.datetime.now()).split('.')[0]
				sql = f"insert into work values({int(time.time()*1000)},'ddcw',\'{data['work_dt']}\',\'{data['work_status']}\', \'{data['work_si']}\', \'{data['work_detail']}\', '')"
			elif data['action'] == 'delete': # 删除
				# sql = f"delete from work where work_id={data['work_id']}"
				sql = f"update work set work_status='已删除' where work_id={data['work_id']}"
			elif data['action'] == 'update': # 更新
				sql = f"update work set work_status=\'{data['work_status']}\', work_si=\'{data['work_si']}\', work_dt='{str(datetime.datetime.now()).split('.')[0]}' where work_id = {data['work_id']}"
			elif data['action'] == 'select': # 查询的, 默认就最近50条 
				sql = 'select work_id,work_dt,work_status,work_si,work_detail from work where work_status !="已删除" order by work_dt desc limit 50'
			else:
				sql = "select '不知道你在干什么, 但我只管记录... {data}'"
			#self.wfile.write(post_data) # 慕容复
		elif self.path == '/plan':
			# 判断action
			if data['action'] == 'add':
				if data['plan_dt'] == '':
					data['plan_dt'] = str(datetime.datetime.now()).split('.')[0]
				sql = f"insert into plan values({int(time.time()*1000)}, 'ddcw', \'{data['plan_dt']}\', \'{str(datetime.datetime.now()).split('.')[0]}\', '未完成', \'{data['plan_contact']}\', \'{data['plan_si']}\', \'{data['plan_detail']}\', '' )"
			elif data['action'] == 'status':
				sql = f"update plan set plan_status=\'{data['plan_status']}\',plan_update=\'{str(datetime.datetime.now()).split('.')[0]}\' where plan_id={data['plan_id']}"
			elif data['action'] == 'select':
				sql = f"select plan_id,plan_dt,plan_contact,plan_status,plan_si,plan_detail from plan where plan_status='未完成' order by plan_dt" # 就不要limit了, 全TM查出来
			else:
				sql = "select '不知道你在干什么, 但我只管记录... {data}'"
		elif self.path == '/report':
			if data['action'] == 1: # 上周周报
				sql = f"select work_id,work_dt,work_si from work where work_dt >= date('now', 'weekday 0', '-13 days') and work_dt < date('now', 'weekday 0', '-6 day') and work_status!='已删除'"
			else : # 本周周报
				sql = f"select work_id,work_dt,work_si from work where work_dt >= date('now', 'weekday 0', '-6 days') and work_dt < date('now', 'weekday 0', '+1 day') and work_status!='已删除'"
		else:
			sql = "select '不知道你在干什么, 但我只管记录... {data}'"
		status,data = runsql(sql)
		self.send_response(200)
		self.send_header('Content-type', 'text/html')
		self.end_headers()
		rbdata = json.dumps({'data':data,'status':status}).encode('utf-8')
		print('返回数据',{'data':data,'status':status})
		self.wfile.write(rbdata)

	def handle_html_request(self):
		#pass # 就返回首页html就行. 其实就这一个page...
		self.send_response(200)
		self.send_header('Content-type', 'text/html')
		self.end_headers()
		html_content = '''
<html>
<head>
	<title>DDCW miniWorkNote</title>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
    body {
        font-family: Arial, sans-serif;
    }
    .container {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 10px;
        margin: 10px;
    }
    .note, .plan {
        border: 1px solid #ccc;
        padding: 10px;
    }
    .header {
        background-color: #f0f0f0;
        padding: 5px;
        font-weight: bold;
        text-align: center;
    }
    button {
        margin-right: 5px;
    }
    .footer {
        display: flex;
        justify-content: space-between;
        margin-top: 10px;
    }
    .note>div:last-child, .plan>div:last-child {
        border-top: 1px solid #ccc;
        margin-top: 10px;
        padding-top: 10px;
    }
    .week-report {
        border-top: 1px solid #ccc;
        padding-top: 10px;
    }
    td {
        padding: 15px;
    }
    tr {background-color:LightGray;}
    tbody tr:hover   {background-color: yellow;}
</style>
<script>
	// 周报
	function work_report(n){
		data = {'action':n}
		var xhr = new XMLHttpRequest();
		xhr.open('POST', '/report', true);
		xhr.setRequestHeader("Content-Type", "application/json");
		xhr.onreadystatechange = function () {
			if (xhr.readyState === 4 && xhr.status === 200) {
				var rdata = JSON.parse(xhr.responseText);
				vv = ""
				if (rdata.data.length == 0){alert('无周报内容, 你在摸鱼?')}
				else{
					for (var row in rdata.data){
						vv += rdata.data[row][1] + "    " + rdata.data[row][2]  + "\\n"
					}
					document.getElementById('hidden_report').style.display = 'block';
					document.getElementById('hidden_report').value = vv;
					document.getElementById('hidden_report').select();
					document.execCommand('copy');
					document.getElementById('hidden_report').style.display = 'none';
					avv = "已复制\\n" + vv
					alert(avv);
				}
			}
		}
		data1 = JSON.stringify(data);
		xhr.send(data1)
	}


	function modify_work(n){
		work_status = document.getElementById("work_status_"+n).innerHTML
		work_si = document.getElementById("work_si_"+n).innerHTML
		// select
		work_status_select = "<select id='work_status_op_"+n+"'><option value='已完成'>已完成</option><option value='未完成'>未完成</option><option value='异常'>异常</option></select>"
		document.getElementById("work_status_"+n).innerHTML = work_status_select
		// 简述
		work_si_input = "<textarea cols=30 id='work_si_op_"+n+"'>"+work_si+"</textarea>"
		document.getElementById("work_si_"+n).innerHTML = work_si_input
		// 操作: 确认:提交数据.  取消:重新刷新即可...
		work_ctl_button = "<input value='确认' type='button' onclick='modify_work_op("+n+")'><input value='取消' type='button' onclick='flush_work()'>"
		document.getElementById("work_ctl_"+n).innerHTML = work_ctl_button
	}

	// 提交确认的数据
	function modify_work_op(n){
		work_status_idx = document.getElementById('work_status_op_'+n).selectedIndex;
		data = {
			'action':'update',
			'work_id':n,
			'work_status':document.getElementById('work_status_op_'+n).options[work_status_idx].value,
			'work_si':document.getElementById("work_si_op_"+n).value
		}
		var xhr = new XMLHttpRequest();
		xhr.open('POST', '/work', true);
		xhr.setRequestHeader("Content-Type", "application/json");
		xhr.onreadystatechange = function () {
			if (xhr.readyState === 4 && xhr.status === 200) {
				var rdata = JSON.parse(xhr.responseText);
				if (rdata.status){
					flush_work()
				}
				else{
					alert(rdata.data)
				}
			}
		}
		data1 = JSON.stringify(data);
		xhr.send(data1)
	}

	function flush_work(){
		// 刷新的.
		data = {'action':'select'}
		var xhr = new XMLHttpRequest();
		xhr.open('POST', '/work', true);
		xhr.setRequestHeader("Content-Type", "application/json");
		xhr.onreadystatechange = function () {
			if (xhr.readyState === 4 && xhr.status === 200) {
				var rdata = JSON.parse(xhr.responseText);
				if (rdata.status){
					tbodyhtml = ""
					document.getElementById('work_tbody').innerHTML="看不见的";
					for (var row in rdata['data']){
						tbodyhtml += "<tr>"
						tbodyhtml += "<td>"+ rdata['data'][row][0]  +"</td>"
						tbodyhtml += "<td >"+ rdata['data'][row][1]  +"</td>"
						tbodyhtml += "<td id='work_status_"+rdata['data'][row][0]+"' "
						if (rdata['data'][row][2] == "异常"){
							tbodyhtml += " style='background-color:red'>"+ rdata['data'][row][2]  +"</td>"
						}
						else if (rdata['data'][row][2] == "未完成"){
							tbodyhtml += " style='background-color:yellow;'>"+ rdata['data'][row][2]  +"</td>"
						}
						else{
							tbodyhtml += ">"+ rdata['data'][row][2]  +"</td>"
						}
						tbodyhtml += "<td id='work_si_"+rdata['data'][row][0]+"'>"+ rdata['data'][row][3]  +"</td>"
						tbodyhtml += "<td id='work_ctl_"+rdata['data'][row][0]+"'>"
						tbodyhtml += "<input type='button' value='修改' onclick='modify_work("+rdata['data'][row][0]+")'>"
						tbodyhtml += "<input type='button' value='详情' onclick='alert(\\""+rdata['data'][row][4]+"\\")'>"
						tbodyhtml += "<input type='button' value='删除' onclick='delete_work("+rdata['data'][row][0]+")'>"
						tbodyhtml += "</td>"
						tbodyhtml += "</tr>"
					}
					document.getElementById('work_tbody').innerHTML=tbodyhtml
				}
			}
		}
		data1 = JSON.stringify(data);
		xhr.send(data1)
	}

	function delete_work(n){
		data = {"action":'delete','work_id':n}
		var xhr = new XMLHttpRequest();
		xhr.open('POST', '/work', true);
		xhr.setRequestHeader("Content-Type", "application/json");
		xhr.onreadystatechange = function () {
			if (xhr.readyState === 4 && xhr.status === 200) {
				var rdata = JSON.parse(xhr.responseText);
				if (rdata.status){
					//alert("删除成功")
					//setTimeout(function(){flush_work()},500)
					flush_work()
				}
				else {
					alert(rdata.data)
				}
			}
		}
		data1 = JSON.stringify(data);
		xhr.send(data1)
	}

	function add_work(){
		formdata = new FormData(); // dio用没得, 还不如直接json
		work_status_idx = document.getElementById('work_status').selectedIndex;
		data = {
			"action":"add",
			"work_dt":document.getElementById('work_dt').value,
			"work_status":document.getElementById('work_status').options[work_status_idx].value,
			"work_si":document.getElementById('work_si').value,
			"work_detail":document.getElementById('work_detail').value,
		};
		var xhr = new XMLHttpRequest();
		xhr.open('POST', '/work', true);
		xhr.setRequestHeader("Content-Type", "application/json");
		xhr.onreadystatechange = function () {
			if (xhr.readyState === 4 && xhr.status === 200) {
				//alert(xhr.responseText)
				var rdata = JSON.parse(xhr.responseText);
				if (rdata.status) {
					//flush_work()
					setTimeout(function(){flush_work()},100)
				}
			}
		}
		data1 = JSON.stringify(data);
		xhr.send(data1)
		// setTimeout(function(){flush_work()},500) /* send 完之后刷新 */
		
	}

	// 判断字符串是否是今天
	function is_today(dt){
		today = new Date();
		y = today.getFullYear();
		m = today.getMonth() + 1;
		d = today.getDate();
		dt2 = dt.split('-');
		return y == dt2[0] && m == dt2[1] && d == dt2[2];
	}

	// 判断字符串是否是这周
	function is_week(dt){
		today = new Date();
		dt2 = new Date(dt);
		fstweek = new Date(today.getTime() - today.getDay() * 86400000);
		lstweek = new Date(fstweek.getTime() + 6 * 86400000);
		return dt2 >= fstweek && dt2 <= lstweek;
	}


	// plan相关的了
	function flush_plan(){
		data = {'action':'select'}
		var xhr = new XMLHttpRequest();
		xhr.open('POST', '/plan', true);
		xhr.setRequestHeader("Content-Type", "application/json");
		xhr.onreadystatechange = function () {
			if (xhr.readyState === 4 && xhr.status === 200) {
				var rdata = JSON.parse(xhr.responseText);
				document.getElementById('plan_tbody').innerHTML="看不见的";
				tbodyhtml = ""
				// 如果是今天的变更, 就红色. 本周的就黄色,  其它的不管
				for (var row in rdata['data']){
					tbodyhtml += "<tr>"
					tbodyhtml += "<td>"+ rdata['data'][row][0]  +"</td>"
					tbodyhtml += "<td>"+ rdata['data'][row][1]  +"</td>"
					tbodyhtml += "<td>"+ rdata['data'][row][2]  +"</td>"
					tbodyhtml += "<td "
					if (is_today(rdata['data'][row][1])){
						tbodyhtml += "style='background-color:red'"
					}
					else if (is_week(rdata['data'][row][1])){
						tbodyhtml += "style='background-color:yellow'"
					}
					tbodyhtml += " >" + rdata['data'][row][3]  +"</td>"
					//tbodyhtml += "<td>"+ rdata['data'][row][3]  +"</td>"
					tbodyhtml += "<td>"+ rdata['data'][row][4]  +"</td>"
					tbodyhtml += "<td>"
					tbodyhtml += "<input type='button' value='详情' onclick='alert(\\""+rdata['data'][row][5]+"\\")'>"
					tbodyhtml += "<input type='button' value='设置为已完成' onclick='plan_commit("+rdata['data'][row][0]+")'>"
					tbodyhtml += "</td>"
					tbodyhtml += "</tr>"
				}
				document.getElementById('plan_tbody').innerHTML=tbodyhtml
			}
		}
		data1 = JSON.stringify(data);
		xhr.send(data1)
	}

	function add_plan(){
		data = {
			'action':'add',
			"plan_dt":document.getElementById('plan_dt').value,
			"plan_contact":document.getElementById('plan_contact').value,
			"plan_si":document.getElementById('plan_si').value,
			"plan_detail":document.getElementById('plan_detail').value,
		}
		var xhr = new XMLHttpRequest();
		xhr.open('POST', '/plan', true);
		xhr.setRequestHeader("Content-Type", "application/json");
		xhr.onreadystatechange = function () {
			if (xhr.readyState === 4 && xhr.status === 200) {
				var rdata = JSON.parse(xhr.responseText);
				if (rdata.status) {setTimeout(function(){flush_plan()},100)}
			}
		}
		data1 = JSON.stringify(data);
		xhr.send(data1)
	}

	function plan_commit(n){
		data = {'action':'status','plan_status':'已完成','plan_id':n}
		var xhr = new XMLHttpRequest();
		xhr.open('POST', '/plan', true);
		xhr.setRequestHeader("Content-Type", "application/json");
		xhr.onreadystatechange = function () {
			if (xhr.readyState === 4 && xhr.status === 200) {
				var rdata = JSON.parse(xhr.responseText);
				if (rdata.status) {setTimeout(function(){flush_plan()},100)}
			}
		}
		data1 = JSON.stringify(data);
		xhr.send(data1)
	}
</script>
</head>
<body>
    <div class="container">
        <div class="note">
            <div class="header">NOTE</div>
            <div>
	<label>任务时间:</label> <input type='datetime-local', id='work_dt'>
	<label>任务状态</label> <select id='work_status'><option value='未完成'>未完成</option><option value='已完成'>已完成</option><option value='异常'>异常</option></select>
	</div>
            <div align="left"><label>工作内容简述:</label> <textarea id='work_si' cols="50" ></textarea></div>
            <div align="left">工作内容详情: <textarea id='work_detail' rows="3" cols="50"></textarea></div>
            <div align="center">
                <input style="width: 80px; height: 40px; padding: 8px; margin: 4px;" type='button' value='添加' class='btn' onclick="add_work()">
                <input style="width: 80px; height: 40px; padding: 8px; margin: 4px;" type='button' value='刷新' class='btn' onclick="flush_work()">
            </div>
            <div class="week-report">
		<input type='button' value='本周周报' class='btn' onclick="work_report(0)">
		<input type='button' value='上周周报' class='btn' onclick="work_report(1)">
		<textarea id='hidden_report' style='display:none'></textarea> <!-- 不显示的话, 就无法复制 . 所以得打开显示,然后复制, 然后取消显示  -->
	</div>
            <table>
		<thead>
			<tr>
				<td>任务ID</td>
				<td>修改时间</td>
				<td>任务状态</td>
				<td>任务简述</td>
				<td>操作</td>
			</tr>
		</thead>
		<tbody id='work_tbody'>
		</tbody>
	</table>
        </div>

        <div class="plan">
            <div class="header">PLAN</div>
<div>
	<label>任务时间:</label> <input type='date', id='plan_dt'>
	<label>对接人:</label> <input id='plan_contact' value='不知道'>
</div>
<div align="left"><label>工作内容简述:</label> <textarea id='plan_si' cols="50" ></textarea></div>
<div align="left"><label>工作内容详情:</label> <textarea id='plan_detail' cols="50" rows="3" ></textarea></div>
<div align="center">
                <input style="width: 80px; height: 40px; padding: 8px; margin: 4px;" type='button' value='添加' class='btn' onclick="add_plan()">
                <input style="width: 80px; height: 40px; padding: 8px; margin: 4px;" type='button' value='刷新' class='btn' onclick="flush_plan()">
</div>

	<div>
		<table>
			<thead>
				<tr>
					<td>ID</td>
					<td>时间</td>
					<td>对接人</td>
					<td>状态</td>
					<td>简述</td>
					<td>操作</td>
				</tr>
			</thead>
			<tbody id='plan_tbody'>
			</tbody>
		</table>
	</div>


        </div>
    </div>
</body>
<script>
window.onload = function() {
    flush_work();
    flush_plan();
    // 设置默认时间. 前端获取时间太麻烦了(还得考虑月份+1就离了个大谱). 还是后端整吧...
    var default_dt = "''' + str(datetime.datetime.now()).split('.')[0] + '''"
    var default_d = "''' + str(datetime.datetime.now()).split()[0] + '''"
    document.getElementById('work_dt').value = default_dt;
    document.getElementById('plan_dt').value = default_d;
};
</script>
</html>
		'''
		self.wfile.write(html_content.encode('utf-8'))

	def handle_work_request(self,query):
		pass

	def handle_work_plan(self,query):
		pass

#def run(server_class=ThreadingSimpleServer, handler_class=SimpleHTTPRequestHandler):
def run(server_class=HTTPServer, handler_class=SimpleHTTPRequestHandler):
	server_address = (BIND_HOST,BIND_PORT)
	httpd = server_class(server_address, handler_class)
	print(f'http://{BIND_HOST}:{BIND_PORT}')
	httpd.serve_forever()
	

if __name__ == '__main__':
	run() # 润
