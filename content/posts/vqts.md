---
title: "【补发】黑QNAP之vqts破解，支持从官方升级"
date: 2022-04-13
categories:
- vQTS
- QutsCloud
typora-root-url: ..\..\static
---

这篇之前被新浪加密了，导出的工具不能登录博客导出不了，所以在这里补上

原作时间：2020-02-16

<!--more-->



{{< toc >}}

已经两年过去，官网的镜像现在无法下载了

我之前做了patch好的镜像在百度云盘上，点[这里]({{< ref "#4-最后" >}})去下载

# 0. 要求

只支持有vdx设备的虚拟机，即virtio-blk设备，kvm或者bhyve均可，virtualbox不支持

已经测试的平台，freebsd 12.0 + bhyve, proxmox(lastest version)+kvm 

# 1. 镜像
首先，下载vqts镜像，下载后需要使用qemu-img解密

~~下载地址为https://download.qnap.com/Storage/Full_VirtualQTS/vQTSRelease3.2.xml~~（已失效）

解密密码为：`jo!xu06@wj/#Rico`

# 2. 修改设置
## 1. 修改grub引导参数：
```shell
rdinit=/bin/bash path=/bin:/sbin -c -- export\$\{IFS\}PATH=/bin:/sbin\;mount\$\{IFS\}-t\$\{IFS\}devtmpfs\$\{IFS\}devtmpfs\$\{IFS\}/dev\;cd\$\{IFS\}/lib/modules/KVM\;insmod\$\{IFS\}virtio_blk.ko\;sleep\$\{IFS\}5\;mount\$\{IFS\}/dev/vda1\$\{IFS\}/mnt\;cp\$\{IFS\}/mnt/start.sh\$\{IFS\}/start.sh\;source\$\{IFS\}/start.sh\;
```

## 2. 序列号
放置文件SN于boot分区，内容为你自己定义的序列号

类似于Q177I15622，不带回车，10位ASCII



## 3. 启动脚本
以下脚本放置于boot分区，命名为start.sh，启动后该脚本会自动把SN计算得到的MD5写入硬盘偏移，并且替换系统的dmidecode
```shell
#!/bin/sh

exec_init() {
        umount /mnt
        umount /dev
        umount /sys
        umount /proc

        cd /
        echo "Last chance to check root, Press Enter to break in to bash in [10]s"
        read -t 10 && /bin/bash
        exec /init
}

PATH=/bin:/sbin
if [ -e /sbin/dmidecode.orig ];then
        echo "patched vQTS"
        exec_init
fi

# Get SN

SN=`cat /mnt/SN`

MD5=`echo "[v.1]
host_model = TVS-1277
host_fw_model = TS-X77
host_fw_build_day = 20171117
host_fw_build_ver = 4.3.3
host_fw_build_num = 20171117
host_mac_addr = 02:42:16:A7:05:04
vqts_sn = ${SN}-00
vqts_uuid = B19A0031924C084684F95ADF83AB412F" | busybox md5sum | cut -c11-18`

# write md5 to disk
echo -n -e "B19A0031924C084684F95ADF83AB412F,$MD5\0" | dd of=/dev/vda6 seek=7864576 bs=1


# Patch dmidecode
cp /sbin/dmidecode /sbin/dmidecode.orig

cat >> /sbin/dmidecode<<"eof"
#!/bin/sh

if [ $# == 0 ]; then
       echo -n "Getting SMBIOS data from sysfs.
SMBIOS 2.8 present.
15 structures occupying 641 bytes.
Table at 0xBFFFFD70.

Handle 0x0000, DMI type 0, 24 bytes
BIOS Information
       Vendor: QNAP
       Version: Not Specified
       Release Date: Not Specified
       Address: 0xE8000
       Runtime Size: 96 kB
       ROM Size: 64 kB
       Characteristics:
              BIOS characteristics not supported
              Targeted content distribution is supported
              System is a virtual machine
       BIOS Revision: 0.0

Handle 0x0100, DMI type 1, 27 bytes
System Information
       Manufacturer: OpenStack Foundation
       Product Name: OpenStack Nova
       Version: 14.0.1
       Serial Number: 48230110-dd08-4e91-b7b6-885728b98295
       UUID: dbe0e595-81ee-47e0-bbdb-2f9517d08dd4
       Wake-up Type: Power Switch
       SKU Number: Not Specified
       Family: Virtual Machine

Handle 0x0200, DMI type 2, 15 bytes
Base Board Information
       Manufacturer: TS-X77
       Product Name: TVS-1277
       Version: 20171117-4.3.3-20171117
       Serial Number: SERIALNUMBER
       Asset Tag: Not Specified
       Features:
              Board is a hosting board
       Location In Chassis: Not Specified
       Chassis Handle: 0x0300
       Type: Motherboard
       Contained Object Handles: 0

Handle 0x0300, DMI type 3, 21 bytes
Chassis Information
       Manufacturer: Not Specified
       Type: Other
       Lock: Not Present
       Version: Not Specified
       Serial Number: Not Specified
       Asset Tag: Not Specified
       Boot-up State: Safe
       Power Supply State: Safe
       Thermal State: Safe
       Security Status: Unknown
       OEM Information: 0x00000000
       Height: Unspecified
       Number Of Power Cords: Unspecified
       Contained Elements: 0

Handle 0x0400, DMI type 4, 42 bytes
Processor Information
       Socket Designation: (null) 0
       Type: Central Processor
       Family: Other
       Manufacturer: Not Specified
       ID: A1 06 02 00 FF FB 8B 0F
       Version: Not Specified
       Voltage: Unknown
       External Clock: Unknown
       Max Speed: 2000 MHz
       Current Speed: 2000 MHz
       Status: Populated, Enabled
       Upgrade: Other
       L1 Cache Handle: Not Provided
       L2 Cache Handle: Not Provided
       L3 Cache Handle: Not Provided
       Serial Number: Not Specified
       Asset Tag: Not Specified
       Part Number: Not Specified
       Core Count: 1
       Core Enabled: 1
       Thread Count: 1
       Characteristics: None

Handle 0x0401, DMI type 4, 42 bytes
Processor Information
       Socket Designation: (null) 1
       Type: Central Processor
       Family: Other
       Manufacturer: Not Specified
       ID: A1 06 02 00 FF FB 8B 0F
       Version: Not Specified
       Voltage: Unknown
       External Clock: Unknown
       Max Speed: 2000 MHz
       Current Speed: 2000 MHz
       Status: Populated, Enabled
       Upgrade: Other
       L1 Cache Handle: Not Provided
       L2 Cache Handle: Not Provided
       L3 Cache Handle: Not Provided
       Serial Number: Not Specified
       Asset Tag: Not Specified
       Part Number: Not Specified
       Core Count: 1
       Core Enabled: 1
       Thread Count: 1
       Characteristics: None

Handle 0x0402, DMI type 4, 42 bytes
Processor Information
       Socket Designation: (null) 2
       Type: Central Processor
       Family: Other
       Manufacturer: Not Specified
       ID: A1 06 02 00 FF FB 8B 0F
       Version: Not Specified
       Voltage: Unknown
       External Clock: Unknown
       Max Speed: 2000 MHz
       Current Speed: 2000 MHz
       Status: Populated, Enabled
       Upgrade: Other
       L1 Cache Handle: Not Provided
       L2 Cache Handle: Not Provided
       L3 Cache Handle: Not Provided
       Serial Number: Not Specified
       Asset Tag: Not Specified
       Part Number: Not Specified
       Core Count: 1
       Core Enabled: 1
       Thread Count: 1
       Characteristics: None

Handle 0x0403, DMI type 4, 42 bytes
Processor Information
       Socket Designation: (null) 3
       Type: Central Processor
       Family: Other
       Manufacturer: Not Specified
       ID: A1 06 02 00 FF FB 8B 0F
       Version: Not Specified
       Voltage: Unknown
       External Clock: Unknown
       Max Speed: 2000 MHz
       Current Speed: 2000 MHz
       Status: Populated, Enabled
       Upgrade: Other
       L1 Cache Handle: Not Provided
       L2 Cache Handle: Not Provided
       L3 Cache Handle: Not Provided
       Serial Number: Not Specified
       Asset Tag: Not Specified
       Part Number: Not Specified
       Core Count: 1
       Core Enabled: 1
       Thread Count: 1
       Characteristics: None

Handle 0x1000, DMI type 16, 23 bytes
Physical Memory Array
       Location: Other
       Use: System Memory
       Error Correction Type: Multi-bit ECC
       Maximum Capacity: 8 GB
       Error Information Handle: Not Provided
       Number Of Devices: 1

Handle 0x1100, DMI type 17, 40 bytes
Memory Device
       Array Handle: 0x1000
       Error Information Handle: Not Provided
       Total Width: Unknown
       Data Width: Unknown
       Size: 8192 MB
       Form Factor: DIMM
       Set: None
       Locator: (null) 0
       Bank Locator: Not Specified
       Type: RAM
       Type Detail: Other
       Speed: Unknown
       Manufacturer: Not Specified
       Serial Number: Not Specified
       Asset Tag: Not Specified
       Part Number: Not Specified
       Rank: Unknown
       Configured Clock Speed: Unknown
       Minimum Voltage: Unknown
       Maximum Voltage: Unknown
       Configured Voltage: Unknown

Handle 0x1300, DMI type 19, 31 bytes
Memory Array Mapped Address
       Starting Address: 0x00000000000
       Ending Address: 0x000BFFFFFFF
       Range Size: 3 GB
       Physical Array Handle: 0x1000
       Partition Width: 1

Handle 0x1301, DMI type 19, 31 bytes
Memory Array Mapped Address
       Starting Address: 0x00100000000
       Ending Address: 0x0023FFFFFFF
       Range Size: 5 GB
       Physical Array Handle: 0x1000
       Partition Width: 1

Handle 0x2000, DMI type 32, 11 bytes
System Boot Information
       Status: No errors detected

Handle 0x8000, DMI type 128, 27 bytes
OEM-specific Type
       Header and Data:
              80 1B 00 80 02 42 16 A7 05 04 B1 9A 00 31 92 4C
              08 46 84 F9 5A DF 83 AB 41 2F 00

Handle 0x7F00, DMI type 127, 4 bytes
End Of Table
"

elif [ "x$1" == "x-t" -a "x$2" == "x2" ]; then
        echo -n "# dmidecode 3.1
Getting SMBIOS data from sysfs.
SMBIOS 2.8 present.

Handle 0x0200, DMI type 2, 15 bytes
Base Board Information
        Manufacturer: TS-X77
        Product Name: TVS-1277
        Version: 20171117-4.3.3-20171117
        Serial Number: SERIALNUMBER
        Asset Tag: Not Specified
        Features:
                Board is a hosting board
        Location In Chassis: Not Specified
        Chassis Handle: 0x0300
        Type: Motherboard
        Contained Object Handles: 0

"

elif [ "x$1" == "x-t" -a "x$2" == "x128" ]; then
        echo -n "# dmidecode 3.1
Getting SMBIOS data from sysfs.
SMBIOS 2.8 present.

Handle 0x8000, DMI type 128, 27 bytes
OEM-specific Type
        Header and Data:
                80 1B 00 80 02 42 16 A7 05 04 B1 9A 00 31 92 4C
                08 46 84 F9 5A DF 83 AB 41 2F 00

"
else
        /sbin/dmidecode.orig $@
fi
eof

# replace SERIALNUMBER with SN
sed -i "s/SERIALNUMBER/$SN/" /sbin/dmidecode
chmod a+x /sbin/dmidecode

exec_init
```



# 3. 升级测试

![](/img/vqts-1.png)



![](/img/vqts-2.png)



# 4. 最后

**数据无价，风险自担**

如果还是不行的话，请下载镜像自己查看，新浪的排版不可靠，镜像中对dmidecode的patch不一定有用。

请自行检查dmidecode的输出，在最后一次进入bash的时候。

注意type2 以及最后一个OEM-specific Type 

链接：[https://pan.baidu.com/s/1iIxaaMf_krjG9bk8zuMrMA](https://pan.baidu.com/s/1iIxaaMf_krjG9bk8zuMrMA )

提取码：6hqx