---
title: "QutsCloud 逆向笔记"
date: 2022-03-15
categories:
- qutscloud
thumbnailImagePosition: "top"
thumbnailImage: /img/qnap-intro-cover-750.png
---

这才三月份，深圳的天气就这么热，看瞅着往三十度飙，再加上疫情导致的封闭管理，闲来无事坐在家里顺手把前年没整完的qutscloud继续整整。

<!--more-->



tg交流群：https://t.me/qutscloud



这两天简单看了一下，一年半过去了，里面除了换了一些函数和调用命令的名字，其他的东西几乎没变。

内核版本从4.14.24升级到了5.10.60，QNAP别的不好说，升级内核版本还是很给力的，内核基本上紧跟桌面系统内核版本，这点甩了群晖一百条街。

关于qutscloud的逆向，准备弄一个系列出来，因为订阅制的关系，校验的地方多了一些，但是大部分代码写的很浅显易懂，在逆向的过程中，也能学习到不少有用的知识。



下面是暂时整理的分段，我会尽量每周至少更新一篇。


- [安装]({{< ref "qnap-install.md" >}})
- [启动顺序及切入点]({{< ref "qnap-start-point.md" >}})
- [安装包文件签名校验]({{< ref "qnap-sign-check.md" >}})
- [qlicense设备标识文件及许可证文件]({{< ref "qnap-license.md" >}})
- [激活思路及路线选择]({{< ref "qnap-fake-activation.md" >}})
- [无侵入式补丁及支持官方升级的可能性]({{< ref "qnap-official-upgrade.md" >}})
- [能否在硬件平台安装qutscloud]({{< ref "qnap-hardware.md" >}})
- [qutscloud的安全性解读]({{< ref "qnap-security.md" >}})


由于在线服务器无法提供稳定的服务，因此提供qlicense的分析以及开源服务器

对于不想研究内部实现的同学，我也准备了一篇傻瓜式安装教程

- [【番外】史上最简单安装QutsCloud的办法 ]({{< ref "qnap-simple-install.md" >}})



另外还是要说一遍

**数据无价，如果底层存储没有快照或者没有备份，请不要存放重要数据**

