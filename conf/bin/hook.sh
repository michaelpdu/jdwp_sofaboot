#!/bin/bash

function before_appstart_hook {
#    do something other for example call other script
    dir_name=`dirname $0`
    echo "hook.sh dirname=${dir_name}"
    echo 'In before_appstart_hook sofa boot before_appstart_hook executed'
}

function after_appstart_hook {
    dir_name=`dirname $0`
    echo "hook.sh dirname=${dir_name}"
    echo 'sofa-lite2 after_appstart_hook executed'
}

function before_appkill_hook {
#    do something other for example call other script
    dir_name=`dirname $0`
    echo "hook.sh dirname=${dir_name}"
    echo 'In before_appkill_hook sofa boot before_appkill_hook executed'
}

function after_appkill_hook {
    dir_name=`dirname $0`
    echo "hook.sh dirname=${dir_name}"
    echo 'sofa-lite2 after_appkill_hook executed'
}
