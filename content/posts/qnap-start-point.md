---
title: "QutsCloud 逆向笔记 - 启动顺序及切入点"
date: 2022-03-23
categories:
- qutscloud
thumbnailImagePosition: "top"
thumbnailImage: /img/qnap-start-point-cover.png
typora-root-url: ..\..\static
---





本篇简要介绍qutscloud的启动过程，以及找到逆向的第一个线头，虽然很久以前就知道qnap怎么做的，不过第一次逆向的时候我确实也是这样找到线索的。

<!--more-->



{{< toc >}}



# 1. 启动脚本及内部工具介绍



## init脚本

在qutscloud安装好后，我们就可以ssh进入系统，可以看到QNAP还是沿用之前的init系统

- `init`启动脚本`/etc/init.d/rcS`
- `rcS`调用`/etc/rcS_init.d/S20init_check`
- `S20init_check`将会调用`/etc/rcS.d/`中的启动脚本



如果有兴趣的话，可以看一下其中的一些init开头的脚本

- `init_disk.sh` - 挂载硬盘
- `init_nas.sh` - 创建一些临时文件以及写系统配置
- `init_qpkg.sh` - 安装预设的qpkg
- `cs_fw_verify.sh` - 检查系统固件签名

这里不作过多分析，因为这部分需要适配很多QNAP的产品，所以零零碎碎的东西非常多，深究下去就有点头疼了，如果你的QNAP升级系统后遇到无法启动，或者硬盘不识别，或者其他卡死的bug，很有可能和这里的处理有关系。



## 后台程序以及命令行工具

- `qpkd` - 后台daemon，开机时启动预置包安装，以及在后台异步安装qpkg

- `qpkg_cli` - 安装qpkg的命令行，web调用此命令进行安装

- `cs_daemon` - 后台daemon，远程调用中心，类似RPC

- `cs_qdaemon` - 后台daemon，qcloud服务端，注册到`cs_daemon`，提供签名验证以及token检查

- `ql_daemon` - qlicense相关的daemon，它仅定时调用qlicense_tool检查license，除此之外无其他功能

- `qlicense_tool` - 管理license的命令行

- `qsh` - 调用在`cs_daemon`中服务的命令行客户端

- `cs_qpkg_verify.sh` - 验证qpkg或者qdk的签名，根据里面是否有control.tar.gz判断是qpkg还是qdk，两种格式仅有细微差别

  

## 一些配置文件

- `/etc/config/uLinux.conf` - 系统的一些基础参数配置
- `/etc/config/qid.conf` - qcloud用到的设置，device token也存在这里
- `/etc/config/qpkg.conf` - 系统安装好的qpkg会在这个文件里更新信息
- `/etc/config/nas_sign_qpkg.db` - sqlite3数据库，存储qpkg的签名，以及包内文件的签名及证书（如果有.qcodesigning目录的话）
- `/etc/config/nas_sign_fw.db` - sqlite3数据库，仅存储系统固件的签名，虽然看起来有用，但似乎没什么用
- `/etc/config/rssdoc/` - 系统下载的一些xml文件，包括app center下载的qpkg列表，固件更新信息，等等
- `/etc/config/qlicense/` - 存储授权文件证书，设备授权申请文件`(*.dif)`，授权文件`(*.lif)`，以及需要授权的产品列表文件`product_list`, 离线反激活文件`(*.luf)`不在本系列的讨论范围内
- `/tmp/tmp_app_token` - 存储加密的`access_token`，这个token访问api的时候服务器会验证，需要使用suid以及hash什么来申请，感觉没啥用
- `/tmp/tmp_suid` - 存储系统的suid，对于qutscloud，这个根据mac地址以及uuidgen随机生成出来，并且写入分区/dev/dom6的偏移7864320处，多少有点像之前硬件QNAP的序列号ID，写入之后就不再更改，可以使用命令get_suid查看，对于qutscloud，这是和mac地址唯二标记硬件的信息，qutscloud的hwsn与suid相同 **（所以请不要随意分享安装后的qutscloud镜像文件）**



## 配置中可能对调试有帮助的选项

- `/etc/config/uLinux.conf`

  - ```ini
    [System]
    proxy toggle = 1							# enable system wide proxy
    proxy server = http://[proxy server]:8888	# proxy server address
    ```

- `/etc/config/qid.conf`

  - ```ini
    [QNAP ID Service]
    PROTO = http								# select proto of api
    DEVICE_TOKEN = XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX
    HTTP_FLAG = 80682695						# enable curl debug, magic code
    ```

    

开启系统范围的代理，可以借助Fiddler来分析系统的https请求，当然也包括激活的过程

开启curl debug，则会在`/etc/logs/qid.log`下输出qlicense激活以及token更新中详细的http请求和响应

![Fidder中的请求](/img/qnap-start-point-1.png)



# 2. quick.cgi

`quick.cgi`是QNAP系统在第一次安装，或者重置系统删除所有配置后用户访问的第一个cgi程序，它在检测license后会做如下动作

- `init_NAS_disk` - 复制`/etc/config`到`/mnt/HDA_root/.config`，然后使用链接替换`/etc/config`，用以持久化配置文件
- 安装qpkg.tar，并且解压到update目录，以供系统应用更新持久化，qnap为什么启动这么慢就是因为所有的系统应用在重启后都会重新安装，而非系统应用则只是运行一个启动脚本，参考`/etc/config/qpkg.conf`中的`Alt_Shell`
- 启动安装更新后的服务，使用apache作为前置代理
- 至此`quick.cgi`对用户隐藏不见，无法再调用



现在就看看这个`quick.cgi`到底怎么检查license的，启动QutsCloud之后，访问web页面，可以明显看到，这个ui位于`cgi-bin/quick`，可以在`/home/httpd/cgi-bin/quick/`中找到它

![](/img/qnap-start-point-2.png)



继续点击页面中的`启动智能安装`，在F12中可以看到有一个请求`http://192.168.2.120:8080/cgi-bin/quick/quick.cgi?todo=have_qutscloud_installed_license&_=1648046171871`

![](/img/qnap-start-point-3.png)

这是第一个出现license相关的点，可以记下来作为参考，当然，也可以从post license key的调用着手进行逆向。

在输入框随便输入一串license后，点击`提交`可以看到post的url是`http://192.168.2.120:8080/cgi-bin/quick/quick.cgi?todo=check_qtscloud_license_key&license_key=1231231231231231231231231&region=GLB&_=1648046571322`

虽然现在没有有效的license，已经可以使用IDA尝试对quick.cgi进行逆向了



# 3. 静态分析quick.cgi



在IDA中打开`quick.cgi`，按`shift+F12`打开字符串窗口，搜索字符串`have_qutscloud_installed_license`，查找对该字符串的引用，很幸运，只有一个函数引用了这个字符串

![](/img/qnap-start-point-5.png)



进入这个函数，按`F5`生成C伪码，发现只是字符串比较，如果命中则调用`sub_40A5F4`

```c
v353 = "have_qutscloud_installed_license";
v354 = 33LL;
v355 = v5;
do
{
    if ( !v354 )
        break;
    v351 = *v355 < (const unsigned __int8)*v353;
    v352 = *v355++ == *v353++;
    --v354;
}
while ( v352 );
v356 = !v351 && !v352;
v357 = v351;
v358 = v356 < (unsigned __int8)v351;
v359 = v356 == v357;
if ( v356 == v357 )
{
    sub_40A5F4(v6, v355);
    v36 = 0;
    v119 = 1;
}
```



继续进入函数`sub_40A5F4`看看，这个函数只调用了两个内部函数，第一个显然是获取`model_type`，第二函数则以`vqtscloud`作为参数调用，很明显，就是这个函数进行了license的检查

```c
__int64 sub_40A5F4()
{
  signed int v0; // ebx@3
  __int64 v2; // [sp+0h] [bp-1038h]@1
  __int64 v3; // [sp+8h] [bp-1030h]@1
  __int64 v4; // [sp+10h] [bp-1028h]@1
  __int64 v5; // [sp+18h] [bp-1020h]@1
  int v6; // [sp+20h] [bp-1018h]@3
  char v7; // [sp+24h] [bp-1014h]@3
  char v8; // [sp+424h] [bp-C14h]@3
  char v9; // [sp+824h] [bp-814h]@3
  char v10; // [sp+C24h] [bp-414h]@3

  v2 = 0LL;
  v3 = 0LL;
  v4 = 0LL;
  v5 = 0LL;
  sub_40A4CA((char *)&v2);
  if ( strstr((const char *)&v2, "QCS") || strstr((const char *)&v2, "QVS") )
  {
    v6 = -1;
    v7 = 0;
    v8 = 0;
    v10 = 0;
    v9 = 0;
    v0 = 1;
  }
  else
  {
    sub_40A170("vqtscloud");
    v0 = 0;
  }
  printf("<platform>%s</platform>\n", &v2);
  printf("<skip_license>%d</skip_license>\n", (unsigned int)v0);
  printf("<have_license>%d</have_license>\n", v6 == 0);
  printf("<app_name>%s</app_name>\n", &v7);
  printf("<license_id>%s</license_id>\n", &v8);
  printf("<license_name>%s</license_name>\n", &v10);
  printf("<applied_date>%s</applied_date>\n", &v9);
  puts("<Result>success</Result>");
  return 0LL;
}
```



实际上，这个函数又是QNAP的传统艺能体现，调用一个cmd来看看license有没有，命令应该是` /usr/local/bin/qlicense_tool installed_list -a 'vqtscloud'`

```c
  if ( !src )
    return 0xFFFFFFFFLL;
  v3 = a2;
  strncpy((char *)(a2 + 4), src, 0x3FFuLL);
  snprintf(
    &s,
    0x202uLL,
    "%s installed_list -a '%s' 2>/dev/null | %s -r '(.code),(.result[0].license_id),(.result[0].apply_date)' 2>/dev/null",
    "/usr/local/bin/qlicense_tool",
    src,
    "/usr/local/sbin/jq");
  v4 = popen(&s, "r");
  v5 = v4;
  if ( !v4 )
  {
    snprintf(
      &s,
      0x202uLL,
      "%s installed_list -a '%s' 2>/dev/null | %s -r '(.result[0].license_info_json_str)' 2>/dev/null | %s -r '(.license_"
      "name)' 2>/dev/null",
      "/usr/local/bin/qlicense_tool",
      src,
      "/usr/local/sbin/jq",
      "/usr/local/sbin/jq");
    v25 = popen(&s, "r");
    v15 = 0;
    if ( !v25 )
      return 0LL;
LABEL_17:
    v16 = fgets(v27, 2570, v25);
```



那么这个命令到底应该输出什么？如果没有一个license在手里是很难知道的，除非对qlicense完整逆向。

不过很幸运，QNAP现在在打折，qutscloud一个月才4.9美金，感天动地。



实际上它输出的应该是lif解密后的内容

```json
qlicense_tool installed_list -a 'vqtscloud'
{
   "code": 0,
   "message": "success",
   "result": [
     {
       "id": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX",
       "dif_id": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX",
       "dif_signature": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX",
       "license_id": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX",
       "mac": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX",
       "hwsn": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX",
       "suid": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX",
       "model": "QuTScloud",
       "fw_build_version": "c5.0.0.1919",
       "license_info_json_str": "{ \"sku\": \"LS-QUTSCLOUD-1CR-1M-EI\", \"valid_until\": \"2021-02-03 04:05:06.000000\", \"app_internal_name\": \"vqtscloud\", \"valid_from\": \"2021-02-03 04:05:06.000000\", \"product_type\": \"vQTS_Cloud\", \"name\": \"QuTScloud 1 Core - 1 Month\", \"license_name\": \"QuTScloud 1 Core - 1 Month\", \"feature\": null, \"applied_at\": \"2021-02-03 04:05:06.000000\", \"categories\": [ \"vQTS_Cloud\" ], \"owner\": [ \"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX\" ], \"attributes\": { \"is_floating\": true, \"ext_check_type\": \"product.product_type\", \"aw_sarp2_is_used_advanced_pricing\": \"Use config\", \"cpu_limit\": \"1\", \"small_image_label\": \"QuTScloud 1 Core - 1 Month\", \"is_subscription\": true, \"thumbnail_label\": \"QuTScloud 1 Core - 1 Month\", \"device_type\": \"vqts_cld\", \"purchase_before_installed\": \"false\", \"external_service\": false, \"is_self_check\": true, \"product_image_size\": \"Default\", \"type\": \"device\", \"msrp_display_actual_price_type\": \"Use config\", \"grace_period_days\": \"21\", \"gift_message_available\": \"No\", \"app_internal_name\": \"vqtscloud\", \"plan_title\": \"1 Core\", \"quota_device\": \"1\", \"expiry_warning_day\": \"-1\", \"upgradeable\": true, \"immediate_activate\": true, \"product_class\": \"vQTS_Cloud\", \"amrolepermissions_owner\": \"0\", \"duration_month\": \"1\", \"app_min_version\": \"c4.4.2\", \"license_activation_info\": \"<div class=\\\"qSW-pd-desc\\\"  id=\\\"qSW-pd-detail-license\\\">\\n    \\n    <iframe class=\\\"resize_height iframe_license_activation\\\" id=\\\"iframe_license_activation\\\" src=\\\"https:\\/\\/docs.qnap.com\\/operating-system\\/qts\\/4.5.x\\/en-us\\/GUID-C6DE86F5-38A3-496E-A872-F833E1E5280D.html\\\" frameborder=\\\"0\\\" allowfullscreen=\\\"\\\" width=\\\"100%\\\" height=\\\"100%\\\" scrolling=\\\"no\\\"><\\/iframe>\\n\\n<\\/div>\", \"variant_display_name\": \"QuTScloud 1 Core - 1 Month\", \"extendable\": true, \"app_display_name\": \"QuTScloud\", \"is_perpetual\": \"false\", \"is_bundle\": false, \"transferable\": true, \"support_org\": false, \"image_label\": \"QuTScloud 1 Core - 1 Month\" }, \"app_display_name\": \"QuTScloud\", \"channel\": null, \"product_id\": \"2302\" }",
       "status": "valid",
       "subscription_status": "valid",
       "legacy": 0,
       "apply_date": "2021-02-03T04:05:06SST",
       "created_at": "2021-02-03T04:05:06+00:00",
       "remaining_days": 24,
       "api_check_date": "2021-02-03T04:05:06Z",
       "floating_uuid": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX",
       "floating_token": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX",
       "license_check_period": 43200,
       "is_partial_deactivated": 0,
       "used_seats": 1,
       "unsubscribed_used_seats": 0,
       "unsubscribed_valid_until": "",
       "api_check_status": "success"
     }
   ]
 }
```



怎么样，有没有想到什么，我们完全可以替换这个qlicense_tool，让它吐出合适的json不就可以了吗？

那事实确实如此吗？

我觉得应该是可以的，不过这个可以后面再说，关键是，如果这样就弄完了，这个系列怎么去水出那么多篇？

