---
title: "【番外】史上最简单安装QutsCloud的办法"
date: 2022-03-30
categories:
- qutscloud
typora-root-url: ..\..\static
---

最后更新日期：2023年04月06日 00点39分



经过一个晚上的思想斗争，还是决定写这一篇，当然声明还是要来一个的

{{< alert danger no-icon>}}

！！！本页内发布的任何工具及脚本仅供个人学习及研究之用！！！

！！！请在下载后24小时内删除！！！


{{< /alert >}}


<!--more-->

{{< toc >}}



{{< alert danger no-icon>}}

**注意：**

本篇演示的激活未hook https连接，以及有部分api未实现，**无法保证稳定性**

如果您使用了socks代理或者http代理，则会完全失效（本篇基于域名劫持原理来劫持api）



稳定的激活请参考=>[这篇]({{< ref "qnap-more-simple-install.md" >}}) （仅激活系统，其他许可则需要购买）

如果想研究本篇服务器的实现，请参考文末源码（包含可用许可的许可证模板）

源码可以随意使用（作者声明其在public domain），但请尽量保留来源，即本文地址


{{< /alert >}}



tg交流群：https://t.me/qutscloud


# 1.安装原版系统



请参考官方文档或者[安装]({{< ref "qnap-install.md" >}})



# 2. 运行脚本



ssh进QutsCloud后运行命令，sudo的密码与登录密码一致（若没有激活则默认登录就是root权限）

{{< alert info >}}

全新镜像启动的用户名和密码分别是admin及去掉`:`然后全部大写的MAC地址，虚拟机启动界面会提示

{{< /alert >}}

```
sudo curl -k https://jxcn.org/file/active.sh | bash
```

![](/img/qnap-simple-install-1.png)



# 3. 重启

（非必须，但是**建议重启**，以避免无法发现下次启动失败的情况）

![](/img/qnap-simple-install-2.png)



# 4. 安装

直接输入下面的序列号即可
```
L1111-11111-11111-11111-11111
```


![](/img/qnap-simple-install-3.png)



![](/img/qnap-simple-install-4.png)



![](/img/qnap-simple-install-5.png)



![](/img/qnap-simple-install-6.png)



![](/img/qnap-simple-install-7.png)







# 5. 需要注意的

## 小tips

- 尽量使用静态卷（无法自动扩展空间，但是基本不会有问题，恢复数据也很容易，数据安全请使用下层snapshot保证）

- Esxi新建snapshot后硬盘无法扩展大小，可以新加硬盘（所以用静态卷就可以了）

- 支持百度云盘同步的HybridMount->[https://www.aliyundrive.com/s/1HpFZnq5UGB](https://www.aliyundrive.com/s/1HpFZnq5UGB)

- 支持的最大核心数是100，应该够用了吧

- QTS至今尚不支持e1000e网卡(virtualbox可以使用e1000)

- 因为是域名劫持的方式实现的，所以使用代理上网时激活会失败，可以手动劫持以下域名及子域名到132.145.94.147
  - myqnapcloud.com
  - myqnapcloud.cn
  
- 因为服务器负载的限制，只允许注册有限数量的设备，每台注册的设备可以随意激活任意数量的许可证，设备超过数量限制后就不再接受新加设备的注册请求了，点[这里](http://132.145.94.147/device_count)查看现在的设备数量

  



---

## 存在的问题

因为接管了系统的myQNAPcloud云服务，所以

- 无法停用激活的许可证
- 无法登录QNAP ID
- 任何依赖myQNAPcloud云服务的功能将无法运行，包括以下
  - 远程消息推送
  - oauth认证
  - DDNS
- 无法获取最新的product list
- 无法使用官网购买的许可证
- 作者未测试升级的情况，理论上支持
- 升级后可能不可用（作者只会做最低限度的维护，不保证后续可用）

---

## 服务器的可用性

因为可能需要修补bug，但是又无法使用远程API停用许可证，请在服务器数据库重置后重新更新许可证

使用如下命令更新本机许可（会删除原有的所有许可）

```shell
#!/bin/sh

rm -f /mnt/boot_config/qlicense/*.lif /mnt/boot_config/qlicense/*.dif
rm -f /etc/config/qlicense/lif/*.lif /etc/config/qlicense/dif/*/*.dif
rm -f /etc/config/qlicense/decrypt/lif/*

sed -i "/floating_refresh/d" /tmp/cron/crontabs/admin
sed -i "/floating_refresh/d" /mnt/HDA_ROOT/.config/crontab

qlicense_tool online_activate -k L1111-11111-11111-11111-11111
```

另外，激活命令可以运行多次，但是只有最后下载的许可证有效，之前的许可floating_refresh会失败，请务必**删除所有许可**后再激活，或许需要一次重启来保证后台程序全部被清理掉，目前发现storage_util可能会卡死。



**修改记录**

```changelog
2022-04-25  (未重置) 修改floating refresh为43200秒，虽然可能会失败，但是会自动重试
2022-04-21  (未重置) 修复list installed license可能会失败的问题
2022-04-10  (未重置) 修复dns可能失效的问题，建议重新patch后重启，若dns查询失败，请手动添加dns服务器
2022-04-06  (未重置) 修复一些会导致程序crash的bug，重新测试一遍所有序列号
2022-04-03  (未重置) 修改floating refresh为一个月，QutsCloud中crontab的格式要求最少一个月一次
2022-04-02  (已重置) 修复update忘记加where的问题😅
2022-04-01  (已重置) 修复未知uuid的问题
```



---

## APP

QutsCloud的APP Center里的APP不多，但是可以在QNAP的APP Center页面中下载X86的安装包，例如photo station, download station等等，然后在系统的APP Center上传安装即可

地址==>[https://www.qnap.com/zh-cn/app_center/](https://www.qnap.com/zh-cn/app_center/)

![](/img/qnap-simple-install-8.png)



  


---

## 目前可用的序列号

可用的序列号列表(如果提示device not support，请先下载app包后手动安装，例如mediasign player，里面应该是有hardcode，改起来略麻烦，所以就先将就一下)： 

```
L1111-11111-11111-11111-11111 √  QutsCloud (100 核心)
L8111-11111-11111-11111-11111 √  HybridMount (100连接)
L1811-11111-11111-11111-11111 x  Coolocto Video for QuTScloud（需要登录QNAP ID）
L1181-11111-11111-11111-11111 √  Qsirch
L1118-11111-11111-11111-11111 √  QuMagie
L1111-81111-11111-11111-11111 √  VJBOD Cloud （100连接）
L1111-18111-11111-11111-11111 =  McAfee Antivirus （没啥用，不测试了）
L1111-11811-11111-11111-11111 √  CAYIN MediaSign Player (plus版本)
L1111-11181-11111-11111-11111 √  Boxafe
L1111-11118-11111-11111-11111 √  QmailAgent（Premium版本）
L1111-11111-81111-11111-11111 √  OCR Converter
L1111-11111-18111-11111-11111 √  Qfiling for QuTScloud Upgrade (Premium版本)
```
以上序列号并非全部可用，有一些设定只是猜测值，请酌情使用

```
√ : 已测试，可以正常使用
× ：已测试，无法使用 (若朋友们有进展请在评论区留言)
= : 尚未测试
```



如果需要什么产品的序列号请在下面评论区留言，有时间我就会更新
或者你可以提交这个产品的license_info，仅需要其中的`attributes`及`product`字段

---

小笔记(请忽略)

1. createAt 必须在24小时内

2. is_subscription=false与valid_unitl=None不能同时设定，expires_at与valid_until相差过大就会extend

3. floating refresh多次失败后会自己生成未知uuid

4. license id在show info及activate过程需要保持不变

   

下面貌似是个除法，但是我不知道怎么算。

```
(signed int)(((signed __int64)((unsigned __int128)(1749024623285053783LL * (v6 - v7)) >> 64) >> 13)
                  - ((v6 - v7) >> 63)) > 0
```

floating_refresh 似乎不能小于一天，否则会显示fail或者fail_lock

```c
__int64 __fastcall qcloud_license_get_api_check_status(__int64 a1, char *a2, int a3)
{
  int v3; // er12@1
  int v4; // ecx@1
  int v5; // ebx@2
  __int64 v6; // rax@3
  __int64 v8; // [sp+0h] [bp-238h]@1
  char v9; // [sp+200h] [bp-38h]@1

  v3 = 0;
  memset(&v8, 0, 0x200uLL);
  v4 = *(_DWORD *)(a1 + 19612);
  v9 = 0;
  if ( !v4 )
  {
    v5 = a3;
    if ( *(_DWORD *)(a1 + 19256)
      || (v3 = sub_12B40(a1 + 643, "/sbin/getcfg -f %s \"%s\" \"NONCHECK_PERIOD\" -d \"\"", &v8),
          (v6 = strtoll((const char *)&v8, 0LL, 10)) == 0) )
    {
      snprintf(a2, v5, "%s", "success");
    }
    else if ( v6 > 172800 )
    {
      snprintf(a2, v5, "%s", "fail_lock");
    }
    else if ( v6 > 86400 )
    {
      snprintf(a2, v5, "%s", "fail");
    }
    else
    {
      snprintf(a2, v5, "%s", "success");
    }
  }
  return (unsigned int)v3;
```





## 本地部署

目前还不支持本地部署，原本的计划是在本机启动一个proxy，除license相关的请求全部正常转发，而license的请求内部处理。

但是现在这个license manager server感觉还不是很稳定，偶尔会掉注册啥的，测试一段时间之后再实现这个代理服务器好了。



# 6. 最重要的



**本篇教程仅作体验之用，请支持正版软件，价格和群晖的skynas差不多（一年300多RMB），但是比skynas部署灵活，功能也强很多**

订阅地址：[https://software.qnap.com/qutscloud.html](https://software.qnap.com/qutscloud.html)

---

**数据无价，请谨慎使用**

**数据无价，请谨慎使用**

**数据无价，请谨慎使用**



# 7. 自建服务器



点击[这里](https://jxcn.org/file/qnap_fake_server.zip)下载服务器源码，运行的步骤差不多如下

1. 生成private key及public key
2. 生成数据库(license.db.sql)
3. 替换脚本里的ip

逻辑没有特别复杂，应该一点点时间就能看明白

添加product的话就在product_generate添加模板就可以

license key有一个校验，需要里面数字的和满足啥要求。。忘记了，qnap校验license的js里有写

这个东西基本就这样，我应该不会再更新了。



另外再提一嘴，如果需要稳定一些，我觉得应该是需要使用https劫持的，需要自己导入https公钥和劫持域名

另外要支持qnap cloud的话可以用nginx分发请求，这个和license应该是独立的。