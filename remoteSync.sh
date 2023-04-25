#!/bin/bash
#
# v1.0
# update time: 2023/03/22
# yu.zhang
#

#
SCRIPT_FOLDER=/root/shell-script
FTP_SYNC_BASE=/data/disk-sdd1-2t
SERVER_LIST=/root/shell-script/remoteSync_server_list.txt

#
LOG_FOLDER_BASE=/root/shell-script/remoteSync-log
LOG_FOLDER_DETAIL=${LOG_FOLDER_BASE}/$(date +%Y)/$(date +%Y%m%d)
LOG_FILE_RUN_LOG=${LOG_FOLDER_BASE}/remoteSync-runlog-$(date +%Y%m%d).log
#
cd ${SCRIPT_FOLDER}

# -n 非零则为真 , -z 为零则为真
log(){
  if [[ -z $TYPE ]];then TYPE=info;fi
  echo -e "$(date +%Y-%m-%d" "%H:%M:%S) \t$TYPE: ${SERVER_NAME}, $CONTENT" |tee -a ${LOG_FILE_RUN_LOG}
}

FILE_SYNC(){
  unset IFS
  # Function Start......
  #
  LOG_FILE_COMMAND=${LOG_FOLDER_DETAIL}/remoteSyncCommand-${SERVER_NAME}.log
  LOG_FILE_DETAIL=${LOG_FOLDER_DETAIL}/remoteSync-${SERVER_NAME}.log

  #
  mkdir -p ${LOG_FOLDER_BASE}
  mkdir -p ${LOG_FOLDER_DETAIL}
  touch ${LOG_FILE_COMMAND}
  touch ${LOG_FILE_DETAIL}

  #
  SERVER_STATUS=$(ps -ef|grep "${DST_FOLDER}"|grep -v grep)

if [[ -n ${SERVER_STATUS} ]] ; then 
    # 同步进程存在未完成，新任务退出。
    echo 2>&1 |tee -a ${LOG_FILE_RUN_LOG}
    echo -e $(date +%F" "%T)"\tWARNING, Task EXIST. ---${SERVER_TYPE}://${SERVER_LINK}---, Task Status: ${SERVER_STATUS}" 2>&1 |tee -a ${LOG_FILE_RUN_LOG}
    exit

  else
    echo 
    echo -e $(date +%F" "%T)"\tSTART----${SERVER_TYPE}://${SERVER_LINK}----START" 2>&1 |tee -a ${LOG_FILE_RUN_LOG}

    # 更新文件夹，存在，记录原有更新时间，文件夹名
    UPDATE_FOLDER=$(ls -D1 ${DST_FOLDER}|grep "update_20"|head -n 1)
    LAST_UPDATE_TIME=$(echo ${UPDATE_FOLDER}|awk -F "_" '{print $2}'|sed 's/\]$//')
    if [[ -n ${LAST_UPDATE_TIME} ]];then
      echo -e $(date +%F" "%T)"\t${SERVER_NAME}, UPDATE_FOLDER: ${UPDATE_FOLDER}, LAST_UPDATE_TIME: $LAST_UPDATE_TIME" 2>&1 |tee -a ${LOG_FILE_RUN_LOG}
    else
      echo -e $(date +%F" "%T)"\tLAST_UPDATE_TIME NOT FOUND!!!" 2>&1 |tee -a ${LOG_FILE_RUN_LOG} 
    fi

    # 准备开始运行lftp镜像 创建同步时间文件夹updating...
    cd ${DST_FOLDER}
    UPDATEING_FOLDER="[update_$(date +%Y%m%d-%H%M%S)_updating...]"
    if [[ $(pwd)==${DST_FOLDER} ]];then
      ## ---debug info ---- ##
      echo -e $(date +%F" "%T)"\t${SERVER_NAME}, if pwd = DSE_FOLDER then: UPDATE_FOLDER: ${UPDATE_FOLDER}, Curren Folder: $(pwd), DST_FOLDER: ${DST_FOLDER}" 2>&1 | tee -a ${LOG_FILE_RUN_LOG}
      ## ---debug info ---- ##
      for FOLDERS in $(ls -D1|grep "update_20")
        do
           echo -e $(date +%F" "%T)"\t${SERVER_NAME}, Remove ALL update folder: rm -rf: ${FOLDERS}, CURRENT DIR: ${DST_FOLDER}" 2>&1 | tee -a ${LOG_FILE_RUN_LOG}
           rm -rf ${FOLDERS} 2>&1 | tee -a ${LOG_FILE_RUN_LOG}
      done

      echo -e $(date +%F" "%T)"\t${SERVER_NAME}, Start mkdir -p ${UPDATEING_FOLDER}" 2>&1 | tee -a ${LOG_FILE_RUN_LOG}

      COMMAND_LOG=$(mkdir -pv ${UPDATEING_FOLDER})
      echo -e $(date +%F" "%T)"\t${SERVER_NAME}, CREAT UPDATE FOLDER DONE, MSG: ${COMMAND_LOG}" 2>&1 | tee -a ${LOG_FILE_RUN_LOG}

      COMMAND_LOG=$(ls -D1 ${DST_FOLDER}|grep update_20)
      echo -e $(date +%F" "%T)"\t${SERVER_NAME}, Updating NOW... UPDATE Folder: ${UPDATEING_FOLDER}, Command MSG: ${COMMAND_LOG}" 2>&1 | tee -a ${LOG_FILE_RUN_LOG}      
    fi

    echo -e $(date +%F" "%T)"\t${SERVER_NAME}, \rSERVER_TYPE: ${SERVER_TYPE} \r SERVER_LINK: ${SERVER_LINK} \r DST_FOLDER: ${DST_FOLDER} \n EXCLUDE: $EXCLUDE" | tee -a ${LOG_FILE_RUN_LOG}

    if [[ ${SERVER_TYPE} = rsync ]];then 
      # start rsync 
      echo -e $(date +%F" "%T)"\t${SERVER_NAME}, --------------------start rsync---------------------------" |tee -a ${LOG_FILE_DETAIL}
      echo "rsync -avzP --bwlimit=10240 --timeout=120 --contimeout=120 $EXCLUDE ${SERVER_TYPE}://${SERVER_LINK}/ ${DST_FOLDER}" 2>&1 |tee -a ${LOG_FILE_RUN_LOG}
      rsync -avzP --delete --bwlimit=10240 --timeout=120 --contimeout=120 $EXCLUDE ${SERVER_TYPE}://${SERVER_LINK}/ ${DST_FOLDER} 2>&1 >> ${LOG_FILE_DETAIL}
      exit_code=$(echo $?)
      echo -e $(date +%F" "%T)"\t${SERVER_NAME}, TASK DONE, lftp EXIT CODE: $exit_code, "'$$': $$, '$!': $!, '$_': $! | tee -a ${LOG_FILE_RUN_LOG}
    else 
      # start lftp mirror
      # lftp 连接ftp 服务器，最后要有 "/" ！！
      echo -e $(date +%F" "%T)"\t${SERVER_NAME}, --------------------start lftp---------------------------" |tee -a ${LOG_FILE_DETAIL}
      echo "lftp -e ${EXTRA}mirror -c -e -P=5 $EXCLUDE -vvv --verbose --log=${LOG_FILE_COMMAND} ${SERVER_TYPE}://${SERVER_LINK}/ ${DST_FOLDER};quit" 2>&1 | tee -a ${LOG_FILE_RUN_LOG}
      lftp -e "${EXTRA}mirror -c -e -P=5 $EXCLUDE -vvv --verbose --log=${LOG_FILE_COMMAND} ${SERVER_TYPE}://${SERVER_LINK}/ ${DST_FOLDER};quit" 2>&1 >> ${LOG_FILE_DETAIL}
      # echo lftp -e "${EXTRA}mirror -c -e $EXCLUDE --verbose -vvv --log ${LOG_FILE_COMMAND} ${SERVER_TYPE}://${SERVER_LINK} ${DST_FOLDER}"
      exit_code=$(echo $?)
      echo -e $(date +%F" "%T)"\t${SERVER_NAME}, TASK DONE, lftp EXIT CODE: $exit_code, "'$$': $$, '$!': $!, '$_': $! | tee -a ${LOG_FILE_RUN_LOG}
    fi

    if [[ $exit_code != 0 ]];then

      #exit code != 0
      cd ${DST_FOLDER}
      UPDATE_FOLDER="[update_$(date +%Y%m%d-%H%M%S)_abnormal]"

      COMMAND_LOG=$(mkdir -pv ${UPDATE_FOLDER} 2>&1)
      echo -e $(date +%F" "%T)"\t${SERVER_NAME}, CREAT UPDATE FOLDER, MSG: ${COMMAND_LOG}" 2>&1 | tee -a ${LOG_FILE_RUN_LOG}

      COMMAND_LOG=$(ls -D1 ${DST_FOLDER}|grep update_20)
      echo -e $(date +%F" "%T)"\t${SERVER_NAME}, lftp进程非正常的退出。EXIT CODE: $exit_code, UPDATE FOLDER: ${COMMAND_LOG}" 2>&1 | tee -a ${LOG_FILE_RUN_LOG}

    else

      # exit code = 0
      # log
      TYPE=INFO
      CONTENT=$(echo "Update Task DONE. Server: ${SERVER_LINK}, ${SERVER_TYPE}. Exit_Code: ${exit_code}. Detail log file: ${LOG_FILE_DETAIL}")
      log $TYPE,$CONTENT

      # update date
      cd ${DST_FOLDER}
      UPDATE_FOLDER="[update_$(date +%Y%m%d-%H%M%S)]"
      if [[ $(pwd) = ${DST_FOLDER} ]];then

        ## ---debug info ---- ##
        echo -e $(date +%F" "%T)"\t${SERVER_NAME}, if pwd = DSE_FOLDER then: UPDATE_FOLDER: ${UPDATE_FOLDER}, Curren Folder: $(pwd), DST_FOLDER: ${DST_FOLDER}" 2>&1 | tee -a ${LOG_FILE_RUN_LOG}
        ## ---debug info ---- ##

        # 删除更新标志文件夹
        for FOLDERS in $(ls -D1|grep "update_20")
          do
            echo -e $(date +%F" "%T)"\t${SERVER_NAME}, REMOVE OLD UPDATE_FOLDER: rm -rf ${FOLDERS}, Curren Folder: $(pwd)" 2>&1 | tee -a ${LOG_FILE_RUN_LOG}
            rm -rf ${FOLDERS} 2>&1 | tee -a ${LOG_FILE_RUN_LOG}
        done

        # 创建完成文件夹
        echo -e $(date +%F" "%T)"\t${SERVER_NAME}, CREAT NEW UPDATE_FOLDER: mkdir -p ${UPDATE_FOLDER}" 2>&1 | tee -a ${LOG_FILE_RUN_LOG}
        mkdir -pv ${UPDATE_FOLDER} 2>&1 | tee -a ${LOG_FILE_RUN_LOG}
        ls -D1 ${DST_FOLDER}|grep update_20 2>&1 | tee -a ${LOG_FILE_RUN_LOG}
      else  
        echo -e $(date +%F" "%T)"\t!!! ATTENTION !! --pwd-error--!!! Curren Folder: $(pwd), DST_FOLDER: ${DST_FOLDER}" 2>&1 | tee -a ${LLOG_FILE_RUN_LOG}
        UPDATE_TIME=$(ls -D1 ${DST_FOLDER}|grep "update_20"|awk -F "_" '{print $2}'|sed 's/\]$//')
      fi

    fi
  fi
}

###########################################
IFS=","
cat ${SERVER_LIST} | grep -v "#"|while read SERVER_NAME SERVER_TYPE SERVER_LINK DST_FOLDER EXCLUDE EXTRA
  do 
    echo ===debug info start====
    echo SERVER_NAME: "$SERVER_NAME"
    echo SERVER_TYPE: "$SERVER_TYPE"
    echo SERVER_LINK: "$SERVER_LINK"
    echo DST_FOLDER: "$DST_FOLDER"
    echo EXCLUDE: "$EXCLUDE"
    echo EXTRA: "${EXTRA}"
    echo FILE_SYNC "${SERVER_NAME} " "${SERVER_TYPE}" "${SERVER_LINK}" "${DST_FOLDER}" "${EXCLUDE}" "${EXTRA}"
    FILE_SYNC "${SERVER_NAME} " "${SERVER_TYPE}" "${SERVER_LINK}" "${DST_FOLDER}" "${EXCLUDE}" "${EXTRA}" &
    echo -e $(date +%F" "%T)"\t${SERVER_NAME}, TASK DONE, lftp EXIT CODE: $exit_code, "'$$': $$, '$!': $!, '$_': $! | tee -a ${LOG_FILE_RUN_LOG}
    echo ===debug info end====
    echo -e "\r\r"
  done
#
