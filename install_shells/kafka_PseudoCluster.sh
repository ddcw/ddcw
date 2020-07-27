#!/bin/env bash
#write by ddcw at 20200724 first
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
        [[ -z ${ROLLBACK_DIR} ]] && export ROLLBACK_DIR=/tmp
        mkdir -p ${SCRIPT_DIR_CONFIG} ${BASE_INSTALL_DIR} ${ROLLBACK_DIR}
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
	export kafkapack=`ls ./ | grep  kafka_ | grep tgz  | head -1`
	[[ -z ${kafkapack} ]] && exits "you should move zookeeper*.tar . only one"
	export kafkaname=$(echo ${kafkapack} | awk -F .tgz '{print $1}')
	[ -d ${BASE_INSTALL_DIR} ] || mkdir -p ${BASE_INSTALL_DIR}
	[[ -d ${BASE_INSTALL_DIR}/kafka ]] && exits "exits ${BASE_INSTALL_DIR}/kafka"
}

function install() {
	tar -xvf ${kafkapack} -C  ${BASE_INSTALL_DIR} 1>/dev/null || exits "tar -xvf failed, maybe  not tar"
	mv ${BASE_INSTALL_DIR}/${kafkaname} ${BASE_INSTALL_DIR}/kafka
	cluster_info="zookeeper.connect="
	for i in ${cluster_nodes}
        do
		cluster_info="${cluster_info}127.0.0.1:$[ 2181 + ${i} ],"
	done
	cluster_info=${cluster_info::-1}
	
	for i in ${cluster_nodes}
        do
		cp ${BASE_INSTALL_DIR}/kafka/config/server.properties ${BASE_INSTALL_DIR}/kafka/config/server-${i}.properties	
		sed -i "/zookeeper.connect=/c${cluster_info}" ${BASE_INSTALL_DIR}/kafka/config/server-${i}.properties
		sed -i "/broker.id=/cbroker.id=${i}" ${BASE_INSTALL_DIR}/kafka/config/server-${i}.properties
		sed -i "/listeners=/clisteners=PLAINTEXT:\/\/127.0.0.1:$[ 9092 + ${i} ]" ${BASE_INSTALL_DIR}/kafka/config/server-${i}.properties
		sed -i "/log.dirs=/clog.dirs=${BASE_INSTALL_DIR}\/kafka\/kafka-log-${i}" ${BASE_INSTALL_DIR}/kafka/config/server-${i}.properties

	done
}

function install_post() {
	[[ -f /usr/bin/kafkaPseudo ]] && mv /usr/bin/kafkaPseudo ${ROLLBACK_DIR}/kafkaPseudo.bak$(date +%Y%m%d-%H:%M:%S)
	        cat << EOF > /usr/bin/kafkaPseudo
#!/bin/env bash
case \$1 in
	start|START|Start|star)
		[[ -f ${BASE_INSTALL_DIR}/kafka/config/server-\${2}.properties ]] && ${BASE_INSTALL_DIR}/kafka/bin/kafka-server-start.sh -daemon ${BASE_INSTALL_DIR}/kafka/config/server-\${2}.properties && exit 0
		for i in ${cluster_nodes}
		do
			${BASE_INSTALL_DIR}/kafka/bin/kafka-server-start.sh -daemon ${BASE_INSTALL_DIR}/kafka/config/server-\${i}.properties
		done
		;;
        restart|RESTART|Restart|res)
                if [[ -f ${BASE_INSTALL_DIR}/kafka/config/server-\${2}.properties ]] 
		then
			${BASE_INSTALL_DIR}/kafka/bin/kafka-server-stop.sh -daemon ${BASE_INSTALL_DIR}/kafka/config/server-\${2}.properties
			 ${BASE_INSTALL_DIR}/kafka/bin/kafka-server-start.sh -daemon ${BASE_INSTALL_DIR}/kafka/config/server-\${2}.properties && exit 0
		fi
                for i in ${cluster_nodes}
                do
			${BASE_INSTALL_DIR}/kafka/bin/kafka-server-stop.sh -daemon ${BASE_INSTALL_DIR}/kafka/config/server-\${i}.properties
			 ${BASE_INSTALL_DIR}/kafka/bin/kafka-server-start.sh -daemon ${BASE_INSTALL_DIR}/kafka/config/server-\${i}.properties && exit 0
                done
                ;;
        stop|STOP|Stop|sto)
                [[ -f ${BASE_INSTALL_DIR}/kafka/config/server-\${2}.properties ]] && ${BASE_INSTALL_DIR}/kafka/bin/kafka-server-stop.sh -daemon ${BASE_INSTALL_DIR}/kafka/config/server-\${2}.properties && exit 0
                for i in ${cluster_nodes}
                do
                        ${BASE_INSTALL_DIR}/kafka/bin/kafka-server-stop.sh -daemon ${BASE_INSTALL_DIR}/kafka/config/server-\${i}.properties
                done
                ;;
        status|STATUS|Status|stat)
                [[ -f ${BASE_INSTALL_DIR}/kafka/config/server-\${2}.properties ]] && ${BASE_INSTALL_DIR}/kafka/bin/kafka-topics.sh   --describe --zookeeper 127.0.0.1:\$[ 2181 + \$i ] && exit 0
                for i in ${cluster_nodes}
                do
                        ${BASE_INSTALL_DIR}/kafka/bin/kafka-topics.sh   --describe --zookeeper 127.0.0.1:\$[ 2181 + \$i ]
                done
                ;;
	*)
		echo "kafkaPseudo start|stop|status|restart [NUMBER]"
		;;
esac

EOF
	chmod +x /usr/bin/kafkaPseudo
	        #system service
        [[ ${SYSTEM_ENABLED} -eq 1 ]] && cat << EOF > /usr/lib/systemd/system/kafkaPseudo.service
[Unit]
Description=kafka Pseudo cluster
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/kafkaPseudo start
ExecStop=/usr/bin/kafkaPseudo stop
ExecStatus=/usr/bin/kafkaPseudo status
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
}

[[ -f /etc/ddcw/conf/ddcw.conf ]] && when_ddcw_pre
init_variable

[[ -f ${SCRIPT_DIR_CONFIG}/kafka/.install.log ]] && exits  "this script maybe installed, you should remove it first "
cluster_nodes=$(eval echo {0..$[ ${nodes} -1 ]})

init_pre
init_first
install
install_post

#[[ -f /etc/ddcw/conf/ddcw.conf ]] && when_ddcw_post

echo_color info "kafkaPseudo start|stop|status [NODE_NUMBER]"
[[ ${SYSTEM_ENABLED} -eq 1 ]] && echo_color info "systemctl start|stop|restart|status|enabled kafkaPseudo"

[[ ${ONBOOT} -eq 1 ]] && systemctl daemon-reload && systemctl enable kafkaPseudo

[[ -z ${SCRIPT_DIR_CONFIG} ]] ||  mkdir -p ${SCRIPT_DIR_CONFIG}/kafka
echo "#$(date +%Y%m%d-%H:%M:%S)" >> ${SCRIPT_DIR_CONFIG}/kafka/.install.log
echo "${BASE_INSTALL_DIR}/kafka" >> ${SCRIPT_DIR_CONFIG}/kafka/.install.log

dtend=`date +%s`
echo -e "this script cost time: \033[32;40m`expr ${dtend} - ${dtbegin}`\033[0m second"

