#!/bin/env bash
#write by ddcw at 20200717 first
#offical url https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/index.html
#this script only install oracle after complete Check_ENV_ORACLE. So you should check ENV first ,of course you can run install_shells/CheckOracleENV20200328_19C.sh to set ENV
#scriptName: oracle19c_install.sh

#change log
#2020728 add main,zhu yao gong neng dou shi jin tian xie da. sai guo li hai tie ya zi da.
#20200729 add install_soft netca dbca and other.
#20200730 script instead of DBCA by ddcw.
#20200731 by ddcw.  add auto rpm install expect, tips when faild.
#20200804 by ddcw. add Auto clear log. archive log , alert log , listener log , audit log
#20200805 by ddcw. add auto start on boot and fixd some bugs(set_clear script failed)

#this script support LANG=en_US.UTF-8 only.
export LANG=en_US.UTF-8

#define variable
begintime=`date +%s`
dt=$(date +%Y%m%d-%H%M%S)
PARAMS=$@
current_pwd=`pwd`
thisript=$0



#run this function and exit with $2
function exits(){
  echo -e "[`date +%Y%m%d-%H:%M:%S`] \033[31;40m$1\033[0m"
  [ -z $2 ] && exit $2
  exit 1
}

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
      echo "INTERNAL ERROR: echo_color KEY VALUE"
      ;;
  esac
}

function su_command(){
	rpm -q expect >/dev/null 2>&1 || exits "this OS has not expect, so rootpassword is invalid"
        user=root
        commd=$1
        password=${rootpassword}
        expect << EOF
        set timeout 30
        spawn su ${user} -c "${commd}"
        expect {
                        "(yes/no" {send "yes\r";exp_continue}
                        "assword:" {send "${password}\r"}
        }
        expect "${user}@*" {send "exit\r"}
        expect eof
EOF
}

#bak file function, bak_file FILENAME but abandonmented
function bak_file() {
  [ -d ~/bak_file ] || mkdir ~/bak_file
  filename=`echo $1 |sed 's/\//_/g'`
  cp -f $1 ~/bak_file/${filename}_${dt}
}


#init user set params
function init_parameter() {
	export	ORACLE_BASE=${ORACLE_BASE%*/}
	export	ORACLE_HOME=${ORACLE_HOME%*/}
	export	CURRENT_USER=$(id | awk -F uid= '{print $2}' | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
	export	CURRENT_USER_GROUP=$(id | awk -F gid= '{print $2}' | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
	export  INVENTORY_LOCATION_DIR=${ORACLE_BASE%/*}/oraInventory
	export  LISTENER_NAMES="LISTENER"
	export  LISTENER_PORT=1521
	export  ORACLE_SID=$(env | grep ORACLE_SID= | awk -F 'ORACLE_SID=' '{print $2}')
	[[ -z ${ORACLE_SID} ]] && export ORACLE_SID=$(hostname)
	export  DB_UNIQUE_NAME=${ORACLE_SID}
	export  DB_NAME=${ORACLE_SID}
	export  gdbName=${DB_NAME}
	export  characterSet="AL32UTF8"
	export  open_cursors=1000
	export  processes=3000
	export  EMPORT=5500
	export  pdbName=${ORACLE_SID}pdb
	export  ORADATA=${ORACLE_BASE}/oradata
	export  sysPassword=Ddcw.1${ORACLE_SID}
	export  systemPassword=Ddcw.2${ORACLE_SID}
	export  pdbAdminPassword=Ddcw.3${ORACLE_SID}

	export ORACLE_SOFTWARE_NAME="LINUX.X64_193000_db_home.zip"
	
	[[ -z ${BASE_INSTALL_DIR} ]] && export BASE_INSTALL_DIR="/usr/local/oracle19c"
	export  ASROOT_RUN="/tmp/.asrootRunscript.sh"
	echo '' > ${ASROOT_RUN} || exits "current user cant use /tmp or full"

	#pga_size MB
	export PGA_AGGREGATE_TARGET=$(cat /proc/meminfo | grep MemTotal | awk '{print $2/1024/5*2/4}' | awk -F . '{print $1}')
	#sga_size MB
	export SGA_TARGET=$(cat /proc/meminfo | grep MemTotal | awk '{print $2/1024/5*2/4*3}' | awk -F . '{print $1}')

	#mi ma shu ru zui da ci shu
	export mimacishu_max=3
}

#check env for install oracle, such as space,kernel params,software....
function check_env() {
	#check ENV variable
	ENV_variable="ORACLE_HOME ORACLE_BASE ORACLE_HOSTNAME ORACLE_SID"
	echo_color info "check ENV ${ENV_variable}"
	for i in ${ENV_variable}
	do
		env | grep ${i}= >/dev/null 2>&1 || exits "current ENV has not ${i} , you should set it and run again."
	done
	
	#get oracle19c software , or exit
	echo_color info "find software"
	[[ -z ${ORACLE_SOFTWARE} ]] && export ORACLE_SOFTWARE=$(find / -name ${ORACLE_SOFTWARE_NAME} 2>/dev/null | head -1)
	[[ -z ${ORACLE_SOFTWARE} ]] && exits "no software ${ORACLE_SOFTWARE_NAME}"
	echo_color info "ORACLE_SOFTWARE  ${ORACLE_SOFTWARE}"

	#check SPACE 
	echo_color info  "check SPACE about  ${ORACLE_HOME} ${ORACLE_BASE} /tmp"
	[[ $(du -s ${ORACLE_HOME} | awk '{print $1}') -gt 10000 ]] && exits "maybe oracle has install, ${ORACLE_HOME} is not null "
	[[ $(df -P ${ORACLE_HOME} | tail -1 | awk '{print $(NF-2)}') -lt 8000000 ]] && exits "${ORACLE_HOME} size too little, must > 8GB"
	[[ $(df -P ${ORACLE_BASE} | tail -1 | awk '{print $(NF-2)}') -lt 13000000 ]] && exits "${ORACLE_HOME} size too little, must > 13GB"
	[[ $(df -P /tmp | tail -1 | awk '{print $(NF-2)}') -gt 1500000 ]] || exits '/tmp must greate 1.5G'


	#sga size
	[ "${SGA_TARGET}" -lt "800" ] && exits "sga_target ${SGA_TARGET} is too small, needs to be at least 784M"

	#check directories
	[[ $(wc -l ${ASROOT_RUN} | awk '{print $1}') -gt 1 ]] && exits "you should mkdir some of directories and to grant authorization . just like ${ASROOT_RUN}"

	#check number: porcess,cursor,sga,pga,listener,emport....
	need_number="open_cursors processes EMPORT LISTENER_PORT"
	echo_color info "check ${need_number} IS NUMBER"
	for i in ${need_number}
	do
		#eval hui xian ba bian liang huan chen zhi , zai zhi xing ming ling. ya lei ta lei da zi.
		[ "$(eval echo \$$i)" -eq "$(eval echo \$$i)" ] 2>/dev/null || exits "$i must number"
	done
	
	#chekc params NOT NULL:DB_NAME gdbName ORACLE_SID ORACLE_HOME ORACLE_BASE INVENTORY_LOCATION_DIR ORADATA characterSet open_cursors processes PGA_AGGREGATE_TARGET SGA_TARGET LISTENER_PORT sysPassword systemPassword pdbAdminPassword
	need_NOT_NULL="DB_NAME gdbName ORACLE_SID ORACLE_HOME ORACLE_BASE INVENTORY_LOCATION_DIR ORADATA characterSet open_cursors processes PGA_AGGREGATE_TARGET SGA_TARGET LISTENER_PORT sysPassword systemPassword pdbAdminPassword"
	echo_color info "check ${need_NOT_NULL} is valid"
	for i in ${need_NOT_NULL}
	do
		[[ "$(eval echo \$$i)" == "$(eval echo \$$i)" ]] 2>/dev/null || exits "$i must NOT NULL"
	done
	echo_color info "CHECK FINISH"
}

function mkdir_authorization() {
	#make need directories, if rootPassword=XXXX, su_command mkdir and  chown
	need_dir="${ORACLE_HOME} ${ORACLE_BASE} ${BASE_INSTALL_DIR} ${INVENTORY_LOCATION_DIR}"
	echo_color info "make directories : ${need_dir}"
	if [[ -z ${rootpassword} ]]
	then
		for i in ${need_dir}
		do
			mkdir -p $i || echo "mkdir -p $i" >> ${ASROOT_RUN}
			touch ${i}/.flag_judge_Authority && rm -rf ${i}/.flag_judge_Authority || echo "chown -R ${CURRENT_USER}:${CURRENT_USER_GROUP} $i" >> ${ASROOT_RUN}
		done
	else
		for i in ${need_dir}
		do
			su_command "mkdir -p ${i}"
			su_command "chown -R ${CURRENT_USER}:${CURRENT_USER_GROUP} $i"
		done
	fi
}

function unzip_to_ORACLE_HOME() {
	echo_color info "unzip ${ORACLE_SOFTWARE} -d ${ORACLE_HOME}"
	unzip -q ${ORACLE_SOFTWARE} -d ${ORACLE_HOME}
}

function check_PACK() {
	#compat-libstdc++-33 maybe no use
	#nfs-utils only for Oracle ACFS
	#net-tools for RAC and Clusterware
	noinstall_pack=""
	need_packs="unzip bc binutils compat-libcap1 compat-libstdc++-33 glibc glibc-devel ksh libaio libaio-devel libX11 libXau libXi libXtst libXrender libXrender-devel libgcc libstdc++ libxcb make smartmontools sysstat"
	echo_color info "check pack : ${need_packs}"
	for i in ${need_packs}
	do
		rpm --query --queryformat "%{NAME}" $i >/dev/null 2>&1 || noinstall_pack="${noinstall_pack} $i"
	done
	if [[ -z ${noinstall_pack} ]] 
	then
		echo_color info "check software successful, will continue...."
		return 0
	else
		echo_color warn "${noinstall_pack} is not install , you should install then and run again , or use IGNORE_PACK=1 to force run script"
		[[  ! -z ${rootpassword} ]] &&  su_command "yum -y install ${noinstall_pack}" 
		for i in ${need_packs}
		do
		        rpm --query --queryformat "%{NAME}" $i >/dev/null 2>&1 ||  exits "you should config yum and install ${noinstall_pack}, or use IGNORE_PACK=1 to force run script"
		done
	fi
}

#config dbinstall.rsp
function init_db_install_rsp() {
	echo_color info "${BASE_INSTALL_DIR}/db_install.rsp"
	cat << EOF > ${BASE_INSTALL_DIR}/db_install.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=${CURRENT_USER_GROUP}
INVENTORY_LOCATION=${INVENTORY_LOCATION_DIR}
ORACLE_BASE=${ORACLE_BASE}
ORACLE_HOME=${ORACLE_HOME}
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.config.starterdb.type=GENERAL_PURPOSE
oracle.install.db.ConfigureAsContainerDB=false
oracle.install.db.config.starterdb.memoryOption=false
oracle.install.db.config.starterdb.installExampleSchemas=false
oracle.install.db.config.starterdb.managementOption=DEFAULT
oracle.install.db.config.starterdb.omsPort=0
oracle.install.db.config.starterdb.enableRecovery=false
EOF
}

#config netca.rsp
function init_netca_rsp() {
	echo_color info "init ${BASE_INSTALL_DIR}/netca.rsp"
	cat << EOF > ${BASE_INSTALL_DIR}/netca.rsp
[GENERAL]
RESPONSEFILE_VERSION="19.0"
CREATE_TYPE="CUSTOM"
[oracle.net.ca]
INSTALLED_COMPONENTS={"server","net8","javavm"}
INSTALL_TYPE=""typical""
LISTENER_NUMBER=1
LISTENER_NAMES={"${LISTENER_NAMES}"}
LISTENER_PROTOCOLS={"TCP;${LISTENER_PORT}"}
LISTENER_START=""LISTENER""
NAMING_METHODS={"TNSNAMES","ONAMES","HOSTNAME"}
NSN_NUMBER=1
NSN_NAMES={"EXTPROC_CONNECTION_DATA"}
NSN_SERVICE={"PLSExtProc"}
NSN_PROTOCOLS={"TCP;HOSTNAME;${LISTENER_PORT}"}

EOF
}

#config dbca.rsp
function init_dbca_rsp() {
	#when NOPDB=1 dbca will use dbca_NOPDB.rsp, other sids use dbca.rsp.
	#for study will has two dbca reponse file.
	echo_color info "init ${BASE_INSTALL_DIR}/dbca_NOPDB.rsp"
	cat << EOF > ${BASE_INSTALL_DIR}/dbca_NOPDB.rsp
responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v19.0.0
gdbName=${gdbName}
sid=${ORACLE_SID}
databaseConfigType=SI
policyManaged=false
createServerPool=false
force=false
createAsContainerDatabase=false
numberOfPDBs=0
useLocalUndoForPDBs=true
templateName=${ORACLE_HOME}/assistants/dbca/templates/New_Database.dbt
systemPassword=${systemPassword} 
sysPassword=${sysPassword}
pdbAdminPassword=${pdbAdminPassword}
emConfiguration=DBEXPRESS
emExpressPort=${EMPORT}
runCVUChecks=FALSE
omsPort=0
dvConfiguration=false
olsConfiguration=false
datafileDestination=${ORADATA}/{DB_UNIQUE_NAME}/
storageType=FS
characterSet=${characterSet}
nationalCharacterSet=AL16UTF16
registerWithDirService=false
listeners=${LISTENER_NAMES}
variables=ORACLE_BASE_HOME=${ORACLE_HOME},DB_UNIQUE_NAME=${DB_UNIQUE_NAME},ORACLE_BASE=${ORACLE_BASE},PDB_NAME=,DB_NAME=${DB_NAME},ORACLE_HOME=${ORACLE_HOME},SID=${ORACLE_SID}
initParams=undo_tablespace=UNDOTBS1,sga_target=${SGA_TARGET}MB,db_block_size=8192BYTES,nls_language=AMERICAN,dispatchers=(PROTOCOL=TCP) (SERVICE=${ORACLE_SID}XDB),diagnostic_dest={ORACLE_BASE},control_files=("${ORADATA}/{DB_UNIQUE_NAME}/control01.ctl", "${ORADATA}/{DB_UNIQUE_NAME}/control02.ctl"),remote_login_passwordfile=EXCLUSIVE,audit_file_dest={ORACLE_BASE}/admin/{DB_UNIQUE_NAME}/adump,processes=${processes},pga_aggregate_target=${PGA_AGGREGATE_TARGET}MB,nls_territory=AMERICA,local_listener=LISTENER_${ORACLE_SID},open_cursors=${open_cursors},compatible=19.0.0,db_name=${DB_NAME},audit_trail=none
sampleSchema=false
memoryPercentage=40
databaseType=MULTIPURPOSE
automaticMemoryManagement=false
totalMemory=0
EOF
	#with PDBS , pdbName= createAsContainerDatabase=true  initParams=enable_pluggable_database=true 
	echo_color info "init ${BASE_INSTALL_DIR}/dbca.rsp"
	cat << EOF > ${BASE_INSTALL_DIR}/dbca.rsp
responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v12.2.0
gdbName=${gdbName}
sid=${ORACLE_SID}
databaseConfigType=SI
policyManaged=false
createServerPool=false
force=false
createAsContainerDatabase=true
numberOfPDBs=1
pdbName=${pdbName}
useLocalUndoForPDBs=true
templateName=${ORACLE_HOME}/assistants/dbca/templates/New_Database.dbt
systemPassword=${systemPassword} 
sysPassword=${sysPassword}
pdbAdminPassword=${pdbAdminPassword}
emConfiguration=DBEXPRESS
emExpressPort=${EMPORT}
runCVUChecks=FALSE
omsPort=0
dvConfiguration=false
olsConfiguration=false
datafileDestination=${ORADATA}/{DB_UNIQUE_NAME}/
storageType=FS
characterSet=${characterSet}
nationalCharacterSet=AL16UTF16
registerWithDirService=false
listeners=${LISTENER_NAMES}
variables=ORACLE_BASE_HOME=${ORACLE_HOME},DB_UNIQUE_NAME=${DB_UNIQUE_NAME},ORACLE_BASE=${ORACLE_BASE},PDB_NAME=${pdbName},DB_NAME=${DB_NAME},ORACLE_HOME=${ORACLE_HOME},SID=${ORACLE_SID}
initParams=undo_tablespace=UNDOTBS1,enable_pluggable_database=true,sga_target=${SGA_TARGET}MB,db_block_size=8192BYTES,nls_language=AMERICAN,dispatchers=(PROTOCOL=TCP) (SERVICE=${ORACLE_SID}XDB),diagnostic_dest={ORACLE_BASE},control_files=("${ORADATA}/{DB_UNIQUE_NAME}/control01.ctl", "${ORADATA}/{DB_UNIQUE_NAME}/control02.ctl"),remote_login_passwordfile=EXCLUSIVE,audit_file_dest={ORACLE_BASE}/admin/{DB_UNIQUE_NAME}/adump,processes=${processes},pga_aggregate_target=${PGA_AGGREGATE_TARGET}MB,nls_territory=AMERICA,local_listener=LISTENER_${ORACLE_SID},open_cursors=${open_cursors},compatible=19.0.0,db_name=${DB_NAME},audit_trail=none
sampleSchema=false
memoryPercentage=40
databaseType=MULTIPURPOSE
automaticMemoryManagement=false
totalMemory=0
EOF
}

#install oracle software only
function install_db_software() {
	echo_color info "install db software...."
	begintime_dbinstall=$(date +%s)
	#this is 12.2 version,now 19c has BUG
	#ps -ef | grep "${BASE_INSTALL_DIR}/db_install.log" | grep -v grep | awk '{print $2}' | xargs -t -i kill -9 {} >/dev/null 2>&1
	#echo '' > ${BASE_INSTALL_DIR}/db_install.log
	#tail -f ${BASE_INSTALL_DIR}/db_install.log &
	#$ORACLE_HOME/runInstaller  -ignorePrereq  -silent -noconfig -force -responseFile  ${BASE_INSTALL_DIR}/db_install.rsp >${BASE_INSTALL_DIR}/db_install.log
	#while true
	#do
	#	if grep "Successfully Setup Software" ${BASE_INSTALL_DIR}/db_install.log >/dev/null 2>&1
	#	then
	#		echo_color info "oracle software install finish."
	#		echo '' > ${ASROOT_RUN}
	#		echo "cp ${ORACLE_BASE}/oraInventory/orainstRoot.sh ${ORACLE_BASE}/oraInventory/orainstRoot.sh.bak${dt}" >> ${ASROOT_RUN}
	#		echo "sh ${ORACLE_BASE}/oraInventory/orainstRoot.sh" >> ${ASROOT_RUN}
	#		echo "cp ${ORACLE_HOME}/root.sh ${ORACLE_HOME}/root.sh.bak${dt}" >> ${ASROOT_RUN}
	#		echo "sh ${ORACLE_HOME}/root.sh" >> ${ASROOT_RUN}
	#		if [[ -z ${rootpassword} ]]
	#		then
	#			echo_color warn "you should run script as root\n${ORACLE_BASE}/oraInventory/orainstRoot.sh\n${ORACLE_HOME}/root.sh. you can run like ${ASROOT_RUN}"
	#		else
	#			su_command "sh ${ASROOT_RUN}"
	#		fi
	#		break
	#	else
	#		sleep 10
	#	fi
	#done
	#ps -ef | grep "${BASE_INSTALL_DIR}/db_install.log" | grep -v grep | awk '{print $2}' | xargs -t -i kill -9 {} >/dev/null 2>&1

	#19c install software.
	$ORACLE_HOME/runInstaller  -ignorePrereq  -silent -noconfig -force -responseFile  ${BASE_INSTALL_DIR}/db_install.rsp
        echo_color info "oracle software install finish."
        echo '' > ${ASROOT_RUN}
        echo "cp ${INVENTORY_LOCATION_DIR}/orainstRoot.sh ${INVENTORY_LOCATION_DIR}/orainstRoot.sh.bak${dt}" >> ${ASROOT_RUN}
        echo "sh ${INVENTORY_LOCATION_DIR}/orainstRoot.sh" >> ${ASROOT_RUN}
        echo "cp ${ORACLE_HOME}/root.sh ${ORACLE_HOME}/root.sh.bak${dt}" >> ${ASROOT_RUN}
        echo "sh ${ORACLE_HOME}/root.sh" >> ${ASROOT_RUN}
        if [[ -z ${rootpassword} ]]
        then
                echo_color warn "you should run script as root\n${ORACLE_BASE}/oraInventory/orainstRoot.sh\n${ORACLE_HOME}/root.sh. you can run like ${ASROOT_RUN}"
        else
                su_command "sh ${ASROOT_RUN}"
		echo_color info "run orainstRoot.sh and root.sh auto finishd"
		echo '' > ${ASROOT_RUN}
        fi
        endtime_dbinstall=$(date +%s)
        costm_dbinstall=`echo ${begintime_dbinstall} ${endtime_dbinstall} | awk '{print ($2-$1)/60}'`

}

#install netca
function install_netca() {
	echo_color info "install listener"
	${ORACLE_HOME}/bin/netca -silent -responsefile ${BASE_INSTALL_DIR}/netca.rsp > ${BASE_INSTALL_DIR}/netca.log
}

#install dbca
function install_dbca() {
	echo_color info "create database...."
	begintime_dbca=$(date +%s})

	#write at 20191204 wriet, so to do write again
	#echo -e "you can visit \033[1;41;33m`ls -t $ORACLE_BASE/cfgtoollogs/dbca/${DB_NAME}/trace.log_* | grep -v '.lck'`\033[0mto known more"
	
	#echo_color info "you can visit  $ORACLE_BASE/cfgtoollogs/dbca/${DB_NAME}/trace.log_* " 

	#ps -ef | grep "${BASE_INSTALL_DIR}/dbca.log" | grep -v grep | awk '{print $2}' | xargs -t -i kill -9 {} >/dev/null 2>&1
	#echo '' > ${BASE_INSTALL_DIR}/dbca.log
	#tail -f ${BASE_INSTALL_DIR}/dbca.log &
	#if [[  -z ${NOPDB}  ]]
	#then
	#	echo_color info "pdbname: ${pdbName}"
	#	${ORACLE_HOME}/bin/dbca -silent -createDatabase  -responseFile ${BASE_INSTALL_DIR}/dbca.rsp #> ${BASE_INSTALL_DIR}/dbca.log
	#else
	#	echo_color info "you chose NOPDB"
	#	${ORACLE_HOME}/bin/dbca -silent -createDatabase  -responseFile ${BASE_INSTALL_DIR}/dbca_NOPDB.rsp #> ${BASE_INSTALL_DIR}/dbca.log
	#fi
	#ps -ef | grep "${BASE_INSTALL_DIR}/dbca.log" | grep -v grep | awk '{print $2}' | xargs -t -i kill -9 {} >/dev/null 2>&1

	echo_color info "you can visit ${BASE_INSTALL_DIR}/dbca.log to known more"
	${scripts_dir}/${ORACLE_SID}.sh > ${BASE_INSTALL_DIR}/dbca.log 2>&1
	sleep 80
	grep -v "#" /etc/oratab | grep ORACLE_HOME:  >/dev/null 2>&1 || echo "${ORACLE_SID}:$ORACLE_HOME:Y" >> /etc/oratab


        endtime_dbca=$(date +%s)
        costm_dbca=`echo ${begintime_dbca} ${endtime_dbca} | awk '{print ($2-$1)/60}'`
}

function init_dbca_script() {
	#DBNAME=DB_NAME, mei de ban fa, zhe shi fu zhi shang yi ge jiao ben de, wo ye nan de qu gai le. he he da.
	export DBNAME=${DB_NAME}

	#make directory for script 
	mkdir -p ${ORACLE_BASE}/admin/${DBNAME}/scripts || exits " mkdir -p ${ORACLE_BASE}/admin/${DBNAME}/scripts FAILED"
	export scripts_dir="${ORACLE_BASE}/admin/${DBNAME}/scripts"
	

	cat << EOF > ${scripts_dir}/${ORACLE_SID}.sh
#!/bin/sh

OLD_UMASK=\`umask\`
umask 0027
mkdir -p $ORACLE_BASE
mkdir -p $ORACLE_BASE/admin/${DBNAME}/adump
mkdir -p $ORACLE_BASE/admin/${DBNAME}/dpdump
mkdir -p $ORACLE_BASE/admin/${DBNAME}/pfile
mkdir -p $ORACLE_BASE/cfgtoollogs/dbca/${DBNAME}
mkdir -p $ORACLE_BASE/audit
mkdir -p $ORADATA
mkdir -p $ORACLE_HOME/dbs
umask \${OLD_UMASK}
PERL5LIB=\$ORACLE_HOME/rdbms/admin:\$PERL5LIB; export PERL5LIB
ORACLE_SID=$ORACLE_SID; export ORACLE_SID
PATH=\$ORACLE_HOME/bin:\$ORACLE_HOME/perl/bin:\$PATH; export PATH
echo You should Add this entry in the /etc/oratab: ${ORACLE_SID}:$ORACLE_HOME:Y
$ORACLE_HOME/bin/sqlplus /nolog  @$ORACLE_BASE/admin/${DBNAME}/scripts/${ORACLE_SID}.sql
EOF
	chmod +x ${scripts_dir}/${ORACLE_SID}.sh

	cat << EOF > ${scripts_dir}/${ORACLE_SID}.sql
set verify off
define sysPassword=${sysPassword}
define systemPassword=${systemPassword}
define pdbAdminPassword=${pdbAdminPassword}
host $ORACLE_HOME/bin/orapwd file=$ORACLE_HOME/dbs/orapw${ORACLE_SID} password=${sysPassword} force=y format=12
@$ORACLE_BASE/admin/${DBNAME}/scripts/CreateDB.sql
@$ORACLE_BASE/admin/${DBNAME}/scripts/CreateDBFiles.sql
@$ORACLE_BASE/admin/${DBNAME}/scripts/CreateDBCatalog.sql
@$ORACLE_BASE/admin/${DBNAME}/scripts/context.sql
@$ORACLE_BASE/admin/${DBNAME}/scripts/CreateClustDBViews.sql
@$ORACLE_BASE/admin/${DBNAME}/scripts/lockAccount.sql
@$ORACLE_BASE/admin/${DBNAME}/scripts/postDBCreation.sql
@$ORACLE_BASE/admin/${DBNAME}/scripts/PDBCreation.sql
@$ORACLE_BASE/admin/${DBNAME}/scripts/plug_${pdbName}.sql
@$ORACLE_BASE/admin/${DBNAME}/scripts/postPDBCreation_${pdbName}.sql
EOF
	chmod +x ${scripts_dir}/${ORACLE_SID}.sql

	cat << EOF > ${scripts_dir}/CreateDB.sql
SET VERIFY OFF
connect "SYS"/"&&sysPassword" as SYSDBA
set echo on
spool $ORACLE_BASE/admin/${DBNAME}/scripts/CreateDB.log append
startup nomount pfile="$ORACLE_BASE/admin/${DBNAME}/scripts/init.ora";
CREATE DATABASE "${DBNAME}"
MAXINSTANCES 8
MAXLOGHISTORY 1
MAXLOGFILES 16
MAXLOGMEMBERS 3
MAXDATAFILES 1024
DATAFILE SIZE 700M AUTOEXTEND ON NEXT  10240K MAXSIZE UNLIMITED
EXTENT MANAGEMENT LOCAL
SYSAUX DATAFILE SIZE 550M AUTOEXTEND ON NEXT  10240K MAXSIZE UNLIMITED
SMALLFILE DEFAULT TEMPORARY TABLESPACE TEMP TEMPFILE SIZE 20M AUTOEXTEND ON NEXT  640K MAXSIZE UNLIMITED
SMALLFILE UNDO TABLESPACE "UNDOTBS1" DATAFILE SIZE 200M AUTOEXTEND ON NEXT  5120K MAXSIZE UNLIMITED
CHARACTER SET ${characterSet}
NATIONAL CHARACTER SET AL16UTF16
LOGFILE GROUP 1  SIZE 512M,
GROUP 2  SIZE 512M,
GROUP 3  SIZE 512M,
GROUP 4  SIZE 512M
USER SYS IDENTIFIED BY "&&sysPassword" USER SYSTEM IDENTIFIED BY "&&systemPassword";
set linesize 2048;
column ctl_files NEW_VALUE ctl_files;
select concat('control_files=''', concat(replace(value, ', ', ''','''), '''')) ctl_files from v\$parameter where name ='control_files';
host echo &ctl_files >>$ORACLE_BASE/admin/${DBNAME}/scripts/init.ora;
spool off
EOF

	cat << EOF > ${scripts_dir}/CreateDBFiles.sql
SET VERIFY OFF
connect "SYS"/"&&sysPassword" as SYSDBA
set echo on
spool $ORACLE_BASE/admin/${DBNAME}/scripts/CreateDBFiles.log append
CREATE SMALLFILE TABLESPACE "USERS" LOGGING DATAFILE SIZE 5M AUTOEXTEND ON NEXT  1280K MAXSIZE UNLIMITED EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT  AUTO;
ALTER DATABASE DEFAULT TABLESPACE "USERS";
spool off
EOF

	cat << EOF > ${scripts_dir}/CreateDBCatalog.sql
SET VERIFY OFF
connect "SYS"/"&&sysPassword" as SYSDBA
set echo on
spool $ORACLE_BASE/admin/${DBNAME}/scripts/CreateDBCatalog.log append
alter session set "_oracle_script"=true;
alter pluggable database pdb\$seed close;
alter pluggable database pdb\$seed open;
host perl ${ORACLE_HOME}/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${DBNAME}/scripts -v  -b catalog  -U "SYS"/"&&sysPassword" ${ORACLE_HOME}/rdbms/admin/catalog.sql;
host perl ${ORACLE_HOME}/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${DBNAME}/scripts -v  -b catproc  -U "SYS"/"&&sysPassword" ${ORACLE_HOME}/rdbms/admin/catproc.sql;
host perl ${ORACLE_HOME}/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${DBNAME}/scripts -v  -b catoctk  -U "SYS"/"&&sysPassword" ${ORACLE_HOME}/rdbms/admin/catoctk.sql;
host perl ${ORACLE_HOME}/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${DBNAME}/scripts -v  -b owminst  -U "SYS"/"&&sysPassword" ${ORACLE_HOME}/rdbms/admin/owminst.plb;
host perl ${ORACLE_HOME}/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${DBNAME}/scripts -v  -b pupbld -u SYSTEM/&&systemPassword  -U "SYS"/"&&sysPassword" ${ORACLE_HOME}/sqlplus/admin/pupbld.sql;
connect "SYSTEM"/"&&systemPassword"
set echo on
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/sqlPlusHelp.log append
host perl ${ORACLE_HOME}/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${DBNAME}/scripts -v  -b hlpbld -u SYSTEM/&&systemPassword  -U "SYS"/"&&sysPassword" -a 1  ${ORACLE_HOME}/sqlplus/admin/help/hlpbld.sql 1helpus.sql;
spool off
spool off
EOF
	
	cat << EOF > ${scripts_dir}/context.sql
SET VERIFY OFF
connect "SYS"/"&&sysPassword" as SYSDBA
set echo on
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/context.log append
host perl ${ORACLE_HOME}/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${DBNAME}/scripts -v  -b catctx -c  'PDB\$SEED CDB\$ROOT'   -U "SYS"/"&&sysPassword" -a 1  ${ORACLE_HOME}/ctx/admin/catctx.sql 1Xbkfsdcdf1ggh_123 1SYSAUX 1TEMP 1LOCK;
alter user CTXSYS account unlock identified by "CTXSYS";
connect "CTXSYS"/"CTXSYS"
host perl ${ORACLE_HOME}/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${DBNAME}/scripts -v  -b dr0defin -c  'PDB\$SEED CDB\$ROOT'  -u CTXSYS/CTXSYS  -U "SYS"/"&&sysPassword" -a 1  ${ORACLE_HOME}/ctx/admin/defaults/dr0defin.sql 1"AMERICAN";
connect "SYS"/"&&sysPassword" as SYSDBA
alter user CTXSYS password expire account lock;
host perl ${ORACLE_HOME}/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${DBNAME}/scripts -v  -b dbmsxdbt -c  'PDB\$SEED CDB\$ROOT'   -U "SYS"/"&&sysPassword" ${ORACLE_HOME}/rdbms/admin/dbmsxdbt.sql;
spool off
EOF

	cat << EOF > ${scripts_dir}/CreateClustDBViews.sql
SET VERIFY OFF
connect "SYS"/"&&sysPassword" as SYSDBA
set echo on
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/CreateClustDBViews.log append
host perl ${ORACLE_HOME}/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${DBNAME}/scripts -v  -b catclust  -U "SYS"/"&&sysPassword" ${ORACLE_HOME}/rdbms/admin/catclust.sql;
host perl ${ORACLE_HOME}/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${DBNAME}/scripts -v  -b catfinal  -U "SYS"/"&&sysPassword" ${ORACLE_HOME}/rdbms/admin/catfinal.sql;
spool off
connect "SYS"/"&&sysPassword" as SYSDBA
set echo on
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/postDBCreation.log append
create or replace directory ORACLE_HOME as '${ORACLE_HOME}';
create or replace directory ORACLE_BASE as '/u01/app/oracle';
grant sysdg to sysdg;
grant sysbackup to sysbackup;
grant syskm to syskm;
EOF
	cat << EOF > ${scripts_dir}/lockAccount.sql
SET VERIFY OFF
connect "SYS"/"&&sysPassword" as SYSDBA
set echo on
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/lockAccount.log append
alter session set "_oracle_script"=true;
alter pluggable database pdb\$seed close;
alter pluggable database pdb\$seed open;
BEGIN
 FOR item IN ( SELECT USERNAME FROM DBA_USERS WHERE ACCOUNT_STATUS IN ('OPEN', 'LOCKED', 'EXPIRED') AND USERNAME NOT IN (
'SYS','SYSTEM') )
 LOOP
  dbms_output.put_line('Locking and Expiring: ' || item.USERNAME);
  execute immediate 'alter user ' ||
         sys.dbms_assert.enquote_name(
         sys.dbms_assert.schema_name(
         item.USERNAME),false) || ' password expire account lock' ;
 END LOOP;
END;
/
alter session set container=pdb\$seed;
BEGIN
 FOR item IN ( SELECT USERNAME FROM DBA_USERS WHERE ACCOUNT_STATUS IN ('OPEN', 'LOCKED', 'EXPIRED') AND USERNAME NOT IN (
'SYS','SYSTEM') )
 LOOP
  dbms_output.put_line('Locking and Expiring: ' || item.USERNAME);
  execute immediate 'alter user ' ||
         sys.dbms_assert.enquote_name(
         sys.dbms_assert.schema_name(
         item.USERNAME),false) || ' password expire account lock' ;
 END LOOP;
END;
/
alter session set container=cdb\$root;
spool off
EOF

	cat << EOF > ${scripts_dir}/postDBCreation.sql
SET VERIFY OFF
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/postDBCreation.log append
host ${ORACLE_HOME}/OPatch/datapatch -skip_upgrade_check -db ${ORACLE_SID};
connect "SYS"/"&&sysPassword" as SYSDBA
set echo on
create spfile='${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora' FROM pfile='${ORACLE_BASE}/admin/${DBNAME}/scripts/init.ora';
connect "SYS"/"&&sysPassword" as SYSDBA
host perl ${ORACLE_HOME}/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${DBNAME}/scripts -v  -b utlrp  -U "SYS"/"&&sysPassword" ${ORACLE_HOME}/rdbms/admin/utlrp.sql;
select comp_id, status from dba_registry;
shutdown immediate;
connect "SYS"/"&&sysPassword" as SYSDBA
startup ;
spool off
EOF

	cat << EOF > ${scripts_dir}/PDBCreation.sql
SET VERIFY OFF
set echo on
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/PDBCreation.log append
EOF

	cat << EOF > ${scripts_dir}/plug_${pdbName}.sql
SET VERIFY OFF
connect "SYS"/"&&sysPassword" as SYSDBA
set echo on
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/plugDatabase.log append
select  'database_running' from dual;
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/plugDatabase.log append
startup ;
CREATE PLUGGABLE DATABASE ${pdbName} ADMIN USER PDBADMIN IDENTIFIED BY "${pdbAdminPassword}" ROLES=(CONNECT)  file_name_convert=NONE  STORAGE ( MAXSIZE UNLIMITED MAX_SHARED_TEMP_SIZE UNLIMITED);
alter pluggable database ${pdbName} open;
alter system register;
EOF

	cat << EOF > ${scripts_dir}/postPDBCreation_${pdbName}.sql
SET VERIFY OFF
connect "SYS"/"&&sysPassword" as SYSDBA
alter session set container=${pdbName};
set echo on
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/postPDBCreation.log append
CREATE SMALLFILE TABLESPACE "USERS" LOGGING  DATAFILE  SIZE 5M AUTOEXTEND ON NEXT  1280K MAXSIZE UNLIMITED  EXTENT MANAGEMENT LOCAL  SEGMENT SPACE MANAGEMENT  AUTO;
ALTER DATABASE DEFAULT TABLESPACE "USERS";
connect ""/"" as SYSDBA
select property_value from database_properties where property_name='LOCAL_UNDO_ENABLED';
connect "SYS"/"&&sysPassword" as SYSDBA
alter session set container=${pdbName};
set echo on
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/postPDBCreation.log append
connect "SYS"/"&&sysPassword" as SYSDBA
alter session set container=${pdbName};
set echo on
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/postPDBCreation.log append
select TABLESPACE_NAME from cdb_tablespaces a,dba_pdbs b where a.con_id=b.con_id and UPPER(b.pdb_name)=UPPER('${pdbName}');
connect "SYS"/"&&sysPassword" as SYSDBA
alter session set container=${pdbName};
set echo on
spool ${ORACLE_BASE}/admin/${DBNAME}/scripts/postPDBCreation.log append
Select count(*) from dba_registry where comp_id = 'DV' and status='VALID';
alter session set container=CDB\$ROOT;
exit;
EOF

	cat << EOF > ${scripts_dir}/init.ora
db_block_size=8192
open_cursors=${open_cursors}
db_name="${DBNAME}"
db_create_file_dest="$ORADATA"
compatible=19.0.0
diagnostic_dest=$ORACLE_BASE
enable_pluggable_database=true
nls_language="AMERICAN"
nls_territory="AMERICA"
processes=${processes}
sga_target=${SGA_TARGET}M
audit_file_dest="${ORACLE_BASE}/admin/${DBNAME}/adump"
audit_trail=none
remote_login_passwordfile=EXCLUSIVE
dispatchers="(PROTOCOL=TCP) (SERVICE=${ORACLE_SID}XDB)"
pga_aggregate_target=${PGA_AGGREGATE_TARGET}M
undo_tablespace=UNDOTBS1
EOF

}

#install post, clear, start_stop,backup
function set_clearFS() {
	#write at 20200804
	#clear days default 7
	[ "${CLEAR_DAYS}" -eq "${CLEAR_DAYS}" ] 2>/dev/null || export CLEAR_DAYS=7
	[ "${ARCHIVE_LOG_CLEAR_DAYS}" -eq "${ARCHIVE_LOG_CLEAR_DAYS}" ] 2>/dev/null || export ARCHIVE_LOG_CLEAR_DAYS=7
	mkdir -p ~/scripts
	cat << EOF > ~/scripts/AutoClearLog.sh
#!/bin/env bash
source ~/.bash_profile
function exits(){
	echo -e "[\`date +%Y%m%d-%H:%M:%S\`] \\033[31;40m\$1\\033[0m"
	[ -z \$2 ] && exit \$2
	exit 1
}


#clear archive log
#DELETE NOPROMPT ARCHIVELOG UNTIL TIME "SYSDATE-7"; 
#DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE "SYSDATE-7"; 
rman target / << EF
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE "SYSDATE-${ARCHIVE_LOG_CLEAR_DAYS}";
EF

#trace/alert.log
cd ${ORACLE_BASE}/diag/rdbms/${DB_NAME}/${ORACLE_SID}/trace || exits "no dir ${ORACLE_BASE}/diag/rdbms/${DB_NAME}/${ORACLE_SID}/trace"
find . -name "*.trc" -mtime +${CLEAR_DAYS} | xargs -t -i rm -rf {}
find . -name "*.trm" -mtime +${CLEAR_DAYS} | xargs -t -i rm -rf {}

#listener.log
cd $ORACLE_BASE/diag/tnslsnr/${ORACLE_HOSTNAME}/listener/alert || exits "no dir $ORACLE_BASE/diag/tnslsnr/${ORACLE_HOSTNAME}/listener/alert"
find . -name "log_*.xml" -mtime +${CLEAR_DAYS} | xargs -t -i rm -rf {}
cd $ORACLE_BASE/diag/tnslsnr/${ORACLE_HOSTNAME}/listener/trace || exits "no dir $ORACLE_BASE/diag/tnslsnr/${ORACLE_HOSTNAME}/listener/trace"
if [[ "\$(du ./listener.log | awk '{print \$1}')" -gt 50000  ]] 
then
	tail -10000 > ./listener.log.bak
	echo '' > ./listener.log
fi

#audit log
cd /u01/app/oracle/admin/${DB_NAME}/adump || exits "no dir /u01/app/oracle/admin/${DB_NAME}/adump"
find . -name "*.aud" -mtime +${CLEAR_DAYS} | xargs -t -i rm -rf {}

EOF

	chmod +x ~/scripts/AutoClearLog.sh

}

function set_crontab() {
	[ -f ~/.crontab${dt}.cront ] || touch ~/.crontab${dt}.cront
	crontab -l 1> ~/.crontab${dt}.cront 2>/dev/null
	[ "`tail -1 ~/.crontab${dt}.cront`" == "30 23 * * 0 . ~/scripts/AutoClearLog.sh" ] || echo '30 23 * * 0 . ~/scripts/AutoClearLog.sh' >> ~/.crontab${dt}.cront
	crontab  ~/.crontab${dt}.cront
#	crontab -l | tail -1
}

function set_start_stop() {
	#this script is too old, need to rewrite
        [ -d ~/scripts/  ] || mkdir ~/scripts/
        startup_txt="
#!/bin/env bash\n
lsnrctl start >/dev/null 2>&1\n
sqlplus / as sysdba <<EOF\n
startup\n
alter pluggable database all open;\n
EOF\n
"
        echo -e ${startup_txt} > ~/scripts/oracle_start.sh
        chmod +x  ~/scripts/oracle_start.sh
        sed -i 's/^\s*//' ~/scripts/oracle_start.sh
        stop_txt="
#!/bin/env bash\n
lsnrctl stop >/dev/null 2>&1\n
sqlplus / as sysdba <<EOF\n
shutdown immediate\n
EOF\n
"
        echo -e ${stop_txt} > ~/scripts/oracle_stop.sh
        chmod +x  ~/scripts/oracle_stop.sh
        sed -i 's/^\s*//' ~/scripts/oracle_stop.sh
echo_color info "set  ~/scripts/oracle_stop.sh ~/scripts/oracle_start.sh finish"
echo_color info "start: ~/scripts/oracle_start.sh"
echo_color info "stop: ~/scripts/oracle_stop.sh"

}


function set_Backup() {
	#this version is 12.2, I will rewrite it if have time.
	backupdir=${ORACLE_BASE}/backup
	mkdir -p ${ORACLE_BASE}/backup
	mkdir -p ~/scripts
	cpup="`cat /proc/cpuinfo | grep processor | wc -l`"
	parallel=$(( ${cpup} / 8 ))
	[ "${parallel}" -eq "${parallel}" ] || export parallel=1
	[ "${parallel}" -eq "0" ] && export parallel=1
	[ "${parallel}" -gt "8" ] && export parallel=8

	valuespara="
	dt=\$(date +%Y%m%d-%H%M%S)\n
	source ~/.bash_profile\n
	export dt=\$(date +%Y%m%d-%H%M%S)\n
	expdp system/${systemPassword}@127.0.0.1:1521/${pdbName} directory=DataPump_Dir  dumpfile=${pdbName}_\${dt}_%U.dump job_name=${pdbName}\${dt} full=y  logtime=all logfile=${pdbName}_\${dt}_export.log COMPRESSION=all  parallel=${parallel}\n
	cd ${backupdir} || exit 1\n
	echo \"impdp system/${systemPassword}@127.0.0.1:1521/${pdbName} directory=DataPump_Dir  dumpfile=${pdbName}_\${dt}_%U.dump job_name=${pdbName}\${dt} full=y  logtime=all logfile=${pdbName}_\${dt}_import.log  parallel=${parallel}\" >> ${backupdir}/${pdbName}_\${dt}_export.log\n
	tar -cvf ./expdp_${pdbName}_\${dt}.tar ./${pdbName}_\${dt}_*.* --remove-files\n
	find ./ -name 'expdp_${pdbName}_*.tar' -mtime +3 | /usr/bin/xargs rm -rf {}\n

	"
	sqlplus  sys/${sysPassword}@127.0.0.1:1521/${pdbName} as sysdba <<EOF
	CREATE DIRECTORY DataPump_Dir AS '${backupdir}';
	grant write,read on directory DataPump_Dir  to system;
EOF
	echo -e ${valuespara} > ~/scripts/backupdata.sh
	sed -i 's/^\s*//' ~/scripts/backupdata.sh
	chmod +x ~/scripts/backupdata.sh
	echo ""
	echo_color info "you can run ~/scripts/backupdata.sh to backup your database ${pdbName}. just only reference"
}


function isntall_post() {
	set_clearFS
	set_start_stop
	set_Backup
	set_crontab

	#set auto start on boot
	if [ -z ${rootpassword} ]
	then
		echo 'grep oracle_start /etc/rc.local || echo 'su - ${CURRENT_USER} -c /home/${CURRENT_USER}/scripts/oracle_start.sh' >> /etc/rc.local && chmod +x /etc/rc.d/rc.local' >> ${ASROOT_RUN}
	else
		su_command  "grep oracle_start /etc/rc.local || echo 'su - ${CURRENT_USER} -c /home/${CURRENT_USER}/scripts/oracle_start.sh' >> /etc/rc.local && chmod +x /etc/rc.d/rc.local " 
	fi

        grep "define" ${ORACLE_HOME}/sqlplus/admin/glogin.sql >/dev/null 2>&1  || echo -e "define _editor='vi'" >> ${ORACLE_HOME}/sqlplus/admin/glogin.sql
        grep "sqlprompt" ${ORACLE_HOME}/sqlplus/admin/glogin.sql >/dev/null 2>&1 || echo  set sqlprompt "_user'@'_connect_identifier> " >> ${ORACLE_HOME}/sqlplus/admin/glogin.sql
        grep "linesize" ${ORACLE_HOME}/sqlplus/admin/glogin.sql >/dev/null 2>&1  || echo -e '''set linesize 100 pagesize 50''' >> ${ORACLE_HOME}/sqlplus/admin/glogin.sql
        grep stty ~/.bash_profile >/dev/null 2>&1 || echo "stty erase ^H" >> ~/.bash_profile

	$ORACLE_HOME/bin/sqlplus / as sysdba << EOF >> ${BASE_INSTALL_DIR}/sqlplus_set_parameters.log
ALTER PROFILE default LIMIT PASSWORD_LIFE_TIME UNLIMITED;
exec dbms_xdb_config.sethttpsport(${EMPORT});
EOF

	[[  -z ${NOPDB} ]] &&  $ORACLE_HOME/bin/sqlplus / as sysdba << EOF  >> ${BASE_INSTALL_DIR}/sqlplus_set_parameters.log
alter pluggable database ${pdbName} save state;
alter session set container=${pdbName};
ALTER PROFILE default LIMIT PASSWORD_LIFE_TIME UNLIMITED;
EOF
}

#help this script
function help_this_script() {
	echo_color info "you can visit https://github.com/ddcw/ddcw to known more"
	echo_color red  "------------------------sh ${thisript} [PARAMETER=VALUE] ...------------------------"
	echo_color red "------------------------CURRENT VALUES ------------------------"
	need_print_value="DB_NAME gdbName pdbName ORACLE_SID ORACLE_HOME ORACLE_BASE INVENTORY_LOCATION_DIR ORACLE_SOFTWARE_NAME ORADATA characterSet open_cursors processes PGA_AGGREGATE_TARGET SGA_TARGET LISTENER_PORT EMPORT sysPassword systemPassword pdbAdminPassword "
	for i in ${need_print_value}
	do
		eval echo "$i=\$$i"
	done
	echo "rootpassword="
	echo_color red "------------------------      END      ------------------------"
	echo_color info "TIPS:  characterSet : AL32UTF8 ZHS16GBK"
	exit 0
	
}

#to config user set variable
function configUSERset() {
	for i in ${PARAMS}
	do
		param=`echo $i | awk -F "=" '{print $1}'`
		value=`echo $i | awk -F "=" '{print $2}'`
		case ${param} in
			ORACLE_SID|SID|oracle_sid|sid)
				export ORACLE_SID=${value}
				;;
			pdbName|pdbname|PDBNAME|PdbName)
				export pdbName=${value}
				;;
			DB_NAME|dbname|dbName|DBname)
				export DB_NAME=${value}
				;;
			DB_UNIQUE_NAME)
				export DB_UNIQUE_NAME=${value}
				;;
			characterSet|characterset|CHARACTERSET|ZFJ|zfj)
				export characterSet=${value}
				;;
			processes|Processes|PROCESSES)
				export processes=${value}
				;;
			open_cursors|OPEN_CURSORS|OPENCURSORS|opencursors)
				export open_cursors=${value}
				;;
			gdbName|gdbname|GDBNAME|GloableName|GLOABLENAME|gloablename)
				export gdbName=${value}
				;;
			pga_aggregate_target|PGA|pga|PGA_AGGREGATE_TARGET)
				export PGA_AGGREGATE_TARGET=%${value}
				;;
			sga_target|sga|SGA|SGA_TARGET)
				export SGA_TARGET=${value}
				;;
			sysPassword|syspassword|SYSPASSWORD|sys|SYS|sysPW|SYSPW)
				export sysPassword=${value}
				;;
			systemPassword|systempassword|systemPW|SYSTEMPASSWORD|SYSTEMPW)
				export systemPassword=${value}
				;;
			pdbAdminPassword|pdbadmin|pdbpassword|PDBPW|PDBPASSWORD)
				export pdbAdminPassword=${value}
				;;
			p|password|pw|-p|PW|pw|passwd|PASSWD|passWD|PASSWORD)
				export sysPassword=${value}
				export systemPassword=${value}
				export pdbAdminPassword=${value}
				;;
			h|-h|--h|help|-help|--help|HELP|--HELP)
				export HELP_FLAG=1
				;;
			ORADATA|dbdir|datafile_dir|dd)
				ORADATA=${value}
				;;
			rootpassword|Root|root|ROOT|rootP|ROOTPASSWORD|RP|rp|-rootpasswd|-rootpassword)
				export rootpassword=${value}
				;;
			INVENTORY_LOCATION_DIR)
				export INVENTORY_LOCATION_DIR=${value}
				;;
			IGNORE_PACK|ignore_pack|Ignore_pack|Ignore_Pack)
				export IGNORE_PACK=${value}
				;;
			EMPORT|emport|Emport)
				export EMPORT=${value}
				;;
			LISTENER_NAMES|listener_names|LISTENER_NAME)
				export LISTENER_NAMES=${value}
				;;
			ORACLE_SOFTWARE_NAME)
				export ORACLE_SOFTWARE_NAME=${value}
				;;
			LISTENER_PORT|listener_port|Listener_port)
				export LISTENER_PORT=${value}
				;;
			ORACLE_SOFTWARE)
				export ORACLE_SOFTWARE=${value}
				;;
			NOPDB)
				export NOPDB=${value}
				;;
			ORACLE_HOME)
				export ORACLE_HOME=${value}
				;;
			ORACLE_BASE)
				export ORACLE_BASE=${value}
				;;
			SE_ROOT_PASSWORD)
				#when SE_ROOT_PASSWORD=ANY_KEY, you should input rootpassword when script run.
				export SE_ROOT_PASSWORD=${value}
				;;
			*)
				export HELP_FLAG=1
				;;
		esac
	done
}

#to judge rootpassword
function judge_rootpassword() {
	su_command "touch /tmp/.flag_rootpassword_${begintime}"	
	[[ -f /tmp/.flag_rootpassword_${begintime} ]] || exits "root password is wrong"
}

#this is main,ko no DIO da
function main_() {
	init_parameter
	configUSERset
	[[ -z ${HELP_FLAG} ]] || help_this_script
	#when rootpassword is TRUE, yum install expect.
	[[ -z ${rootpassword} ]] || yum install expect -y >/dev/null 2>&1
	[[ -z ${rootpassword} ]] || judge_rootpassword

	mimacishu_current=0
	while [[ ! -z ${SE_ROOT_PASSWORD} ]] && [ ${mimacishu_current} -lt ${mimacishu_max} ]
	do
		read -t 60 -p "please input root password:" rootpasswords
		export rootpassword=${rootpasswords}
		if [[ ! -z ${rootpassword} ]] 
		then
			su_command "touch /tmp/.flag_rootpassword_${begintime}"
			[[ -f /tmp/.flag_rootpassword_${begintime} ]] && break
			echo_color warn "password is wrong"
		fi
		mimacishu_current=$[ ${mimacishu_current} + 1 ]
	done


	mkdir_authorization
	[[ ${IGNORE_PACK} -eq 1 ]] ||  check_PACK
	check_env
	unzip_to_ORACLE_HOME

	init_db_install_rsp
	init_netca_rsp
#	init_dbca_rsp
	init_dbca_script

	install_db_software
	install_netca
	install_dbca
	
	isntall_post

	endtime=`date +%s`
	costm=`echo ${begintime} ${endtime} | awk '{print ($2-$1)/60}'`
	echo_color info "you can run ~/scripts/AutoClearLog.sh to clear log , and it auto run at 23:30 Sunday"
	echo_color info "OEM: https://127.0.0.1:${EMPORT}/em   --without container name"
	echo ""
	echo_color info "sysPassword=${sysPassword}"
	echo_color info "systemPassword=${systemPassword}"
	echo_color info "pdbAdminPassword=${pdbAdminPassword}\n"
	echo_color info "dbinstall cost: ${costm_dbinstall}"
	echo_color info "dbca cost: ${costm_dbca}"
	echo -e "\n\033[1;41;33m `date +%Y%m%d-%H:%M:%S`TOTAL COST ${costm} minutes\033[0m"

	[[ $(wc -l ${ASROOT_RUN} | awk '{print $1}') -gt 1 ]] && echo_color warn "you should run ${ASROOT_RUN} to finishd"
}
main_
