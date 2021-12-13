#!/bin/bash 

FILEDST="/opt/FileNet/shared/host/"
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3

exec 1>"${FILEDST}hello-world.log" 2>&1

echo "Hello, world!"

echo "I am $(whoami)"
echo "I am running in the path $(pwd)"
echo "The contents of the working folder is:"
echo "$(ls -l)"
