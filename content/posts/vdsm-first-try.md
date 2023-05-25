---
title: "【完结】Virtual DSM 逆向笔记 (基于libvirt的安装及升级)"
date: 2022-04-25
categories:
- VDSM
- DSM
typora-root-url: ..\..\static
---



花了一点时间写了一个模拟串口通信的程序，看起来和在DSM上面运行的一样，升级也没有问题，不过没有登录群晖账号，程序预留了设置所有通信参数的设定参数，若是有想试试洗白的朋友可以自己试试

{{< alert danger no-icon>}}

！！！本页内发布的任何工具及脚本仅供个人学习及研究之用！！！

！！！请在下载后24小时内删除！！！

{{< /alert >}}



<!--more-->



{{< toc >}}



tg交流群：https://t.me/qutscloud

@kroese的Virtual DSM => https://github.com/kroese/virtual-dsm

# 1. 系统相关设置及准备

这里我用的系统是ubuntu 20.04，PVE之类的使用kvm平台的应该也差不多。

如果确定知道自己需要做些什么的朋友，这一章可以跳过。



## 1. 安装virt及kvm

```
apt install qemu-kvm libvirt-daemon-system libvirt-clients
```



## 2. 安装其他的一些工具

```
apt install uml-utilities bridge-utils
```



## 3. 修改设置

```
# /etc/libvirt/qemu.conf
user="root"
group="root"
security_driver = "none"
```



```
service libvirtd restart
```



## 4. 创建br0

/etc/netplan/00-installer-config.yaml，这里只是ubuntu的例子，反正最终只是给libvirt用，可以自己随意设置

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens160:
      dhcp4: no
  bridges:
    br0:
      dhcp4: yes
      interfaces:
             - ens160
```



```
netplan apply
```



# 2. 准备镜像及用户数据盘

链接：[https://pan.baidu.com/s/16I89NHPTW6TDx7ACh67yiA](https://pan.baidu.com/s/16I89NHPTW6TDx7ACh67yiA )

提取码：7hkq 

下载下来的镜像是我从DSM中提取出的VDSM 7.0的安装镜像，未做任何修改，因为新版本的包似乎不是用tar，但是我又不想花时间去逆向，所以就用了老版本的镜像，反正随时可以升级的。

后面如果有时间的话，大概会研究一下怎么从pat生成系统镜像，不过还是之后再说好了。

## 1. copy镜像到/opt/vdsm

因为虚拟机的xml中设置的路径是/opt/vdsm，所以请copy 里面的镜像到/opt/vdsm，放到别处的话就修改vdsm_template.xml中的/opt/vdsm到其他路径

```shell
mkdir -p /opt/vdsm
tar xf vdsm-imgs.tar.gz
mv vdsm-imgs/*.img /opt/vdsm
```



## 2. 创建用户数据盘

```
truncate -s 100G /opt/vdsm/user_data.img
```

这里创建了100G的数据盘，由于没有实现硬盘扩容通知，所以安装完成后如果想要增加硬盘容量需要关机后操作。



## 3. 导入xml

```
virsh define vdsm_template.xml
```

如果需要修改cpu数量，或者内存，都可以在启动之前修改

```
virsh edit VDSM
```

**注意：xml中指定了bridge到br0，所以如果使用nat或其他网络请自行修改**



## 4. 启动串口通信设备模拟程序

从这里下载：[https://jxcn.org/file/vdsm-serial](https://jxcn.org/file/vdsm-serial)

如果只是想随便用用，什么参数都不要都可以，或者可以改成systemd里的service，不过这个我就不写了，大家可以自由发挥。

参数也基本上是自描述的，要洗白的话就大概只有hostsn和guestsn这两个可能有用，其他的都只在本机使用。

```
# vdsm-serial --help
Usage of vdsm-serial:
  -addr string
        Listen address (default "0.0.0.0:12345")
  -buildnumber int
        Build Number of Host (default 42218)
  -cpu int
        Num of Guest cpu (default 1)
  -cpu_arch string
        CPU arch (default "QEMU, Virtual CPU, X86_64")
  -fixNumber int
        Fix Number of Host
  -guestsn string
        Guest SN, 13 bytes (default "0000000000000")
  -guestuuid string
        Guest UUID (default "ba13a19a-c0c1-4fef-9346-915ed3b98341")
  -hostsn string
        Host SN, 13 bytes (default "0000000000000")
  -vmmts int
        VMM Timestamp (default 1650802981032)
  -vmmversion string
        VMM version (default "2.5.5-11487")

# vdsm-serial
2022/04/25 01:28:53 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
2022/04/25 01:28:53 !!! Just for experimental, please delete it after 24 hour  !!!
2022/04/25 01:28:53 !!! See https://jxcn.org for update.                       !!!
2022/04/25 01:28:53 !!! This program will be unavailable after 2022-12-31      !!!
2022/04/25 01:28:53 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
2022/04/25 01:28:53 Start listen on 0.0.0.0:12345
2022/04/25 01:29:02 New connection from 192.168.2.187:42068
2022/04/25 01:36:21 Command: Guest Timestamp from Guest:0 
2022/04/25 01:36:21 Info: 1648798789
2022/04/25 01:37:12 Command: Guest SN from Guest:10000000 
2022/04/25 01:37:12 Response data: 0000000000000
2022/04/25 01:37:12 Command: Guest UUID from Guest:10000000 
2022/04/25 01:37:12 Response data: ba13a19a-c0c1-4fef-9346-915ed3b98341
2022/04/25 01:37:12 Command: Cluster UUID from Guest:3000000 
2022/04/25 01:37:12 Response data: 3bdea92b-68f4-4fe9-aa4b-d645c3c63864
2022/04/25 01:37:12 Command: Guest SN from Guest:10000000 
2022/04/25 01:37:12 Response data: 0000000000000
...
```



## 5. 启动虚拟机

```
virsh start VDSM
```

![](/img/vdsm-first-try-2.png)



# 3. 升级测试

![](/img/vdsm-first-try-3.png)



![](/img/vdsm-first-try-4.png)



![](/img/vdsm-first-try-5.png)



![](/img/vdsm-first-try-6.png)



![](/img/vdsm-first-try-7.png)



# 4. 最后

这个串口的程序的源码在这里： [https://jxcn.org/file/vdsm-serial.zip](https://jxcn.org/file/vdsm-serial.zip)

有兴趣的话可以看看，或者做些补充啥的，不过我觉得其他的没啥意义。



还有一些：

1. 理论上，这个是可以无限支持官方版本升级的，因为没有做任何补丁，都是VDSM官方原版的镜像

2. 因为仅仅只是作为一个实验，所以串口通信模拟程序我设置到2023年失效，如果作者没有更新，到了时间又想继续使用，请修改本机时间在2023年之前再启动串口程序，启动之后可以再把本机时间修改回来

3. VDSM看起来似乎是很边缘的产品，虽然支持力度看起来蛮大，不过由于许可证仅仅是用来支持升级，这里的程序也不支持群晖硬件系统，所以其实用用的话群晖应该不在意的吧。

4. 当然，还有最重要的：

   

   **数据无价，请谨慎操作**

   **数据无价，请谨慎操作**

   **数据无价，请谨慎操作**