#!/bin/bash

connect_to_cyberark () {
	#Password retrieving procedure
	PasswordRetrived=0
	while [ $PasswordRetrived -eq 0 ] ; do
		OUT=$(/opt/CARKaim/sdk/clipasswordsdk GetPassword -p AppDescs.AppID=${1} \
			-p Query="Safe=${2};Folder=Root;Object=${3}" \
			-p FailRequestOnPasswordChange=false -o Password,PasswordChangeInProcess 2>&1)
		RC=$?
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
		echo "Error: Password for user ${3} could not be retrieved"
		exit $RC
	else
		CPASS=$(echo $OUT | awk -F"," '{print $1}')
	fi

}

if [ $1 = QQ ]; then
	POSTURL="https://ddd-cpe-qq.validazione.usinet.it/DDMEGABatch/"
	#Modify this 
	FILEDST="/opt/FileNet/shared/host/"
elif [ $1 = QE ]; then
	POSTURL="https://ddd-cpe-qe.collaudo.usinet.it/DDMEGABatch/"
	#Modify this 
	FILEDST="/opt/FileNet/shared/host/"
elif [ $1 = HV ]; then
	POSTURL="https://ddd-cpe-hv.intranet.usinet.it/DDMEGABatch/"
	#Modify this 
	FILEDST="/opt/FileNet/shared/host/"
fi
LOGFILE="sftp-download"

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>"${FILEDST}${LOGFILE}-$(date +%F-%T).log" 2>&1


#Test for the existance of arguments
if [ $# -lt 2 ]; then
	echo "Not enough arguments supplied"
	echo "shell-script.sh [ENV[QE/QQ/HV]] [FILENAME]"
	exit 123
fi

FILESRC=$2
BACKUPSERV=false
RAND1=$((1 + $RANDOM % 10000))
if [ $1 = QQ ]; then
	POSTUSER=$(whoami)
	TUSER=TA06547
	connect_to_cyberark "AIM_DDD" "AIM_DDD_QA" "${POSTUSER^^}_LDPUGDUS_DDD"
	POSTPASS=${CPASS}
	unset CPASS
	connect_to_cyberark "AIM_DDD" "AIM_DDD_QA" "${TUSER^^}_RACF_MILANO_DDD"
	# the technical user QQ env
	TPASS=${CPASS}
	# the ftp servers addres QQ
	SFTP_HOST=IT7E.intranet.unicredit.it
	SFTP_HOST2=IT7E.intranet.unicredit.it
elif [ $1 = QE ]; then
	POSTUSER=$(whoami)
	TUSER=TA06546
	connect_to_cyberark "AIM_DDD" "AIM_DDD_DEV" "${POSTUSER^^}_LDPUGDUS_DDD"
	POSTPASS=${CPASS}
	unset CPASS
	connect_to_cyberark "AIM_DDD" "AIM_DDD_DEV" "${TUSER^^}_RACF_MILANO_DDD"
	# the technical user for PROD env
	TPASS=${CPASS}
	# the sftp servers addres for PROD
	SFTP_HOST=IT5A.intranet.unicredit.it
	SFTP_HOST2=IT5C.intranet.unicredit.it
elif [ $1 = HV ]; then
	POSTUSER=$(whoami)
	TUSER=TA06548
	connect_to_cyberark "AIM_DDD" "AIM_DDD" "${POSTUSER^^}_LDPUGDUS_DDD"
	POSTPASS=${CPASS}
	unset CPASS
	connect_to_cyberark "AIM_DDD" "AIM_DDD" "${TUSER^^}_RACF_MILANO_DDD"
	# the technical user for PROD env
	TPASS=${CPASS}
	# the sftp servers addres for PROD
	SFTP_HOST=IT7A.intranet.unicredit.it
	SFTP_HOST2=IT7B.intranet.unicredit.it
else
	echo "RETC = 124"
	echo "The environment is not valid"
	echo "it should be QQ QE or HV"
	exit 124
fi

#Test connection with remote server
lftp -c "open -e \"set ssl:verify-certificate no; \
	set sftp:auto-confirm yes;\"\
	-u "${TUSER}","${TPASS}" \
	${SFTP_HOST}; ls ${FILESRC}*"
RC=$?
if [ $RC -ne 0 ]; then
	echo "Error: connection to sftp server ${SFTP_HOST2} failed"
	echo "RETC = $RC"
	echo "trying to connect to ${SFTP_HOST2}"
	#Test connection with remote server
	lftp -c "open -e \"set ssl:verify-certificate no; \
		set sftp:auto-confirm yes;\"\
		-u "${TUSER}","${TPASS}" \
		${SFTP_HOST2}; ls ${FILESRC}*"
	RC=$?
	if [ $RC -ne 0 ]; then
		echo "Error: connection to backup sftp server failed"
		echo "RETC = $RC"
		exit $RC
	fi
	BACKUPSERV=true
fi

#copy the desired file using sftp protocol, user and password
if [ $BACKUPSERV = false ]; then
	lftp -c "open -e \"set ssl:verify-certificate no; \
		set sftp:auto-confirm yes;\"\
	        -u "${TUSER}","${TPASS}" \
	        ${SFTP_HOST};

	get ${FILESRC} -o ${FILEDST}; exit"
else
	lftp -c "open -e \"set ssl:verify-certificate no; \
		set sftp:auto-confirm yes;\"\
	        -u "${TUSER}","${TPASS}" \
	        ${SFTP_HOST2};

	get ${FILESRC} -o ${FILEDST}; exit"
fi

#Test for sftp connection success and throw error otherwisse
RC=$?
if [ $RC -ne 0 ]; then
	echo "RETC = ${RC}"
	echo "Error: file already present on NAS storage or no access to NAS mount"
	exit $RC
fi

#Determine the type of the files from it's name
readarray -d . -t strarr <<<"${FILESRC}"

FILETYPE=${strarr[4]}

#start FileNet processing
HTTPS_POST_RC=4
curl -u ${POSTUSER}:${POSTPASS} -X POST -F "file=${FILEDST}${FILESRC}" -F "type=${FILETYPE}" ${POSTURL}startJob

while [ ${HTTPS_POST_RC} = 4 ]
do
	HTTPS_POST_RC=curl -u ${POSTUSER}:${POSTPASS} -X POST -F "file=${FILEDST}${FILESRC}" -F "type=${FILETYPE}" -w "%{http_code}" ${POSTURL}checkJob
	sleep 5m
done

if [ $HTTPS_POST_RC -ne 0 ]; then
	echo "RETC = ${HTTPS_POST_RC}"
	echo "Error: the FileNet processing failed"
	exit $HTTPS_POST_RC
fi

find ${FILEDST}${LOGFILE}*.log -mtime +10 -type f -delete
