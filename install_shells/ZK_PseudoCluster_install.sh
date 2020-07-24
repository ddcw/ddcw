#!/bin/env bash
#write by ddcw at 20200722 first

#                                                                     
#             .,,       .,:;;iiiiiiiii;;:,,.     .,,                   
#           rGB##HS,.;iirrrrriiiiiiiiiirrrrri;,s&##MAS,                
#          r5s;:r3AH5iiiii;;;;;;;;;;;;;;;;iiirXHGSsiih1,               
#             .;i;;s91;;;;;;::::::::::::;;;;iS5;;;ii:                  
#           :rsriii;;r::::::::::::::::::::::;;,;;iiirsi,               
#        .,iri;;::::;;;;;;::,,,,,,,,,,,,,..,,;;;;;;;;iiri,,.           
#     ,9BM&,            .,:;;:,,,,,,,,,,,hXA8:            ..,,,.       
#    ,;&@@#r:;;;;;::::,,.   ,r,,,,,,,,,,iA@@@s,,:::;;;::,,.   .;.      
#     :ih1iii;;;;;::::;;;;;;;:,,,,,,,,,,;i55r;;;;;;;;;iiirrrr,..       
#    .ir;;iiiiiiiiii;;;;::::::,,,,,,,:::::,,:;;;iiiiiiiiiiiiri         
#    iriiiiiiiiiiiiiiii;;;::::::::::::::::;;;iiiiiiiiiiiiiiiir;        
#   ,riii;;;;;;;;;;;;;:::::::::::::::::::::::;;;;;;;;;;;;;;iiir.       
#   iri;;;::::,,,,,,,,,,:::::::::::::::::::::::::,::,,::::;;iir:       
#  .rii;;::::,,,,,,,,,,,,:::::::::::::::::,,,,,,,,,,,,,::::;;iri       
#  ,rii;;;::,,,,,,,,,,,,,:::::::::::,:::::,,,,,,,,,,,,,:::;;;iir.      
#  ,rii;;i::,,,,,,,,,,,,,:::::::::::::::::,,,,,,,,,,,,,,::i;;iir.      
#  ,rii;;r::,,,,,,,,,,,,,:,:::::,:,:::::::,,,,,,,,,,,,,::;r;;iir.      
#  .rii;;rr,:,,,,,,,,,,,,,,:::::::::::::::,,,,,,,,,,,,,:,si;;iri       
#   ;rii;:1i,,,,,,,,,,,,,,,,,,:::::::::,,,,,,,,,,,,,,,:,ss:;iir:       
#   .rii;;;5r,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,sh:;;iri        
#    ;rii;:;51,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.:hh:;;iir,        
#     irii;::hSr,.,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.,sSs:;;iir:         
#      irii;;:iSSs:.,,,,,,,,,,,,,,,,,,,,,,,,,,,..:135;:;;iir:          
#       ;rii;;:,r535r:...,,,,,,,,,,,,,,,,,,..,;sS35i,;;iirr:           
#        :rrii;;:,;1S3Shs;:,............,:is533Ss:,;;;iiri,            
#         .;rrii;;;:,;rhS393S55hh11hh5S3393Shr:,:;;;iirr:              
#           .;rriii;;;::,:;is1h555555h1si;:,::;;;iirri:.               
#             .:irrrii;;;;;:::,,,,,,,,:::;;;;iiirrr;,                  
#                .:irrrriiiiii;;;;;;;;iiiiiirrrr;,.                    
#                   .,:;iirrrrrrrrrrrrrrrrri;:.                        
#                         ..,:::;;;;:::,,.                             
#                                                                       
function exits(){
  echo -e "[`date +%Y%m%d-%H:%M:%S`] \033[31;40m$1\033[0m"
  [ -z $2 ] && exit $2
  exit 1
}

function when_ddcw_pre() {
	source /etc/ddcw/conf/ddcw.conf
}

#define variable 
function init_variable() {
	[[ -z ${SYSTEM_ENABLED} ]] && SYSTEM_ENABLED=""
	[[ -z ${ONBOOT} ]] && ONBOOT=""
	[[ -z ${SCRIPT_DIR_CONFIG} ]] && SCRIPT_DIR_CONFIG="/etc/ddcw/script_dir_config"
	[[ -z ${BASE_INSTALL_DIR} ]] && export BASE_INSTALL_DIR="/u01"
	mkdir -p ${SCRIPT_DIR_CONFIG} ${BASE_INSTALL_DIR}
	export nodes=3 #for cluster number
}

dtbegin=`date +%s`
thiscript=$0


function echo_color() {
  case $1 in
    green)
      echo -e "\033[32;40m$2\033[0m"
      ;;
    red)
      echo -e "\033[31;40m$2\033[0m"
      ;;
    error|erro|ERROR|E|e)
      echo -e "[\033[1;5;41;33mERROR\033[0m `date +%Y%m%d-%H:%M:%S`] \033[1;41;33m$2\033[0m"
      ;;
    redflicker)
      echo -e "\033[1;5;41;33m$2\033[0m"
      ;;
    info|INFO|IF|I|i)
      echo -e "[\033[32;40mINFO\033[0m `date +%Y%m%d-%H:%M:%S`] \033[32;40m$2\033[0m"
      ;;
    highlightbold)
      echo -e "\033[1;41;33m$2\033[0m"
      ;;
    warn|w|W|WARN|warning)
      echo -e "[\033[31;40mWARNNING\033[0m `date +%Y%m%d-%H:%M:%S`] \033[31;40m$2\033[0m"
      ;;
    *)
      echo "Example: echo_color red string"
      ;;
  esac
}

function init_pre() {
	systemctl stop firewalld >/dev/null 2>&1
	systemctl disable firewalld >/dev/null 2>&1
	chkconfig firewalld off >/dev/null 2>&1
	service firewalld stop >/dev/null 2>&1
	[ "`grep -E "^SELINUX=" /etc/selinux/config | awk -F "=" '{print $2}'`" == "disabled" ] ||  sed -i '/^SELINUX=/cSELINUX=disabled' /etc/selinux/config
	#grep -E "^SELINUX=" /etc/selinux/config

}

function init_first() {
	#export zkpack=`find ./ -name *zookeeper-3.* | head -1`
	export zkpack=`ls ./ |grep -E *zookeeper-3.*tar | head -1`
	[[ -z ${zkpack} ]] && exits "you should move zookeeper*.tar . only one"
	export zkname=`echo ${zkpack} | sed 's/.tar//' | sed 's/.gz//' | awk -F / '{print $NF}' `
	java -version >/dev/null 2>&1 || yum install java-1.8.0-openjdk -y >/dev/null 2>&1 || exits "this os is not have:openjdk-1.8.0"
	[ -d ${BASE_INSTALL_DIR} ] || mkdir -p ${BASE_INSTALL_DIR}
}

function install() {
	tar -zxvf ${zkpack} -C 	${BASE_INSTALL_DIR} 1>/dev/null
	mv ${BASE_INSTALL_DIR}/${zkname} ${BASE_INSTALL_DIR}/zookeeper
	
	#cluster info
	cluster_info=""
	for i in ${cluster_nodes}
	do
		cluster_info="${cluster_info}
server.${i}=127.0.0.1:288${i}:388${i}"
	done

	for i in ${cluster_nodes}
	do
		cat <<EOF > ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_${i}.cfg
tickTime=2000
initLimit=10
syncLimit=5
dataDir=${BASE_INSTALL_DIR}/zookeeper/data${i}
dataLogDir=${BASE_INSTALL_DIR}/zookeeper/log${i}
clientPort=218${i}
autopurge.snapRetainCount=3
autopurge.purgeInterval=1
${cluster_info}
EOF
		[[ -d ${BASE_INSTALL_DIR}/zookeeper/data${i} ]] || mkdir -p ${BASE_INSTALL_DIR}/zookeeper/data${i}
		[[ -d ${BASE_INSTALL_DIR}/zookeeper/log${i} ]] || mkdir -p ${BASE_INSTALL_DIR}/zookeeper/log${i}
		echo $i > ${BASE_INSTALL_DIR}/zookeeper/data${i}/myid
	done
	log4j="${BASE_INSTALL_DIR}/zookeeper/conf/log4j.properties"
	cp ${log4j} ${BASE_INSTALL_DIR}/zookeeper/conf/log4j.properties.bak
	sed -i '/zookeeper.root.logger=/czookeeper.root.logger=ERROR, CONSOLE' ${log4j}
	sed -i '/zookeeper.console.threshold=/czookeeper.console.threshold= ERROR' ${log4j}
	sed -i '/zookeeper.log.threshold=/czookeeper.log.threshold= ERROR' ${log4j}
}

function install_post() {
	#zkPseudo for control zookeeper psedudo cluster
	#zkPseudo start | stop | restart | status [NUMBER]
	[[ -f /usr/bin/zkPseudo ]] && mv /usr/bin/zkPseudo /usr/bin/zkPseudo.bak$(date +%Y%m%d-%H:%M:%S)
	cat << EOF > /usr/bin/zkPseudo
#!/bin/env bash
case \$1 in 
	start|START|Start|star)
		[[ -f ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_\$2.cfg ]] && ${BASE_INSTALL_DIR}/zookeeper/bin/zkServer.sh start ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_\${2}.cfg && exit 0
		for i in ${cluster_nodes}
		do
			${BASE_INSTALL_DIR}/zookeeper/bin/zkServer.sh start ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_\${i}.cfg
		done
			;;
        restart|RESTART|Restart|res)
		[[ -f ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_\$2.cfg ]] && ${BASE_INSTALL_DIR}/zookeeper/bin/zkServer.sh restart ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_\${2}.cfg && exit 0
                for i in ${cluster_nodes}
                do
                        ${BASE_INSTALL_DIR}/zookeeper/bin/zkServer.sh start ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_\${i}.cfg
                done
                        ;;
	stop|STOP|Stop|sto)
		[[ -f ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_\$2.cfg ]] && ${BASE_INSTALL_DIR}/zookeeper/bin/zkServer.sh stop ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_\${2}.cfg && exit 0
		for i in ${cluster_nodes}
                do
                        ${BASE_INSTALL_DIR}/zookeeper/bin/zkServer.sh stop ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_\${i}.cfg
                done
                        ;;
	status|STATUS|Status|stat)
		[[ -f ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_\$2.cfg ]] && ${BASE_INSTALL_DIR}/zookeeper/bin/zkServer.sh status ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_\${2}.cfg && exit 0
                for i in ${cluster_nodes}
                do
                        ${BASE_INSTALL_DIR}/zookeeper/bin/zkServer.sh status ${BASE_INSTALL_DIR}/zookeeper/conf/zoo_\${i}.cfg
			echo ""
                done
                        ;;
	*)
		echo "zkPseudo status|start|stop|restart"
		;;
esac


EOF
	chmod +x /usr/bin/zkPseudo


	#system service
	[[ ${SYSTEM_ENABLED} -eq 1 ]] && cat << EOF > /usr/lib/systemd/system/zkPseudo.service
[Unit]
Description=zk Pseudo cluster
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/zkPseudo start
ExecStop=/usr/bin/zkPseudo stop
ExecStatus=/usr/bin/zkPseudo status
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
}

	
[[ -f /etc/ddcw/conf/ddcw.conf ]] && when_ddcw_pre
init_variable

[[ -f ${SCRIPT_DIR_CONFIG}/zookeeper/.install.log ]] && exits  "this script maybe installed, you should remove it first "
cluster_nodes=$(eval echo {1..$[ ${nodes} ]})


init_pre
init_first
install
install_post

#[[ -f /etc/ddcw/conf/ddcw.conf ]] && when_ddcw_post

echo_color info "zkPseudo start|stop|status [NODE_NUMBER]"
[[ ${SYSTEM_ENABLED} -eq 1 ]] && echo_color info "systemctl start|stop|restart|status|enabled zkPseudo"

[[ ${ONBOOT} -eq 1 ]] && systemctl daemon-reload && systemctl enable zkPseudo

[[ -z ${SCRIPT_DIR_CONFIG} ]] ||  mkdir -p ${SCRIPT_DIR_CONFIG}/zookeeper
echo $(date +%Y%m%d-%H:%M:%S) >> ${SCRIPT_DIR_CONFIG}/zookeeper/.install.log

dtend=`date +%s`
echo -e "this script cost time: \033[32;40m`expr ${dtend} - ${dtbegin}`\033[0m second"

