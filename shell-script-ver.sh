#!/bin/bash

if [ $1 -gt 0 ]; then
	echo "This parameter is 0 - (Current record)"
	echo "Or negaive number - (Historical record)"
	exit 124
fi

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
	
	TPASS=$(echo $OUT | awk -F"," '{print $1}')
fi

#parameters to be edited for local environment
# the technical user
USER=TA06546

# the ftps servers addres
FTPS_HOST=IT7E.intranet.unicredit.it
FTPS_PORT=921

# the name of the required file
FILESRC=QQ.NAS.BX.DDD.UPDTNDG.XIBM.NET

# hte NAS mount point
FILEDST=/opt/FileNet/shared/FileStores

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
