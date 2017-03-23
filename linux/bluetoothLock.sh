#!/bin/bash

#命令
hcitool="/usr/bin/hcitool"
awk="/usr/bin/awk"
slock="/usr/bin/slock"
ps="/bin/ps"
wc="/usr/bin/wc"
su="/bin/su"
kill="/bin/kill"
grep="/bin/grep"
echo="/bin/echo"
date="/bin/date"
cat="/bin/cat"
rm="/bin/rm"
sleep="/bin/sleep"

#锁屏帐号
user="lynn"

#被监控的蓝牙MAC地址
mac="F4:8B:32:51:EA:04"

#启动/密码解锁后时长
startupTime="3s"

#默认监控时长
sleepTimeDefault="5s"

#lock后停留时长
sleepTimeLockAfter="5s"

#蓝牙掉线后监控时长
sleepTimeDownStatus="10s"

#unlock后停留时长
sleepTimeUnlockAfter="5s"

#最快监控时长
sleepTimeFast="0s"

#lock监控阀值
sizeLockLimit=50

#unlock监控阀值
sizeUnlockLimit=30

#lock监控阀值连续次数
lockLimitCountLimit=3

#蓝牙掉线状态连续次数
downStatusCountLimit=$[2 * $lockLimitCountLimit + 1]

#unlock监控阀值连续次数
unlockLimitCountLimit=5

#去噪阀值，数值波动率，单位%
sizePercentLimit=50

#pid文件
pidFile="/tmp/bluetoothLock_pid.log"

#日志文件
logFile="/tmp/bluetoothLock.log"

#slock的pid文件
slockPidFile="/tmp/slock_pid.log"

#lock标志
lockFlag=0

#bluetooth标志
bluetoothFlag=0

#保证只运行一个
ppid=$($cat $pidFile)
if [ "$ppid" > "0" ]; then
 $kill -9 $ppid
fi
 
pid=$$
$echo $pid > $pidFile

$rm -f $slockPidFile

#防止死锁
sleep $startupTime;

$echo `$date +%Y-%m-%d\ %H:%M:%S`"[start]" >> $logFile;

size=100

#监控
while [ -f "$pidFile" ]
do

 upSize=$size
 #获取信号强度，越大越弱，100最弱
 #output1=$($hcitool cc $mac && $hcitool lst $mac | $awk -F' \(' '{print $2}' | $awk -F')' '{print $1}' && $hcitool clock $mac | $awk '{print $2" "$3}' && $hcitool rssi $mac | $awk '{print -1 * $4}' && $hcitool lq $mac | $awk '{print $3}' && $hcitool tpl $mac | $awk '{print -1 * $5}')
 #status=$($echo $output1 | $awk '{print $6}')
 status=$($hcitool cc $mac && $hcitool rssi $mac | $awk '{print -1 * $4}')
 if [ "$status" == "" ]; then
  status="down"
  size=100
 else
  size=${status#-}
 fi
 output2="1 2 3 4 5 -"$status"- 7 8"

 output=$output2
 $echo $output >> $logFile

 #蓝牙状态检测
 if [ "$status" == "down" ]; then
  downStatusCount=$[$downStatusCount+1]
  sleepTime=$sleepTimeFast
 else
  downStatusCount=0
  bluetoothFlag=1
  sleepTime=$sleepTimeDefault
 fi
 if [ "$downStatusCount" -ge "$downStatusCountLimit" ]; then
  bluetoothFlag=0
  sleepTime=$sleepTimeDownStatus
  #$echo $($date +%Y-%m-%d\ %H:%M:%S)"[down] "$downStatusCount" >= "$downStatusCountLimit >> $logFile;
  if [ "$downStatusCount" == "$downStatusCountLimit" ]; then
   $echo $($date +%Y-%m-%d\ %H:%M:%S) >> $logFile;
   $echo "downStatusCount: $downStatusCount >= $downStatusCountLimit" >> $logFile
  fi
 fi
 
 #蓝牙正常
 if [ "$bluetoothFlag" == "1" ]; then
  #去噪
  if [ "$upSize" -ne "$size" ]; then
   if [ "$upSize" -lt "1" ]; then
    upSize=1
   fi
   sizeTmp=$[$size - $upSize]
   sizeTmp=${sizeTmp#-}
   sizePercent=$[$sizeTmp * 100 / $upSize]
   if [ "$sizePercent" -ge "$sizePercentLimit" ]; then
    continue;
   fi
  fi
  #未锁
  if [ "$lockFlag" == "0" ]; then

   if [ "$size" -ge "$sizeLockLimit" ]; then
    sleepTime=$sleepTimeFast;
    limitCount=$[$limitCount+1]
   else
    limitCount=0
   fi
   if [ "$limitCount" -ge "$lockLimitCountLimit" ]; then
    $echo $($date +%Y-%m-%d\ %H:%M:%S) >> $logFile;
    $echo "lockSet: "$sizeLockLimit >> $logFile;
    $echo "lockLimitCount:"$limitCount" >= "$lockLimitCountLimit >> $logFile;
    limitCount=0
    #锁屏
    $su $user -c "$slock &"
    slockPid=$($ps aux | $grep -v "$grep" | $grep "$slock" | $awk '{print $2}')
    if [ "$slockPid" > "0" ]; then
     $echo $slockPid > $slockPidFile
     $echo "slock pid: "$slockPid >> $logFile
     lockFlag=1
     sleepTime=$sleepTimeLockAfter
    fi
   fi

  #已锁
  else

   if [ "$size" -le "$sizeUnlockLimit" ]; then
    sleepTime=$sleepTimeFast;
    limitCount=$[$limitCount+1]
   else
    sleepTime=$sleepTimeFast;
    limitCount=0
   fi
   if [ "$limitCount" -ge "$unlockLimitCountLimit" ]; then
    $echo $($date +%Y-%m-%d\ %H:%M:%S) >> $logFile;
    $echo "unlockSet: "$sizeUnlockLimit >> $logFile;
    $echo "unlockLimitCount:"$limitCount" >= "$unlockLimitCountLimit >> $logFile;
    limitCount=0
    #解锁
    slockPid=$($cat $slockPidFile)
    if [ "$slockPid" > "0" ]; then
     $su $user -c "$kill -9 $slockPid"
    fi
    lockFlag=0 
    sleepTime=$sleepTimeUnlockAfter
    $rm -f $slockPidFile
    $echo "unlock slock pid: "$slockPid >> $logFile
   fi

  fi
 fi

 if [ "$lockFlag" == "1" ] && [ -f "$slockPidFile" ]; then
  slockPid=$($cat $slockPidFile)
  if [ "$slockPid" > "0" ]; then
   lineCount=$($ps $slockPid | $wc -l)
   #输入密码的方式解锁
   if [ "$lineCount" -ne "2" ]; then
    #防止死锁
    sleepTime=$startupTime
    lockFlag=0
    limitCount=0
    $rm -f $slockPidFile
   fi
  fi
 fi

 #echo "upSize: $upSize size: $size" >> $logFile
 $sleep $sleepTime;

done

$echo `$date +%Y-%m-%d\ %H:%M:%S`"[stop]" >> $logFile;
