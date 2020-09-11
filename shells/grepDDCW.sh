#!/bin/env bash
#write by ddcw at 20200911
#USAGES: sh grepDDCW.sh KEY_WORD FILES_NAME
#relay on sed 


#modified info


#define variable
begintime=`date +%s`
dt=$(date +%Y%m%d-%H%M%S)
PARAMS=$@
PARAMS_ARRAY=($@)
COLOR="red"
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

sed --help >/dev/null 2>&1 || exits "this OS has not command sed in PATH"

function help_this() {
	echo_color info "USAGE: sh ${thisript} KEY_WORD|REGEX FILE_NAME [--color green|red|warn|blue] "
	exit 1
}

#KEY_WORD=$1
#FILE_NAME=$2
#
#eval sed 's/${KEY_WORD}/$(echo -e "\033[31;40m\\\0\033[0m")/g' ${FILE_NAME}


function sed_key_word() {
#	red='\033[31;40m'
#	green='\033[32;40m'
	
	#for i in ${KEY_WORD}
	#do
	#	reg_key="${reg_key}s/${i}/\$(echo -e \"\${${COLOR}}\\\\\\0\\033[0m\");"
	#done
	#reg_key=${reg_key::-1}
	#echo ${reg_key} --

	#eval sed '$(echo ${reg_key})/g' ${FILE_NAME}


	eval sed 's/${KEY_WORD}/$(echo -e "${1}\\\0\033[0m")/g' ${FILE_NAME}
}

function grep_color() {
	[[ -z ${KEY_WORD} ]] && help_this
	#[[ -f ${FILE_NAME} ]] || exits "NO FILES ${FILE_NAME}"
	case ${COLOR} in
		red)
			sed_key_word '\033[31;40m'
			;;
		green)
			sed_key_word '\033[32;40m'
			;;
		warn)
			sed_key_word '\033[1;5;41;33m'
			;;
		yellow)
			sed_key_word '\033[33;40m'
			;;
		blue)
			sed_key_word '\033[34;40m'
			;;
		*)
			help_this
			;;
	esac
}


#judeg user params
function _main() {
	params_num=0
        for i in ${PARAMS}
        do
		[[ ${PARAMS_ARRAY[params_num]} == "${i}" ]] || continue
		case $i in
			--color|-c|--COLOR|-C)
				export COLOR=${PARAMS_ARRAY[params_num + 1]}
				params_num=$[ ${params_num} + 2 ]
				;;
			--KEY|--key|-k|-K)
				KEY_WORD="${i} "
				params_num=$[ ${params_num} + 2 ]
				;;
			--dir|--directory|-f|-F|--f|--F)
				export FILE_NAME=${i}/*
				params_num=$[ ${params_num} + 2 ]
				;;
			--file|--FILE|-f|-F|--f|--F)
				export FILE_NAME=${i}
				params_num=$[ ${params_num} + 2 ]
				;;
			--help|-h|-H|--HELP)
				help_this
				;;
			*)
				params_num=$[ ${params_num} + 1 ]
				[[ -f ${i} ]] && export FILE_NAME=${i} && continue
				[[ -d ${i} ]] && export FILE_NAME=${i}/* || export KEY_WORD="${i}"
				
		esac	
	done
	#export KEY_WORD=${KEY_WORD::-1}
}



_main
grep_color

