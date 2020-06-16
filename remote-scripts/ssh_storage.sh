#！/bin/bash

#######################################################################################
## Description:
##   This script to execute 'kdumpctl propagate' 
#######################################################################################
## Revision:
## v1.0 - xinhu - 12/02/2019 - Draft script for case kdump_3_types_storage.
#######################################################################################

dos2unix utils.sh

# Source utils.sh
. utils.sh || {
    echo "Error: unable to source utils.sh!"
    exit 1
}

# Source constants file and initialize most common variables
UtilsInit

#######################################################################################
## Main Body
#######################################################################################
/usr/bin/expect <<-EOF
set time 30
spawn kdumpctl propagate
expect {
    "*yes/no*" {send "yes\r"; exp_continue }
    "*password:" {send "redhat\r" }
}
expect eof
EOF