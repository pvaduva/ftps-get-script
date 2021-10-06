#!/bin/bash


#lftp -c 'open -e "set ftp:initial-prot ""; \
#   set ftp:ssl-force false; \
#   set ftp:ssl-protect-data false; "\
#   -u "sftp_user","sftp_password" \
#   ftp://127.0.0.1'

#lftp -d -c 'open -u "sftp_user","sftp_password" ftp://127.0.0.1
#get files/testfile -o testfolder

if [ $1 -gt 0 ]; then
	echo "This parameter is 0 - (Current record)"
	echo "Or negaive number - (Historical record)"
	exit 124
fi

#parameters to be edited for local environment
# the technical user
TUSER=files
TPASS=FSBhuNOR

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
	ftp://${FTPS_HOST}:${FTPS_PORT}; ls ${FILESRC}*" > "/tmp/temp.file"
RC=$?
if [ $RC -ne 0 ]; then
	echo "Error: connection to ftps server failed"
	exit $RC
fi

lista=$(awk '{ print $9 }' /tmp/temp.file)
arr=($lista)

# remove the temp file
rm /tmp/temp.file

if [ ${#arr[@]} -le ${1#-} ]; then
       echo "The history of the record is not kept that long"
       exit 125
fi

# the name of the required file
FILESRC=${arr[$1]}

#copy the desired file using sftp protocol, user and password
lftp -c "open -e \"set ftps:initial-prot; \
        set ftp:ssl-force true; \
	set ssl:verify-certificate false; \
        set ftp:ssl-protect-data true; \"\
        -u "${TUSER}","${TPASS}" \
        ftp://${FTPS_HOST}:${FTPS_PORT};

get ${FILESRC} -o ${FILEDST}; exit"

#Test for ftps connection success and throw error otherwisse
RC=$?
if [ $RC -ne 0 ]; then
	echo "Error: file already present on NAS storage"
	exit $RC
fi
