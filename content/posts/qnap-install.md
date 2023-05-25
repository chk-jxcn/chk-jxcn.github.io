---
title: "QutsCloud 逆向笔记 - 安装"
date: 2022-03-20
categories:
- qutscloud
typora-root-url: ..\..\static
thumbnailImagePosition: "top"
thumbnailImage: /img/qnap-install-cover-750.png
---

QNAP官方有安装qutscloud的文件以及手册，虽然已经很详细了，但是我还是简单介绍一下怎么安装原版系统。本人使用esxi 6.7u2作为宿主机系统，使用同版本esxi的朋友可以作为参考。

<!--more-->

{{< toc >}}

# 1. 下载镜像

QNAP官方的下载地址为：
https://www.qnap.com/zh-hk/download?model=qutscloud&category=firmware

因为已知ova无法在esxi 6.7u2完成安装，所以我们选择下载VMDK - Full Disk Image。

![](/img/qnap-install-2.png)

# 2. 上传硬盘镜像到esxi

在esxi的数据存储浏览器中直接上传，最好新建一个新的文件夹

![](/img/qnap-install-1-3.png)



# 3. 转换磁盘镜像

因为QNAP下载的vmdk镜像版本无法在esxi 6.7中启动，需要转换一下
登录到esxi的ssh控制台，使用如下命令转换磁盘镜像：

```
[root@localhost:/vmfs/volumes/621d5fae-c9d09868-1506-003111061288/qutscloud-install-diskimg] vmkfstools -i F_TS-KVM-CLD_20220218-c5.0.1.img.vmdk qutscloud-new.vmdk -d thin
Destination disk format: VMFS thin-provisioned
Cloning disk 'F_TS-KVM-CLD_20220218-c5.0.1.img.vmdk'...
Clone: 100% done.
```

请自行替换`F_TS-KVM-CLD_20220218-c5.0.1.img.vmdk`为上传的镜像名字

# 4. 创建虚拟机

创建一台普通的虚拟机，先删除硬盘，再修改启动方式为bios （默认为efi）
其他选择默认即可

![](/img/qnap-install-1.png)

![](/img/qnap-install--6.png)

![](/img/qnap-install-5.png)

![](/img/qnap-install-4.png)

# 5. 导入硬盘
在esxi的数据存储浏览器中复制qutscloud-new.vmdk到虚拟机对应的文件夹下

![](/img/qnap-install-7.png)

# 6. 将硬盘添加到虚拟机
在虚拟机设置中，选择新增硬盘->现有硬盘，添加复制后的硬盘镜像，目前大小是无法修改的。
虽然已经转换为thin磁盘，但是似乎导入后变成thick了，不过没关系，第一次启动后关机就可以变成thin了。

![](/img/qnap-install-8.png)

# 7. 启动虚拟机并修改硬盘大小
在开机然后关机后，就发现磁盘变成thin磁盘了，并且可以修改大小，我这里修改为50G，内存可以适当改大一点，4G以上最好，因为宿主机内存的限制，我这里只分配了1G(qutscloud要求最少2G，否则无法启动)

![](/img/qnap-install-9.png)

# 8. 启动并登录ssh
启动后，可以在控制台看到IP地址及MAC地址，根据提示admin的密码为MAC地址去掉 : 后全部大写，我这里的密码即000C291AEED8

![](/img/qnap-install-10.png)

同时，使用浏览器也可以访问到对应的地址了

![](/img/qnap-install-11.png)



至此安装已经全部完成，可以在web中点击启动智能安装进行安装（如果已经购买License的话）