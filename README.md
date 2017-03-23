
使用前需要更改如下两个参数，帐号需要当前登录用户帐号，mac地址是需要检测的蓝牙地址：
#锁屏帐号
user="lynn"

#被监控的蓝牙MAC地址
mac="F4:8B:32:51:EA:04"

另外，头部的命令按照系统不同请自行更改，一般不用变更

需要root用户运行，例如：
sudo bash bluetoothLock.sh
