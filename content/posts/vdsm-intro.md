---
title: "Virtual DSM 逆向笔记"
date: 2022-04-12
categories:
- VDSM
- DSM
typora-root-url: ..\..\static
---



弄完了QutsCloud，继续研究一下virtual DSM，这个其实两年前也看了一下，vdsm主要靠串口与主机通讯来验证license，发送network信息，硬盘扩容插拔事件等等。



<!--more-->

{{< toc >}}



# 1. 整体结构



在VDSM的虚拟机管理软件中，会将虚拟机的配置以及license信息放在etcd中，这样集群就可以使用同步的信息。

除了license是加密的外，其他都可以直接查看

```shell
bash-4.4# etcdctl ls /syno/live_cluster/
/syno/live_cluster/LOCK
/syno/live_cluster/vnic
/syno/live_cluster/ha_setting
/syno/live_cluster/image
/syno/live_cluster/vdisk
/syno/live_cluster/cluster_controller
/syno/live_cluster/log
/syno/live_cluster/host
/syno/live_cluster/network_group
/syno/live_cluster/repository
/syno/live_cluster/license
/syno/live_cluster/task_group
/syno/live_cluster/guests
/syno/live_cluster/setting
/syno/live_cluster/notify
/syno/live_cluster/guest_replica
/syno/live_cluster/guest_admin
```



顺便提一嘴，加密使用的是libsynocore中实现的的算法，Enigma密码机，使用的参数如下：

```C
  v12 = crypt("GLIBC_2.1", "SP");           // 参数1，cryptpw
  snprintf(v4, 0xDuLL, "%s", v12);
  v13 = 0LL;
  LODWORD(v14) = 824;						// 参数2，seed 
```

FreeBSD有一个实现和它几乎一致[https://github.com/freebsd/freebsd-src/blob/main/usr.bin/enigma/enigma.c](https://github.com/freebsd/freebsd-src/blob/main/usr.bin/enigma/enigma.c)

这是一个可逆算法，明文经过运算得到密文，再经过同样的运算可以得到明文，有兴趣的朋友可以尝试修改enigma中的参数来进行加解密，因为这个license本身的内容对VDSM并不重要，所以我不再继续分析。



qemu启动时会为vdsm启动一个虚拟串口

```
-chardev socket,id=charchannel0,path=/tmp/synohostvmcomm/guest_interface/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx,server,nowait -device virtserialport,bus=virtio-serial0.0,nr=1,chardev=charchannel0,id=channel0,name=vchannel
```

VDSM会寻找名字为vchannel的串口，然后选择它来进行通信



主机的daemons

```
/var/packages/Virtualization/target/bin/synohostcmdd 不同命令的实现，使用MQ
/var/packages/Virtualization/target/bin/synohostsvcd 其他的命令
/var/packages/Virtualization/target/bin/synohostcommd 监视文件夹变化，桥接虚拟串口与MQ
```



客户机的daemons，功能基本和主机的一样，不再详述

```
/usr/syno/bin/synoguestsvcd
/usr/syno/bin/synoguestcmdd
/usr/syno/bin/synoguestcommd
```



其中宿主机可以接受的命令在synoguestcmdd中调用一个函数指针数组处理

![](/img/vdsm-1.png)



客户机启动后，会使用固定格式的message与主机通信，有一些字段看起来是固定的，不知道什么意思，不过主要的是command id和data而已

```
random ID 	4	Bytes
NULL		4	Bytes
Guest UUID	16	Bytes
Guest ID	4	Bytes
NULL		4	Bytes
req?		4	Bytes
response?	4	Bytes
1		4	Bytes
NULL		4	Bytes
Length		4	Bytes
Command ID	4	Bytes
1		4	Bytes
0		4	Bytes
Data		N	Bytes  0<= N <= 4096-64
```



# 2. synobios.ko

VDSM的synobios.ko似乎什么事情都不做，只是设定一个固定值

```C
__int64 __usercall GetModel@<rax>(unsigned __int8 a1@<cf>, bool a2@<zf>)
{
  signed __int64 v2; // rcx@1
  _BYTE *v3; // rsi@1
  const char *v4; // rdi@1

  v2 = 5LL;
  v3 = &gszSynoHWVersion;
  v4 = "C2DSM";
  do
  {
    if ( !v2 )
      break;
    a1 = *v3 < (const unsigned __int8)*v4;
    a2 = *v3++ == *v4++;
    --v2;
  }
  while ( a2 );
  return (unsigned int)(char)(!(a1 | a2) - a1) < 1 ? 102 : 68;
}
```



# 3. 安装的选择



面临的问题

- 硬盘的类型，目前VDSM使用的是 vhost-scsi ，能不能直接使用virtio-blk还存在疑问，甚至使用sata的情况也是未知的
- 虚拟串口的支持，默认情况下，VDSM只会寻找virtio port，这个只有kvm才有，而且基本所有的vps都无法提供
- 仍然需要两块硬盘



跳过检查有两个办法

- 不改动固件，写一个串口通信的模块
- 对guest上的synoguestcommd进行patch