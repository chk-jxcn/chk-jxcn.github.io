---
title: "如何在QutsCloud上安装virtualization station之套娃指南"
date: 2022-04-04
categories:
- qutscloud
typora-root-url: ..\..\static
---

现在大部分虚拟化平台都支持nested虚拟化，也就是在虚拟机中再开虚拟机，esxi也是支持的，那么可以在Qutscloud上安装虚拟机管理程序virtualization station吗。

答案是可以！

<!--more-->



{{< alert info >}}

注意，仅在esxi 6.7u2中通过测试，其他平台应该可以，但是我没有测试，如果有测试可用的平台请在评论区留言，我会在这里加上

{{< /alert >}}



已知可用的虚拟化平台：

- ESXI 6.7u2



{{< toc >}}



# 1. 准备工作

## 修改patch

- 如果是在看到这篇文章后进行的patch，则已经包含了

- 如果在4月4日之前patch的，请在ssh中执行

  - ```
    sudo curl -k https://jxcn.org/file/active.sh | bash
    ```

    

如果安装QVS仍提示失败或者是正版授权，请在安装前手动修改设置（仅在安装时检查，安装后就不会再访问，所以重启也不影响）：

```
/sbin/setcfg System VM 1 -f /etc/default_config/uLinux.conf
```



## 修改虚拟机设置

将qutscloud关机后，在虚拟机设置中开启下面的选项后再开机

- 向客户机操作系统公开硬件辅助的虚拟化
- 向客户机操作系统公开IOMMU

![](/img/qnap-qkvm-1.png)

在esxi的虚拟交换机中打开网卡混杂模式

![](/img/qnap-qkvm-8.png)



# 2. 安装QVS

在QNAP APP Center中搜索并下载virtualization station并下载，或者[点此下载](https://download.qnap.com/QPKG/QVS_3.6.21_20220324_x86_64.zip)

![](/img/qnap-qkvm-2.png)



在qutscloud的app center中上传并安装

![](/img/qnap-qkvm-3.png)



# 3. 安装系统

## 手动安装

将QVS安装好后，打开`http://[nas ip]:8088`，就可以发现QVS已经装好了，点击完成创建虚拟交换机。

![](/img/qnap-qkvm-11.png)

下面就可以在QVS中安装系统了，下载vmdk镜像，然后上传到QVS进行转换，不知道为什么，raw image无法导入

![](/img/qnap-qkvm-5.png)



然后新建虚拟机就可以了，不过记得要调整硬盘大小，但是调整之前需要删除所有快照

![](/img/qnap-qkvm-6.png)



![](/img/qnap-qkvm-7.png)



启动试试看

![](/img/qnap-qkvm-9.png)



套娃成功！



## 自动安装

在VM market中其实已经有qutscloud了，直接点击部署，就可以一键安装，至于如何操作，这里就不详细讲解了

![](/img/qnap-qkvm-10.png)

