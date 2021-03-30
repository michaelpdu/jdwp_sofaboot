#!/usr/bin/env bash

function set_up(){
    echo "hello"
}

function move_static_resources()
{
    # priority : META/resources > resources > static > public

    # BOOT-INF/classes
    static_resources=$1
    # tgz unzip dir
    target_dir=$2
    if [ -d $1/META/resources ]; then
        mv $1/META/resources $2/META/resources
        return
    elif [ -d $1/resources ]; then
        mv $1/resources $2/resources
        return
    elif [ -d $1/static ]; then
        mv $1/static $2/static
        return
    elif [ -d $1/public ]; then
        mv $1/public $2/public
        return
    else
        echo "No Static Resources"
        return
    fi
}

prepare_env()
{
    echo -e "\n### preparing environment";

    # load deploy vars
    dbmode=`load_deploy_var dbmode`
    zone=`load_deploy_var zone`
    zmode=`load_deploy_var zmode`
    confreg_url=`load_deploy_var confregurl`
    echo "dbmode=$dbmode"
    echo "zone=$zone"
    echo "zmode=$zmode"
    echo "confreg_url=$confreg_url"

    echo "### preparing environment ended";
}

function kill_sofa_boot_process() {
    # ignore xflush and timetunnel.User can self define the process ignored 用户需要自定义要忽略的进程
    local bootpids=`ps aux|grep java|grep admin| grep -v xflush | grep -v timetunnel | grep -v "com.alipay.linka.coverage.client.Launcher" | grep -v grep |awk '{print $2;}'`
    local boot_pid_array=($bootpids)
    echo -e "\\nkilling SOFABoot processes:${boot_pid_array[@]}"
    for bootpid in ${boot_pid_array[@]}
    do
        if [ -z "$bootpid" ]; then
            continue;
        fi
        echo "kill $bootpid"
	    kill $bootpid
	    /bin/sleep 3
	    killed_pid=$(ps aux | grep java | awk '{print $2;}' | grep $bootpid)

	    if [[ "$killed_pid" == "$bootpid" ]]; then
	    echo "Kill $bootpid don't work and kill -9 $bootpid used violently!"
        kill -9 $bootpid
	    fi
    done
}

function replace_conf_use_active_properties() {
  local REAL_SPRING_PROFILES_ACTIVE=$1
  local SOURCE_CONFIG_DIR=$2
  local TARGET_CONF=$3
  local env=`echo ${REAL_SPRING_PROFILES_ACTIVE} | cut -d, -f1`
  if [ -f ${SOURCE_CONFIG_DIR}/application-${env}.properties ]; then
    local ACTIVE_SOURCE_FILE=${SOURCE_CONFIG_DIR}/application-${env}.properties
  fi
  echo "REPLACE_ACTIVE_SORUCE_FILE = $ACTIVE_SOURCE_FILE"

  local COMMON_SOURCE_FILE=${SOURCE_CONFIG_DIR}/application.properties
  local SOURCE_FILE_ARRAY=(${ACTIVE_SOURCE_FILE} ${COMMON_SOURCE_FILE})

  for SOURCE_FILE in ${SOURCE_FILE_ARRAY[@]}
  do
      if [ -f ${SOURCE_FILE} ]; then
        while read line || [[ -n ${line} ]]
        do
            real_line=`echo "$line" | sed 's| ||g'`
            if [ -z "$real_line" ]; then
                continue
            fi

            local key=`echo $real_line | cut -d= -f1`
            local value=`echo $real_line | cut -d= -f2-`

            local token="\${"${key}"}"
            LANG=C LANG_ALL=C sed -i "s|$token|$value|g" $TARGET_CONF
        done < $SOURCE_FILE
      fi
  done
}


#  获取执行路径 : 如果脚本是一个文件的链接
if [[ -L $0 ]]; then
    BIN_DIR=$(dirname $(readlink $0))
else
    BIN_DIR=$(dirname $(readlink -f $0))
fi

echo "BIN_DIR=$BIN_DIR"
# 启动工具脚本
source $BIN_DIR/util.sh

#约定的 fat jar 执行目录
BOOT_DIR=$BIN_DIR/../boot
echo "BOOT_DIR=$BOOT_DIR"

#配置目录
CONFIG_DIR=$BIN_DIR/../config
echo "CONFIG_DIR=$CONFIG_DIR"

#校验配置目录下的配置文件
if [ ! -f "${CONFIG_DIR}/application.properties" ] && [ ! -f "${CONFIG_DIR}/application.yaml" ] && [ ! -f "${CONFIG_DIR}/application.yml" ]; then
  echo "application.properties/yaml/yml file in ${CONFIG_DIR} not exist, exit"
  exit 1
fi

#几个全局参数
if [ -z "$JAVA_HOME" ]; then
  echo "JAVA_HOME not set, exit"
  exit 1
fi

if [ -z "$APP_HOME" ]; then
  APP_HOME=/home/admin
fi

echo "JAVA_HOME=${JAVA_HOME}"
echo "APP_HOME=${APP_HOME}"
#echo "APP_RUN=${APP_RUN}"

# setup directories
mkdir -p $APP_HOME/temp
mkdir -p ${APP_HOME}/temp/nginx/proxy_temp
mkdir -p ${APP_HOME}/temp/nginx/client_body_temp
LOG_ROOT=$APP_HOME/logs
mkdir -p $LOG_ROOT
mkdir -p ${LOG_ROOT}/nginx

# hook before kill
run_hook before_appkill_hook ${BIN_DIR}
# kill process
kill_sofa_boot_process
# hook after kill
run_hook after_appkill_hook ${BIN_DIR}


#进入 fat jar 目录
cd $BOOT_DIR

#取出所有的 fat jar,但只执行第一个
fat_jar_files=(`ls *.jar`)

# spring-boot path middle default value
BOOT_INF_CLASSES_DIR=BOOT-INF/classes

if [ -n "$fat_jar_files" ]; then
    echo "All fat jar files are $fat_jar_files"
    # found more,only use first fat jar
    JAR_FILE=${fat_jar_files[0]}
    JAR_FILE_NAME=`basename ${JAR_FILE}`

    JAR_FILE=${BOOT_DIR}/${JAR_FILE}
    echo "Deployed fat jar file is $JAR_FILE"
    # unzip fat jar
    UNZIP_FAT_JAR_PATH=${BOOT_DIR}/${JAR_FILE_NAME%.jar}
    # unzip source file to workdir
    unzip -q ${JAR_FILE} -d $UNZIP_FAT_JAR_PATH
    # echo
    echo "Unzipped Jar Directory=${UNZIP_FAT_JAR_PATH}"
    # move static resources to $BOOT_DIR/../
    # static resources
    move_static_resources ${UNZIP_FAT_JAR_PATH}/${BOOT_INF_CLASSES_DIR} ${BIN_DIR}/../

    # 替换配置文件中的 @@ 变量
    sed_cmd=$(cat ~/server.conf | \
    awk -F= '/domainname/ {v=$2}; {print $1, $2}; END {print "inner.domain " v}' | \
    awk '{print "s/@" $1 "@/" $2 "/g " }'| tr '\n' ';')
    if [ -f "${CONFIG_DIR}/application.properties" ]; then
      echo "replace @@ params for ${CONFIG_DIR}/*.properties files"
      sed -i "$sed_cmd" ${CONFIG_DIR}/*.properties
    fi
    if [ -f "${CONFIG_DIR}/application.yaml" ]; then
      echo "replace @@ params for ${CONFIG_DIR}/*.yaml files"
      sed -i "$sed_cmd" ${CONFIG_DIR}/*.yaml
    fi
    if [ -f "${CONFIG_DIR}/application.yml" ]; then
      echo "replace @@ params for ${CONFIG_DIR}/*.yml files"
      sed -i "$sed_cmd" ${CONFIG_DIR}/*.yml
    fi

    # set -Dspring.profiles.active param
    typeset -l SPRING_PROFILES_ACTIVE
    SPRING_PROFILES_ACTIVE=""
    if [[ -n $ALIPAY_APP_ENV ]]; then
        SPRING_PROFILES_ACTIVE=$ALIPAY_APP_ENV
    elif [[ -n $SERVER_ENV ]]; then
        SPRING_PROFILES_ACTIVE=$SERVER_ENV
    else
        echo "ALIPAY_APP_ENV or SERVER_ENV not set, exit"
        exit 1
    fi
    if [[ "$SPRING_PROFILES_ACTIVE" == "stable" ]]; then
        SPRING_PROFILES_ACTIVE="dev"
    fi
    if [[ "$SPRING_PROFILES_ACTIVE" == "prepub" ]] || [[ "$SPRING_PROFILES_ACTIVE" == "gray" ]]; then
        SPRING_PROFILES_ACTIVE="prod"
    fi
    echo "spring.profiles.active: $SPRING_PROFILES_ACTIVE"

    # 获取配置中心地址
    prepare_env
    # get java opts
    # PE export JAVA_OPTS 系统环境
    if [ -z $JAVA_OPTS ]; then
        echo "JAVA_OPTS not configured or exported in machine";
        get_java_opts $CONFIG_DIR
        echo "JAVA_OPTS read from java_opts file in tgz file are $JAVA_OPTS"
    else
        echo "JAVA_OPTS exported in machine are $JAVA_OPTS"
    fi

    if [ -n "$APP_INSTANCE_GROUP_NAME" ]; then
        additional_location="${CONFIG_DIR}/,${CONFIG_DIR}/../service-group/${APP_INSTANCE_GROUP_NAME}.properties"
        echo "Support AIG properties, group is ${APP_INSTANCE_GROUP_NAME}";
    else
        additional_location="${CONFIG_DIR}/"
    fi

    # 启动的系统参数 外置化配置文件 配置profiles
    SYS_PROPS="$JAVA_OPTS $SYS_PROPS -Ddbmode=$dbmode -Dzmode=$zmode -Dcom.alipay.ldc.zone=$zone -Dcom.alipay.confreg.url=$confreg_url -Dspring.config.additional-location=$additional_location -Dspring.profiles.active=$SPRING_PROFILES_ACTIVE"

    # echo java opts
    echo "Running SYS_PROPS : $SYS_PROPS"
    # run before hook
    run_hook before_appstart_hook ${BIN_DIR}
    # stdout stderr.log 处理
    FILE_STDOUT_LOG=$LOG_ROOT/stdout.log
    FILE_STDERR_LOG=$LOG_ROOT/stderr.log

    NOW=`date +%Y%m%d.%H%M%S`
    # scroll SOFA Boot STDOUT log
    if [ -e $FILE_STDOUT_LOG ] ; then
        mv $FILE_STDOUT_LOG $FILE_STDOUT_LOG.$NOW
    fi

    # scroll SOFA Boot STDERR log
    if [ -e $FILE_STDERR_LOG ] ; then
        mv $FILE_STDERR_LOG $FILE_STDERR_LOG.$NOW
    fi
    # run 外化配置文件
    ${JAVA_HOME}/bin/java $SYS_PROPS -jar ${JAR_FILE} >> $FILE_STDOUT_LOG 2>> $FILE_STDERR_LOG &
    # run after hook
    run_hook after_appstart_hook ${BIN_DIR}
    echo "deploy jar success, stdout:${FILE_STDOUT_LOG}, stderr:${FILE_STDERR_LOG}"
    #tnginx 启动
    # start nginx, if conf exist
    if [ -f "$CONFIG_DIR/tenginx-conf/t-alipay-tengine.conf" ]; then
        kill_nginxPro
        echo "NGINX_CONF: $CONFIG_DIR/tenginx-conf/t-alipay-tengine.conf";
        replace_conf_use_active_properties $SPRING_PROFILES_ACTIVE $CONFIG_DIR $CONFIG_DIR/tenginx-conf/t-alipay-tengine.conf
        sed -i "$sed_cmd" $CONFIG_DIR/tenginx-conf/t-alipay-tengine.conf
        bash $BIN_DIR/nginx.sh $CONFIG_DIR/tenginx-conf/t-alipay-tengine.conf;
    fi

else
    echo "No fat jar found under $BOOT_DIR, deploy failed!";
    exit 1;
fi


