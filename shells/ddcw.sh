#!/bin/env bash
#write by ddcw 20200710 first
#this script is for manage other shell scripts ,
#it's have add , delete , update ,rollback commands (scripts) 
#and its can used some default theme like PS1

#define variable
ddcwdir="/usr/local/ddcw"
rollbackdir=${ddcw}/rollback
confdir=/etc/ddcw
mandir=/usr/share/man
completion=/etc/bash_completion.d

default_conf=ddcw.conf
custom_conf=custom.conf

#config content
#scriptname install_time md5sum version(number)
#ddcw	20200717093522	XXXXXXXXXX 1
