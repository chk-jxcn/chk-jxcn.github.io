---
title: "YT88脱壳笔记"
date: 2022-06-19
categories:
- debug
- unpack
typora-root-url: ..\..\static
---



朋友有个程序必须用加密狗才能运行，让我试着看看能不能复制加密狗或者脱狗运行，于是有了这篇

<!--more-->



# 1. 加密狗的原理

因为手里有狗，所以先检查一下狗的VID，发现是YT88，东莞一个叫做域天的厂家做的，去网上找了一下它的工具，然后用usb trace跟踪。发现它有四种加密方法

a) 普通算法，读写存储器使用的读密码，同时也可以用来加密一个整数

b) 增强算法一，密钥存储在程序中，计算一个随机负载的加密值，与加密狗的计算结果对比

c) 增强算法二，程序中只存储应答表，随机选出里面的负载和对应的应答值，与加密狗的计算结果对比

d) 国密sm，这个加密狗硬件版本太低，没实现非对称算法



a) 的读密钥直接可以从usb trace中读出，是以明文发送的，b) 及c) 使用的是通用的算法TEA，它的模板中有给出算法的实现：

```c
void SoftKey:: EncBySoft(   BYTE  *   aData,  BYTE   *   aKey   )
{
    const   unsigned   long   cnDelta   =   0x9E3779B9;
    register   unsigned   long   y   =   (   (   unsigned   long   *   )aData   )[0],   z   =   (   (   unsigned   long   *   )aData   )[1];
    register   unsigned   long   sum   =   0;
    unsigned   long   a   =   (   (   unsigned   long   *   )aKey   )[0],   b   =   (   (   unsigned   long   *   )aKey   )[1];
    unsigned   long   c   =   (   (   unsigned   long   *   )aKey   )[2],   d   =   (   (   unsigned   long   *   )aKey   )[3];
    int   n   =   32;

    while   (   n--   >   0   )
    {
        sum   +=   cnDelta;
        y   +=   ((   z   <<   4   )   +   a )  ^   (z   +   sum )  ^  ( (   z   >>   5   )   +   b);

        z   +=   ((   y   <<   4   )   +   c )  ^   (y   +   sum )  ^  ( (   y   >>   5   )   +   d);
    }
    (   (   unsigned   long   *   )aData   )[0]   =   y;
    (   (   unsigned   long   *   )aData   )[1]   =   z;
}

void SoftKey:: DecBySoft(    BYTE  *   aData,   BYTE   *   aKey   )
{
    const   unsigned   long   cnDelta   =   0x9E3779B9;
    register   unsigned   long   y   =   (   (   unsigned   long   *   )aData   )[0],   z   =   (   (   unsigned   long   *   )aData   )[1];
    register   unsigned   long   sum   =   0xC6EF3720;
    unsigned   long   a   =   (   (   unsigned   long   *   )aKey   )[0],   b   =   (   (   unsigned   long   *   )aKey   )[1];
    unsigned   long   c   =   (   (   unsigned   long   *   )aKey   )[2],   d   =   (   (   unsigned   long   *   )aKey   )[3];
    int   n   =   32;
    while   (   n--   >   0   )
    {
        z   -=  ( (   y   <<   4   )   +   c )  ^  ( y   +   sum  ) ^ (  (   y   >>   5   )   +   d);
        y   -=  ( (   z   <<   4   )   +   a )  ^  ( z   +   sum  ) ^ (  (   z   >>   5   )   +   b);
        sum   -=   cnDelta;
    }
    (   (   unsigned   long   *   )aData   )[0]   =   y;
    (   (   unsigned   long   *   )aData   )[1]   =   z;
}
```



# 2. 破解思路



a) 如果没有使用增强算法二，那么可以提取出程序中的密钥1以及读密钥，然后复制加密狗

b) 如果使用算法二，则可以1. 穷举来找出密钥，2. 使用其他的值替换增强算法二中的应答表，3. 造一个假狗，对请求回应应答表中的值（加密狗是一个USB HID设备，树莓派就可以模拟），4. 为已有的狗建立一个远程服务器，则可以利用它来解密其他机器上的程序（同样需要一个虚拟驱动或者模拟的硬件）

c) 脱壳



看了一下，这个程序使用了加密算法二，所以a) 就可以淘汰了，b) 中，感觉只有3有可操作性，因为4也要弄个假狗来通信，那么其实没必要用远程服务器了，毕竟应答表是固定的，穷举有难度，对程序做patch肯定也是需要修改验证的。

另外，如果使用国密sm算法，假狗应该也不行了（对随机数据签名，不再是固定应答），只有4才有可能实现（不过如果对狗ID校验的话也会失败，不过ID似乎不会参与国密sm的运算，所以可以用模拟的回答）。



# 3. 尝试脱壳



这里其实也不是尝试，已经试了很多次，而且看了看雪的脱壳教程，以及几个大佬对yt88脱壳的帖子

脱壳教程： https://bbs.pediy.com/thread-20366.htm

YT88脱壳大佬：

OEP dump重入 https://bbs.pediy.com/thread-258258.htm

PE dump修复 https://bbs.pediy.com/thread-214287.htm



这两个大佬脱壳的思路是不一样的，第一个大佬在进OEP之前将程序分配的可执行段存储为PE sector，这样下次启动即可直接恢复到OEP中执行。第二个大佬则用了更复杂的方法，他将程序解密的可执行段dump出来后进行修复，但是比较困难，不过他的视频很详细，有点意思。



我用类似第一个大佬的方法做的（ollydbg+ollydumpex）：

1. 因为程序有int3的反调试，所以需要勾选让程序自己处理异常

2. F9运行后会中断在反调试的int3后，这时对virtualfree下断点

3. shift+F9，忽略异常继续执行（seh会处理int3）

4. 多次F9后检查返回点的代码（同时可以看到usb trace中有通信），在这里就jmp到OEP

   ```asm
   
   02E80000    6A 00           push    0
   02E80002    68 00204500     push    452000      (解密后的程序的大小452000)
   02E80007    68 0000B403     push    3B40000     (解密后的程序的基址3B40000)
   02E8000C    68 00004000     push    400000      (加载地址)
   02E80011    68 FFFFFFFF     push    -1
   02E80016    FF15 38DD5200   call    dword ptr [52DD38] 
   02E8001C    68 00800000     push    8000
   02E80021    6A 00           push    0
   02E80023    68 0000B403     push    3B40000      (释放前8K，似乎没什么意义，应该是已经将解密后的.text复制到现在的加载地址上了，因此释放掉内存)
   02E80028    FF15 34D71900   call    dword ptr [19D734]               ; KERNEL32.VirtualFree
   02E8002E    8BE5            mov     esp, ebp
   02E80030    5D              pop     ebp
   02E80031    8BE5            mov     esp, ebp
   02E80033    5D              pop     ebp
   02E80034  - E9 F6CC58FD     jmp     gamecons.0040CD2F (OEP)
   02E80039    0000            add     byte ptr [eax], al
   ```

   

5. 此时直接dump内存中的.text，.rsrc以及3B40000对应的段以及.rsrc，同时修改3B40000加载地址为3B40000，选择重建PE转储即可。
6. 如果程序本身没有校验的话，现在应该已经可以运行了。