#!/bin/bash

#Password retrieving procedure
PasswordRetrived=0
while [ $PasswordRetrived -eq 0 ] ; do
	OUT=`clipasswordsdk GetPassword -p AppDescs.AppID=AIM_appcode \
	       	-p Query="Safe=AIM_appcode_env;Folder=Root;Object=xxxxxxx" \ 
	       	-p FailRequestOnPasswordChange=false -o Password,PasswordChangeInProcess 2>&1`
	RC = $?
	if [ $RC -ne 0 ] ; then
		break
	fi
	InProcess=`echo $OUT | awk -F"," '{print $2}'`
	if [ "$InProcess" != "true" ] ; then
		PasswordRetrived=1
	else
		sleep 1.5
	fi
done

# Test if password has been retrieved and throw 
# error if not
if [ $PasswordRetrived -eq 0 ] ; then
	echo $OUT
	echo "Error: Password could not be retrieved"
	exit $RC
else
	
	PASS=$(echo $OUT | awk -F"," '{print $1}')
fi

#parameters to be edited for local environment
USER=TA06546
FTPS_HOST=IT7E.intranet.unicredit.it
FILESRC=QQ.NAS.BX.DDD.UPDTNDG.XIBM.NET
FILEDST=/opt/FileNet/shared/FileStores

#Test connection with remote server
lftp 'open -e "set ftps:initial-prot ""; \
	set ftp:ssl-force true; \
	set ftp:ssl-protect-data true; "\
	-u "${USER}","${PASS}" \
	ftps://${FTPS_HOST}; ls'
RC=$?
if [ $RC -ne 0 ]; then
	echo "Error: connection to ftps server failed"
	exit $RC
fi

#copy the desired file using sftp protocol, user and password
lftp -c 'open -e "set ftps:initial-prot ""; \
   set ftp:ssl-force true; \
   set ftp:ssl-protect-data true; "\
   -u "${USER}","${PASS}" \
   ftps://${FTSP_HOST};

get ${FILESRC} -o ${FILEDST}'

#Test for ftps connection success and throw error otherwisse
RC=$?
if [ $RC -ne 0]; then
	echo "Error: file already present on NAS storage"
	exit $RC
fi
