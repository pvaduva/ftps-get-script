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
	
	export SSHPASS=$(echo $OUT | awk -F"," '{print $1}')
fi

#parameters to be edited for local environment
USER=TA06546
SFTP_HOST=IT7E.intranet.unicredit.it
FILESRC=/userfile
FILEDST=userfolder/userfile

#if file exists the file_exists variable will be 1 in other case it will be 0
file_exists=$(ls ${FILEDST} 2>/dev/null | wc -l)

#throw error and exit if the file already exists
if [ $file_exists -eq 1 ]; then 
	echo "Error: File already exists!"
	exit 125
fi

#copy the desired file using sftp protocol, user and password
sshpass -e sftp ${USER}@${SFTP_HOST}:${FILESRC} ${FILEDST}

#Test for file transfer success and throw error otherwisse
RC = $?
if [ $RC -ne 0]; then
	echo "Error: sftp file transfer failed"
	exit $RC
fi
