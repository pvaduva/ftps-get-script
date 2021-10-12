#!/bin/bash

#Test for the existance of arguments
if [ $# -eq 0 ]; then
	echo "No arguments supplied"
	exit 123
fi

if [ $1 -gt 0 ]; then
	echo "This parameter is 0 - (Current record)"
	echo "Or negaive number - (Historical record)"
	exit 124
fi

USER=$(whoami)
BACKUPSERV=false
RAND1=$((1 + $RANDOM % 10000))
if [ $USER = TA06547 ]; then
	# the technical user QQ env
	TUSER=TA06547

	# the ftps servers addres QQ
	FTPS_HOST=IT7E.intranet.unicredit.it
	FTPS_HOST2=IT7E.intranet.unicredit.it
	FTPS_PORT=921
	FTPS_PORT2=921

	# the name of the required file QQ
	FILESRC=QQ.NAS.BX.DDD.DELMRNDG.XIBM.NET

	# hte NAS mount point QQ
	FILEDST=/opt/FileNet/shared/host
elif [ $USER = TA06548 ]; then
	# the technical user for PROD env
	TUSER=TA06548

	# the ftps servers addres for PROD
	FTPS_HOST=IT7A.intranet.unicredit.it
	FTPS_HOST2=IT7B.intranet.unicredit.it
	FTPS_PORT=921
	FTPS_PORT2=921

	# the name of the required file PROD env
	FILESRC=HP.NAS.BX.DDD.DELMRNDG.XIBM.NET

	# hte NAS mount point for PROD env
	FILEDST=/opt/FileNet/shared/host
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

#Test connection with remote server
lftp -c "open -e \"set ftps:initial-prot; \
	set ftp:ssl-force true; \
	set ssl:verify-certificate false; \
	set ftp:ssl-protect-data true; \"\
	-u "${TUSER}","${TPASS}" \
	ftp://${FTPS_HOST}:${FTPS_PORT}; ls ${FILESRC}*" > "/tmp/temp${RAND1}.file"
RC=$?
if [ $RC -ne 0 ]; then
	echo "Connection to ${FTPS_HOST} is down"
	echo "trying to connect to ${FTPS_HOST2}"
	#Test connection with remote server
	lftp -c "open -e \"set ftps:initial-prot; \
		set ftp:ssl-force true; \
		set ssl:verify-certificate false; \
		set ftp:ssl-protect-data true; \"\
		-u "${TUSER}","${TPASS}" \
		ftp://${FTPS_HOST2}:${FTPS_PORT2}; ls ${FILESRC}*" > "/tmp/temp${RAND1}.file"
	RC=$?
	if [ $RC -ne 0 ]; then
		echo "Error: connection to ftps server failed"
		exit $RC
	BACKUPSERV=true
	fi
fi

lista=$(awk '{ print $9 }' /tmp/temp${RAND1}.file)
arr=($lista)

# remove the temp file
rm /tmp/temp${RAND1}.file

if [ ${#arr[@]} -le ${1#-} ]; then
       echo "The history of the record is not kept that long"
       exit 125
fi

# the name of the required file
FILESRC=${arr[$1]}

#copy the desired file using sftp protocol, user and password
if [ $BACKUPSERV = false ]; then
	lftp -c "open -e \"set ftps:initial-prot; \
	        set ftp:ssl-force true; \
		set ssl:verify-certificate false; \
	        set ftp:ssl-protect-data true; \"\
	        -u "${TUSER}","${TPASS}" \
	        ftp://${FTPS_HOST}:${FTPS_PORT};
	
	get ${FILESRC} -o ${FILEDST}; exit"
else
	lftp -c "open -e \"set ftps:initial-prot; \
	        set ftp:ssl-force true; \
		set ssl:verify-certificate false; \
	        set ftp:ssl-protect-data true; \"\
	        -u "${TUSER}","${TPASS}" \
	        ftp://${FTPS_HOST2}:${FTPS_PORT2};
	
	get ${FILESRC} -o ${FILEDST}; exit"
fi

#Test for ftps connection success and throw error otherwisse
RC=$?
if [ $RC -ne 0 ]; then
	echo "Error: file already present on NAS storage"
	exit $RC
fi
