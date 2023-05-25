---
title: "QutsCloud 逆向笔记 - 能否在硬件平台安装qutscloud"
date: 2022-03-28
categories:
- qutscloud
---



鉴于QutsCloud相比QTS的巨大优势（硬盘自动识别，无需修改model.conf，安装后不拒绝启动，可以ssh进去打patch），虽然缺少了~~QVS虚拟机~~以及硬件转码之类的功能，还是值得尝试一下安装在裸机上面



<!--more-->

{{< toc >}}



# 1. QutsCloud如何判断



首先需要面对的是，QutsCloud是如何判断自己在虚拟化平台上运行的呢，查看hal_app的实现，可以发现它是调用virt-what来判断自己是否运行在虚拟化平台的

```c
 if ( Ini_Conf_Get_Field(a1 - 368, "v.1", "host_model", *(_QWORD *)(a1 - 648), 16LL) <= 0 )
  {
    comm_sys_read_from_popen("echo -n $(/sbin/virt-what 2>/dev/null | head -n 1)", a1 - 336, 64LL);
    if ( !*(_BYTE *)(a1 - 336) )
    {
      *(_QWORD *)(a1 - 640) = fopen64("/dev/kmsg", "r+");
      if ( *(_QWORD *)(a1 - 640) )
      {
        fwrite("---- Error: qutscloud can not run in this environment.\n", 1uLL, 0x37uLL, *(FILE **)(a1 - 640));
        fclose(*(FILE **)(a1 - 640));
      }
      sleep(1u);
      system("/sbin/hal_app --se_sys_quick_poweroff >&/dev/null");
      result = 0xFFFFFFFFLL;
      goto LABEL_74;
    }
    *(_QWORD *)(a1 - 632) = fopen64("/dev/kmsg", "r+");
    if ( *(_QWORD *)(a1 - 632) )
    {
      fprintf(*(FILE **)(a1 - 632), "---- host_model = %s\n", a1 - 336);
      fclose(*(FILE **)(a1 - 632));
    }
    Ini_Conf_Set_Field(a1 - 368, "v.1", "host_model", a1 - 336);
    snprintf(*(char **)(a1 - 648), 0x10uLL, "%s", a1 - 336);
  }
```



那么直接给virt-what打个补丁是不是就可以了呢？这就需要找个机器实际测试一下了。



# 2. 裸机安装测试



目前我没有可以用来测试的裸机，所以暂时就不测试了。

如果有哪位同学测试了，可以邮件我或者在下面的评论区（需要fq）留言，在此提前感谢！