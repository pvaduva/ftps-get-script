#!/bin/bash

curl -o 'shell-script.sh' https://github.com/pvaduva/ftps-get-script/blob/test/shell-script.sh && chmod u+x shell-script.sh
bash +x shell-script.sh 'QE' 'testfile'
cat sftp-download*
