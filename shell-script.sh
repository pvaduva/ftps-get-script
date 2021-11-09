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
	FILEDST="/opt/FileNet/shared/Host/"
elif [ $1 = QE ]; then
	POSTURL="https://ddd-cpe-qe.collaudo.usinet.it/DDMEGABatch/"
	FILEDST="/opt/FileNet/shared/Host/"
elif [ $1 = HV ]; then
	POSTURL="https://ddd-cpe-hv.intranet.unicredit.eu/DDMEGABatch/"
	FILEDST="/opt/FileNet/shared/Host/"
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
	POSTUSER=ta06547
	connect_to_cyberark "AIM_DDD" "AIM_DDD_QA" "${POSTUSER^^}_RACF_MILANO_DDD"
	POSTPASS=${CPASS}
	unset CPASS
	# the ftp servers addres QQ
	SFTP_HOST=IT7E.intranet.unicredit.it
	SFTP_HOST2=IT7E.intranet.unicredit.it
elif [ $1 = QE ]; then
	POSTUSER=ta06546
	connect_to_cyberark "AIM_DDD" "AIM_DDD_DEV" "${POSTUSER^^}_RACF_MILANO_DDD"
	POSTPASS=${CPASS}
	unset CPASS
	# the sftp servers addres for PROD
	SFTP_HOST=IT5A.intranet.unicredit.it
	SFTP_HOST2=IT5C.intranet.unicredit.it
elif [ $1 = HV ]; then
	POSTUSER=ta06548
	connect_to_cyberark "AIM_DDD" "AIM_DDD" "${POSTUSER^^}_RACF_MILANO_DDD"
	POSTPASS=${CPASS}
	unset CPASS
	SFTP_HOST=IT7A.intranet.unicredit.it
	SFTP_HOST2=IT7B.intranet.unicredit.it
else
	echo "RETC = 124"
	echo "The environment is not valid"
	echo "it should be QQ QE or HV"
	exit 124
fi

export SSHPASS=${TPASS}

#Test connection with remote server
#lftp -c "open -e \"set ssl:verify-certificate no; \
#	set net:max-retries 3; \
#	set sftp:auto-confirm yes;\"\
#	-u "${TUSER}","${TPASS}" \
#	${SFTP_HOST}; ls ${FILESRC}*"

sftp -oConnectTimeout=10 ${POSTUSER}@${SFTP_HOST} << !
ls 
!

RC=$?
if [ $RC -ne 0 ]; then
	echo "Error: connection to sftp server ${SFTP_HOST} failed"
	echo "RETC = $RC"
	echo "trying to connect to ${SFTP_HOST2}"
	#Test connection with remote server
sftp -oConnectTimeout=10 ${POSTUSER}@${SFTP_HOST2} << !
ls 
!
#	lftp -c "open -e \"set ssl:verify-certificate no; \
#		set net:max-retries 3; \
#		set sftp:auto-confirm yes;\"\
#		-u "${TUSER}","${TPASS}" \
#		${SFTP_HOST2}; ls ${FILESRC}*"
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
	SFTP_H=${SFTP_HOST}
else
	SFTP_H=${SFTP_HOST2}
fi

rm ${HOME}/${FILESRC}

#lftp -c "open -e \"set ssl:verify-certificate no; \
#	set net:max-retries 3; \
#	set sftp:auto-confirm yes;\"\
#        -u "${TUSER}","${TPASS}" \
#        ${SFTP_H};
#
#get ${FILESRC} -o ${HOME}/; exit"

sftp -oConnectTimeout=10 ${POSTUSER}@${SFTP_H} << !
get ${FILESRC}
!

#Test for sftp connection success and throw error otherwisse
RC=$?
if [ $RC -ne 0 ]; then
	echo "RETC = ${RC}"
	echo "Error: download failed"
	exit ${RC}
fi

#while [ $RC -ne 0 ]
#do
#   command1
#   command2
#   command3
#done

cp ${HOME}/${FILESRC} ${FILEDST}/

#delete this
#Determine the type of the files from it's name
#readarray -d . -t strarr <<<"${FILESRC}"

IFS='.' read -ra strarr <<< "${FILESRC}"

echo ${strarr[4]}

FILETYPE="${strarr[4]}"

# if [ ${FILESRC} = "File_DelMrgNdg.txt" ]; then
# FILETYPE="DELMRNDG"
# elif [ ${FILESRC} = "File_UpRelNdg.txt" ]; then
# FILETYPE="UPRELNDG"
# elif [ ${FILESRC} = "File_Retent.txt" ]; then
# FILETYPE="RETENT"
# elif [ ${FILESRC} = "File_NdgUpdate.txt" ]; then
# FILETYPE="UPDTNDG"
# else
# 	echo "Error: File type not supported"
# 	echo "RC = 122"
# 	exit 122
# fi

#start FileNet processing
HTTPS_POST_RC=4
UUID_CODE=$(curl -k -u ${POSTUSER}:${POSTPASS} -X POST -F "file=${FILEDST}${FILESRC}" -F "type=${FILETYPE}" ${POSTURL}startJob)

RC=$?

if [ $RC -ne 0 ]; then
        echo "RETC = $RC"
        echo "Error: the FileNet processing job failed to start"
        exit $RC
fi

echo "uuid=${UUID_CODE}"

while [ ${HTTPS_POST_RC} = 4 ]
do
#	HTTPS_POST_RC=curl -u ${POSTUSER}:${POSTPASS} -X POST -F "file=${FILEDST}${FILESRC}" -F "type=${FILETYPE}" -w "%{http_code}" ${POSTURL}checkJob
HTTPS_POST_RC=$(curl -k -u ${POSTUSER}:${POSTPASS} ${POSTURL}checkJob?id=${UUID_CODE})

echo "while RC =  ${HTTPS_POST_RC}"
	sleep 1m
done

if [ $HTTPS_POST_RC -ne 0 ]; then
	echo "RETC = ${HTTPS_POST_RC}"
	echo "Error: the FileNet processing failed"
	exit $HTTPS_POST_RC
fi

# Once everything is ok then delete the file from Host
sftp -oConnectTimeout=10 ${POSTUSER}@${SFTP_H} << !
rm ${FILESRC}
!

find ${FILEDST}${LOGFILE}*.log -mtime +10 -type f -delete
