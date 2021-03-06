From IBM Developers
#!/bin/sh 

 # ----------------------------------------------------------------- 
 # Function definitions...  	                          定义函数
 #---------------------------------------------------------------- 
			
 function usage { 
    echo ""
    echo "usage: IOAnalyzer.sh -i inIostatFile [ -l outLogFile ] \ 
 [ -a outAlertFile ] [ -u dishUtil ] [ -r rateGEUtil ]"
    echo ""
    echo "For example: IOAnalyzer.sh -i /tmp/iostat.out -l /tmp/logFile \ 
 -a /tmp/aletFile -u 80 -r 70"
    echo "For AIX, please run 'iostat -d [ <interval> [ <count> ] \ 
 to create inIostatFile"
    echo "For Linux, please run 'iostat -d -x [ <interval> [ <count> ] \ 
 to create inIostatFile"
    exit 1 
 } 

 # ---------------------------------------------------------------- 
 # Process command-line arguments 					     命令行参数处理
 # ---------------------------------------------------------------- 
 while getopts :i:l:a:u:r: opt 
 do 
    case "$opt" in 
    i) inIostatFile="$OPTARG";; 
    l) outLogFile="$OPTARG";; 
    a) outAlertFile="$OPTARG";; 
    u) diskUtil="$OPTARG";; 
    r) rateGEUtil="$OPTARG";; 
    \?) usage;; 
    esac 
 done 

 #---------------------------------------------------------------- 
 # Input validation 					                  输入验证
 #---------------------------------------------------------------- 

 if [ ! -f "$inIostatFile" ] 
 then 
        echo "error: invalid Augument inIostatFile in OPTION -i "
        usage 
        exit 1 
 fi 
 #--------------------------------------------------------------- 
			
 # Set values, if unset                                   设置变量
 # ---------------------------------------------------------------- 

 outLogFile=${outLogFile:-${inIostatFile}.log} 
 outAlertFile=${outAlertFile:-${inIostatFile}.alert} 
 diskUtil=${diskUtil:-'80'} 
 rateGEUtil=${rateGEUtil:-'60'}
#接下来， IOAnalyzer.sh 脚本查询日志，通过计算起止行的办法定位 IO 输出文件的待分析文本。
#清单 7. IOAnalyzer.sh 脚本定位 I/O 输出文件待分析部分
 # ---------------------------------------------------------------- 
 # Identify the lines to be analyzed between StartLine and Endline 
 # 定位日志中待分析文本
			
 # ---------------------------------------------------------------- 

 if [ ! -f "$outLogFile" ] || [ ! tail -1 "$outLogFile"|grep 'ENDLINE'] 
 then 
        StartLineNum=1; 
 else 
        CompletedLine=`tail -1 "$outLogFile" | grep 'ENDLINE' | awk '{print $4}'|cut -d: -f2` 
        StartLineNum=`expr 1 + $CompletedLine` 
 fi 

 eval "sed -n '${StartLineNum},\$p' $inIostatFile" > ${inIostatFile}.tail #从第StartLineNum行到，$p(最后一行)。-n表示关闭sed的默认打印一遍文件内容的模式~~

 LineCount=`cat ${inIostatFile}.tail|wc -l|awk '{print $1}'` 
 EndLineNum=`expr $LineCount + $StartLineNum`
#清单 7 中的脚本实现了按行分析上文定位的 iostat 输出，如果某行磁盘利用率小于先前定义的门限值，则在行尾标记“OK”，
#如果某行磁盘利用率大于等于先前定义的门限值，则在行尾标记“Alarm”。并且脚本中对于 AIX 和 Linux 输出格式和磁盘命名的不同作了相应处理。
#清单 8. IOAnalyzer.sh 按行分析 iostat 输出
 # ---------------------------------------------------------------- 
 # Analyze 'iostat' output, append "Alarm" or "OK" at the end of each# line 
			
 # ---------------------------------------------------------------- 
 OS=`uname` 
 case "$OS" in 
 AIX) 
        diskUtilLabel="% tm_act"
        diskUtilCol=2 
        diskPrefix="hdisk"
        ;; 
 Linux) 
        diskUtilLabel="%util"
        diskUtilCol=14 
        diskPrefix="hd|sd"
        ;; 
 *)     echo "not support $OS operating system!"
        exit 1; 
        ;; 
 esac 

 eval "cat ${inIostatFile}.tail | egrep '${diskPrefix}' | awk '{if ( \$${diskUtilCol} * 100 < ${diskUtil} ) \ 
 {\$20 = \"OK\"; print \$1\"\t\"\$${diskUtilCol}\"\t\"\$20 } else {\$20 = \"Alarm\"; print \$1\"\t\"\$${diskUtilCol}\"\t\"\$20 } }'"  > ${outLogFile}.tmp
#下文脚本给出一个告警触发的例子，如果过高的磁盘利用率计数占总分析行数的比率达到或超出预定的比率，脚本会给 root 用户发一封告警邮件。
#清单 9. IOAnalyzer.sh 触发告警
 # ---------------------------------------------------------------- 
 # Send admin an alert if disk utilization counter reach defined 
 # threshold 
			
 # ---------------------------------------------------------------- 
 Alert="NO"
 for DISK in `cut -f1  ${outLogFile}.tmp | sort -u` 
 do 
        numAlarm=`cat ${outLogFile}.tmp | grep "^$DISK.*Alarm$" |wc -l` 
        numRecord=`cat ${outLogFile}.tmp | grep "^$DISK" |wc -l` 
        rateAlarm=`expr $numAlarm \* 100 / $numRecord` 
        if [ $rateAlarm -ge $rateGEUtil ];then 
                echo "DISK:${DISK}      TIME:`date +%Y%m%d%H%M`   RATE:${rateAlarm}      THRESHOLD:${rateGEUtil}" >> ${outAlertFile}.tmp 
                Alert="YES"
        fi 
 done 
 if [ $Alert= "YES" ];then 
			 cat ${outAlertFile}.tmp >> ${outAlertFile} 
        mail -s "DISK IO Alert"  root@localhost< ${outAlertFile}.tmp 
 fi
#最后，脚本将分析活动归档，便于下次分析时定位起始行；另外，分析过程中产生的文件将被删除。
#清单 10. IOAnalyzer.sh 记录分析活动日志和清除临时文件
 #---------------------------------------------------------------- 
 # Clearup temporary files and logging 
 # ---------------------------------------------------------------- 

 echo "IOSTATFILE:${inIostatFile}        TIME:`date +%Y%m%d%H%M`  \ 
 STARTLINE:${StartLineNum}       ENDLINE:${EndLineNum}   ALERT:${Alert}" \ 
			
 >> ${outLogFile} 

 #rm -f ${outLogFile}.tmp 
 #rm -f ${outAlertFile}.tmp 
 #rm -f ${inIostatFile}.tail 

 exit 0



IOAnalyzer脚本用例
#脚本使用示例
#以下为 IOAnalyzer.sh 脚本在 AIX 上使用示例
#1 ．后台执行 iostat, 并将输出重定向到文件中
#清单 11. 后台执行 iostat
# nohup iostat -d 5 > /root/iostat.out &  
#（对于 Linux，运行 iostat -d – x 5 > /root/iostat.out &）
#2 ．编辑 crontab 文件，每 10 分钟运行一次 IOAnalyzer.sh 脚本，-u 70 –r 80，
#表示在距上次运行 IOAnalyzer.sh 至今产生的某磁盘的监控记录中的 80% 使用率达到或超过 70%，即发出告警。
#告警日志和分析日志可通过 IOAnalyzer.sh 的 –l –a 参数指定，本例保持默认值，即在 iostat 的输出文件所在目录产生 iostat.out.log 和 iostat.out.alert 文件。
#清单 12. 编辑 crontab
 # crontab – e 
# 0,10,20,30,40,50 * * * * /root/IOAnalyzer.sh -i /root/iostat.out -u 70 -r 80>/tmp/iostat.out 2>&1
#3 ．用户收到告警邮件，需要进一步查询历史记录时，可查看日志文件
#清单 13. 查看日志文件
 # cat /root/iostat.out.log | more 
 IOSTATFILE: /root/iostat.out TIME:200905200255 STARTLINE:7220 ENDLINE:7580  ALARM:YES 
 IOSTATFILE: /root/iostat.out  TIME:200905200300  STARTLINE:7581 ENDLINE:7940 ALARM:YES 
 IOSTATFILE:/root/iostat.out TIME:200905200305  STARTLINE:7941 ENDLINE:8300 ALARM:YES 

 [AIXn01]> cat /root/iostat.out.alert | more 
 DISK:hdisk4     TIME:200905200250         RATE:84      THRESHOLD:70 
 DISK:hdisk5     TIME:200905200250         RATE:84      THRESHOLD:70 
 DISK:hdisk6     TIME:200905200250         RATE:84      THRESHOLD:70
