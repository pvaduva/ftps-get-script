#!/bin/bash

#Test for the existance of arguments
if [ $# -eq 0 ]; then
	echo "No arguments supplied"
	exit 123
fi

if [ $2 -gt 0 ]; then
	echo "This parameter is 0 - (Current record)"
	echo "Or negaive number - (Historical record)"
	exit 124
fi

version=$2
BACKUPSERV=false
RAND1=$((1 + $RANDOM % 10000))
if [ $1 = QQ ]; then
	#Password retrieving procedure
	PasswordRetrived=0
	while [ $PasswordRetrived -eq 0 ] ; do
		OUT=`clipasswordsdk GetPassword -p AppDescs.AppID=AIM_DDD \
		       	-p Query="Safe=AIM_DDD_QA;Folder=Root;Object=TA06547_RACF_MILANO_DDD" \ 
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

	# the technical user QQ env
	TUSER=TA06547

	# the ftps servers addres QQ
	FTPS_HOST=IT7E.intranet.unicredit.it
	FTPS_HOST2=IT7E.intranet.unicredit.it
	FTPS_PORT=921
	FTPS_PORT2=921
	FILESRC=QQ.NAS.BX.DDD.UPDTNDG.XIBM.NET

	# hte NAS mount point QQ
	FILEDST=/opt/FileNet/shared/host
elif [ $1 = QE ]; then
	#Password retrieving procedure
	PasswordRetrived=0
	while [ $PasswordRetrived -eq 0 ] ; do
		OUT=`clipasswordsdk GetPassword -p AppDescs.AppID=AIM_DDD \
		       	-p Query="Safe=AIM_DDD;Folder=Root;Object=TA06546_RACF_MILANO_DDD" \ 
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

	# the technical user for PROD env
	TUSER=TA06546

	# the ftps servers addres for PROD
	FTPS_HOST=IT5A.intranet.unicredit.it
	FTPS_HOST2=IT5B.intranet.unicredit.it
	FTPS_PORT=921
	FTPS_PORT2=921
	FILESRC=QE.NAS.BX.DDD.UPDTNDG.XIBM.NET

	# hte NAS mount point for PROD env
	FILEDST=/opt/FileNet/shared/host
elif [ $1 = HV ]; then
	#Password retrieving procedure
	PasswordRetrived=0
	while [ $PasswordRetrived -eq 0 ] ; do
		OUT=`clipasswordsdk GetPassword -p AppDescs.AppID=AIM_DDD \
		       	-p Query="Safe=AIM_DDD_DEV;Folder=Root;Object=TA06548_RACF_MILANO_DDD" \ 
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

	# the technical user for PROD env
	TUSER=TA06548

	# the ftps servers addres for PROD
	FTPS_HOST=IT7A.intranet.unicredit.it
	FTPS_HOST2=IT7B.intranet.unicredit.it
	FTPS_PORT=921
	FTPS_PORT2=921
	FILESRC=HV.NAS.BX.DDD.UPDTNDG.XIBM.NET

	# hte NAS mount point for PROD env
	FILEDST=/opt/FileNet/shared/host
else
	echo "The environment is not valid"
	echo "it should be QQ QE or VN"
	exit 124
fi

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
	${FTPS_HOST}; ls ${FILESRC}*" > "/tmp/temp-bash-${RAND1}.file"
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
		${FTPS_HOST2}; ls ${FILESRC}*" > "/tmp/temp-bash-${RAND1}.file"
	RC=$?
	if [ $RC -ne 0 ]; then
		echo "Error: connection to ftps server failed"
		exit $RC
	fi
	BACKUPSERV=true
fi

lista=$(awk '{ print $9 }' /tmp/temp-bash-${RAND1}.file)
arr=($lista)

# remove the temp file
rm /tmp/temp-bash-${RAND1}.file

if [ ${#arr[@]} -le ${version#-} ]; then
       echo "The history of the record is not kept that long"
       exit 125
fi

# the name of the required file
version=$((version-1))
FILESRC=${arr[$version]}

#copy the desired file using sftp protocol, user and password
if [ $BACKUPSERV = false ]; then
	lftp -c "open -e \"set ftps:initial-prot; \
	        set ftp:ssl-force true; \
		set ssl:verify-certificate false; \
	        set ftp:ssl-protect-data true; \"\
	        -u "${TUSER}","${TPASS}" \
	        ${FTPS_HOST};
	
	get ${FILESRC} -o ${FILEDST}; exit"
else
	lftp -c "open -e \"set ftps:initial-prot; \
	        set ftp:ssl-force true; \
		set ssl:verify-certificate false; \
	        set ftp:ssl-protect-data true; \"\
	        -u "${TUSER}","${TPASS}" \
	        ${FTPS_HOST2};
	
	get ${FILESRC} -o ${FILEDST}; exit"
fi

#Test for ftps connection success and throw error otherwisse
RC=$?
if [ $RC -ne 0 ]; then
	echo "Error: file already present on NAS storage"
	exit $RC
fi
