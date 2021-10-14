#!/bin/bash

LOGFILE="sftp-download"

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>"${LOGFILE}-$(date +%F-%T).log" 2>&1

#lftp -c 'open -e "set ftp:initial-prot ""; \
#   set ftp:ssl-force false; \
#   set ftp:ssl-protect-data false; "\
#   -u "sftp_user","sftp_password" \
#   ftp://127.0.0.1'

#lftp -d -c 'open -u "sftp_user","sftp_password" ftp://127.0.0.1
#get files/testfile -o testfolder

if [ $# -eq 0 ]; then
	RETC=123
	echo "RETC = ${RETC}"
	echo "No arguments supplied"
	exit ${RETC}
fi

if [ $1 -gt 0 ]; then
	RETC=124
	echo "RETC = ${RETC}"
	echo "This parameter is 0 - (Current record)"
	echo "Or negaive number - (Historical record)"
	exit ${RETC}
fi

USER=$(whoami)

#parameters to be edited for local environment
# the technical user
TUSER=sftp_user
TPASS=sftp_password

# the ftps servers addres
FTPS_HOST=localhost
FTPS_PORT=21000

# the name of the required file
FILESRC=testfile

# hte NAS mount point
FILEDST=testfolder

#Test connection with remote server
lftp -c "open -e \"set ftps:initial-prot; \
	set ftp:ssl-force true; \
	set ssl:verify-certificate false; \
	set ftp:ssl-protect-data true; \"\
	-u "${TUSER}","${TPASS}" \
	${FTPS_HOST}; ls ${FILESRC}*" | tee "/tmp/temp.file"
RC=$?
if [ $RC -ne 0 ]; then
	echo "RC = ${RC}"
	echo "Error: connection to ftps server failed"
	exit $RC
fi

lista=$(awk '{ print $9 }' /tmp/temp.file)
arr=($lista)

# remove the temp file
rm /tmp/temp.file

if [ ${#arr[@]} -le ${1#-} ]; then
	RETC=125
	echo "RETC = ${RETC}"
	echo "The history of the record is not kept that long"
	exit ${RETC}
fi

# the name of the required file
FILESRC=${arr[$1]}

#copy the desired file using sftp protocol, user and password
lftp -c "open -e \"set ftps:initial-prot; \
        set ftp:ssl-force true; \
	set ssl:verify-certificate false; \
        set ftp:ssl-protect-data true; \"\
        -u "${TUSER}","${TPASS}" \
        ${FTPS_HOST}:;

get ${FILESRC} -o ${FILEDST}; exit"

#Test for ftps connection success and throw error otherwisse
RC=$?
if [ $RC -ne 0 ]; then
	echo "RC = ${RC}"
	echo "Error: file already present on NAS storage"
	exit $RC
fi

find ${LOGFILE}*.log -mtime +10 -type f -delete
