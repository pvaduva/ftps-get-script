#!/bin/bash


#lftp -c 'open -e "set ftp:initial-prot ""; \
#   set ftp:ssl-force false; \
#   set ftp:ssl-protect-data false; "\
#   -u "sftp_user","sftp_password" \
#   ftp://127.0.0.1'

#lftp -d -c 'open -u "sftp_user","sftp_password" ftp://127.0.0.1
#get files/testfile -o testfolder
#'

#parameters to be edited for local environment
# the technical user
TUSER=files
TPASS=FSBhuNOR

# the ftps servers addres
FTPS_HOST=localhost

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
	ftp://${FTPS_HOST}:21000; ls ${FILESRC}* | awk \'{ print $1 }\'"
RC=$?
if [ $RC -ne 0 ]; then
	echo "Error: connection to ftps server failed"
	exit $RC
fi

#copy the desired file using sftp protocol, user and password
lftp -c "open -e \"set ftps:initial-prot; \
        set ftp:ssl-force true; \
	set ssl:verify-certificate false; \
        set ftp:ssl-protect-data true; \"\
        -u "${TUSER}","${TPASS}" \
        ftp://${FTPS_HOST}:21000;

get ${FILESRC} -o ${FILEDST}; exit"

#Test for ftps connection success and throw error otherwisse
RC=$?
if [ $RC -ne 0 ]; then
	echo "Error: file already present on NAS storage"
	exit $RC
fi
