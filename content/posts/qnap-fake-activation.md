---
title: "QutsCloud 逆向笔记 - 激活思路及路线选择"
date: 2022-03-26
categories:
- qutscloud
typora-root-url: ..\..\static
thumbnailImagePosition: "left"
thumbnailImage: /img/qnap-fake-activate-cover.png
---



这篇讨论一下可以选择的激活系统的方案，以及具体的实现。不过不管哪种方案，**都无法支持myQNAPcloud云服务**，因为现在许可证和用户是绑定的，登录了myQNAPcloud后也找不到可用的设备，也请**不要尝试登录QNAP ID**。

<!--more-->



tg交流群：https://t.me/qutscloud



下面每一个小节都实现了一种激活的方案，也会谈到其中可能存在的问题。


{{< alert danger no-icon>}}

！！！另外，再次声明！！！

不要尝试登录QNAP ID！

不要尝试登录QNAP ID！

不要尝试登录QNAP ID！

{{< /alert >}}



{{< toc >}}





# 1. 方案一：用脚本对qlicense_tool打patch

> 首先要说的是，patch并不是常规意义上的patch，而是hook，使用脚本替换原有的命令，使得可以劫持某些输入参数的输出，同时也可以调用原来的命令。

在之前的几篇，我们知道QutsCloud的许可证全部是由qlicense_tool管理，不论是web ui，还是周期性检查，还是ql_daemon，都是在调用qlicese_tool这个命令行。

因此第一个尝试就是对qlicense_tool进行patch，qlicense_tool有很多参数，如下所示

```
# qlicense_tool
Usage: qlicense_tool [COMMAND] [OPTIONS]...
Generate DIF / Operate Installed License / Online, Offline License Activate|Deactivate.

help               [COMMAND] If with valid COMMAND, show the help message for the command, else show this help message.
generate_dif       [OPTIONS] Please use help generate_dif to see the complete option list
print_dif          [OPTIONS] Please use help print_dif to see the complete option list
print_lif          [OPTIONS] Please use help print_lif to see the complete option list
print_luf          [OPTIONS] Please use help print_luf to see the complete option list
installed_list     [OPTIONS] Please use help installed_list to see the complete option list
installed_get      [OPTIONS] Please use help installed_get to see the complete option list
installed_get_value[OPTIONS] Please use help installed_get_value to see the complete option list
offline_activate   [OPTIONS] Please use help offline_activate to see the complete option list
offline_deactivate [OPTIONS] Please use help offline_deactivate to see the complete option list
online_list        [OPTIONS] Please use help online_list to see the complete option list
online_activate    [OPTIONS] Please use help online_activate to see the complete option list
online_deactivate  [OPTIONS] Please use help online_deactivate to see the complete option list
online_extend      [OPTIONS] Please use help online_extend to see the complete option list
online_upgrade     [OPTIONS] Please use help online_upgrade to see the complete option list
online_get         [OPTIONS] Please use help online_get to see the complete option list
extend_list        [OPTIONS] Please use help extend_list to see the complete option list
recover            [OPTIONS] Please use help recover to see the complete option list
check              [OPTIONS] Please use help check to see the complete option list
migrate            [OPTIONS] Please use help migrate to see the complete option list
get_session_id     [OPTIONS] Please use help get_session_id to see the complete option list
get_basket         [OPTIONS] Please use help get_basket to see the complete option list
get_product_list   [OPTIONS] Please use help get_product_list to see the complete option list
get_product        [OPTIONS] Please use help get_product to see the complete option list
add_product        [OPTIONS] Please use help add_product to see the complete option list
get_payment        [OPTIONS] Please use help get_payment to see the complete option list
activate_trial     [OPTIONS] Please use help activate_trial to see the complete option list
register           [OPTIONS] Please use help register to see the complete option list
unregister         [OPTIONS] Please use help unregister to see the complete option list
mark_invalid       [OPTIONS] Please use help mark_invalid to see the complete option list
floating_refresh   [OPTIONS] Please use help floating_refresh to see the complete option list
floating_unregister[OPTIONS] Please use help floating_unregister to see the complete option list
logging            [OPTIONS] Please use help logging to see the complete option list
before_activate    [OPTIONS] Please use help before_activate to see the complete option list
get_extendable_product [OPTIONS] Please use help get_extendable_product to see the complete option list
```



目前看到系统用到的命令有

- `generate_dif`
- `installed_list`
- `check`
- `online_get`
- `online_activate`
- `floating_refresh`

其中有返回值的只有`generate_dif`，`installed_list`，`online_get`，其他的命令只需要返回表示success的json就可以。

需要的这三个命令中`generate_dif`系统一般不会调用，所以可以排除，下面先写一个版本试试看

## 激活脚本（第一版）

```shell
#!/bin/bash

# 劫持域名
sed -i "s/^#conf-file=\/etc\/dnsmasq.more.conf.*\$/conf-file=\/etc\/dnsmasq.more.conf/" /etc/dnsmasq.conf
echo "address=/myqnapcloud.com/127.0.0.1" > /etc/dnsmasq.more.conf
echo "address=/myqnapcloud.cn/127.0.0.1" >> /etc/dnsmasq.more.conf
echo "address=/myqnapcloud.com.cn/127.0.0.1" >> /etc/dnsmasq.more.conf
killall dnsmasq
/sbin/dnsmasq

if ! grep "fake_qlicense_tool" /usr/local/bin/qlicense_tool 2>/dev/null >/dev/null ; then
        mv /usr/local/bin/qlicense_tool /usr/local/bin/qlicense_tool_old
        cat >/usr/local/bin/qlicense_tool <<"eof"
#!/bin/sh
# fake_qlicense_tool

online_get='
{
   "code": 0,
   "message": "success",
   "result": {
     "license_id": "111111111111111111111111",
     "license_key": "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX",
     "license_name": "QuTScloud 1 Core - 1 Month",
     "status": "valid",
     "transferable": 1,
     "is_self_check": 1,
     "is_floating": 1,
     "is_subscription": 1,
     "is_single_device_multi_seat": 0,
     "type": "device",
     "product_id": 2302,
     "product_name": "QuTScloud 1 Core - 1 Month",
     "product_type": "vQTS_Cloud",
     "app_internal_name": "vqtscloud",
     "app_display_name": "QuTScloud",
     "app_min_version": "c4.4.2",
     "available_seats": 0,
     "total_free_unsubscribed": 0,
     "duration": {
       "year": 0,
       "month": 1,
       "day": 0
     },
     "device": [
     ],
     "created_at": "2020/ 1/ 1",
     "expires_at": "2029/ 1/ 1"
   }
 }
'

installed_list='
{
   "code": 0,
   "message": "success",
   "result": [
     {
       "id": "a51345fc-e45d-4e10-b6bb-df3b647c6cd4",
       "dif_id": "a51345fc-e45d-4e10-b6bb-df3b647c6cd4",
       "dif_signature": "xxxxxxxxxxxxxxxxxxxxxx",
       "license_id": "1111111111111111111",
       "mac": "00:00:00:00:00:00",
       "hwsn": "11111111111111111111111111",
       "suid": "111111111111111111111111111",
       "model": "QuTScloud",
       "fw_build_version": "c5.0.0.1919 (20220119)",
       "license_info_json_str": "{ \"sku\": \"LS-QUTSCLOUD-1CR-1M-EI\", \"valid_until\": \"2029-01-01 00:00:00.000000\", \"app_internal_name\": \"vqtscloud\", \"valid_from\": \"2020-01-01 00:00:00.000000\", \"product_type\": \"vQTS_Cloud\", \"name\": \"QuTScloud 1 Core - 1 Month\", \"license_name\": \"QuTScloud 1 Core - 1 Month\", \"feature\": null, \"applied_at\": \"2020-01-01 00:00:00.000000\", \"categories\": [ \"vQTS_Cloud\" ], \"owner\": [ \"xxxxxxxxxxxxxxxxxxx\" ], \"attributes\": { \"is_floating\": true, \"ext_check_type\": \"product.product_type\", \"aw_sarp2_is_used_advanced_pricing\": \"Use config\", \"00cpu_limit\": \"1\", \"small_image_label\": \"QuTScloud 1 Core - 1 Month\", \"is_subscription\": true, \"thumbnail_label\": \"QuTScloud 1 Core - 1 Month\", \"device_type\": \"vqts_cld\", \"purchase_before_installed\": \"false\", \"external_service\": false, \"is_self_check\": true, \"product_image_size\": \"Default\", \"type\": \"device\", \"msrp_display_actual_price_type\": \"Use config\", \"grace_period_days\": \"21\", \"gift_message_available\": \"No\", \"app_internal_name\": \"vqtscloud\", \"plan_title\": \"1 Core\", \"quota_device\": \"1\", \"expiry_warning_day\": \"-1\", \"upgradeable\": true, \"immediate_activate\": true, \"product_class\": \"vQTS_Cloud\", \"amrolepermissions_owner\": \"0\", \"duration_month\": \"1\", \"app_min_version\": \"c4.4.2\", \"license_activation_info\": \"<div class=\\\"qSW-pd-desc\\\"  id=\\\"qSW-pd-detail-license\\\">\\n    \\n    <iframe class=\\\"resize_height iframe_license_activation\\\" id=\\\"iframe_license_activation\\\" src=\\\"https:\\/\\/docs.qnap.com\\/operating-system\\/qts\\/4.5.x\\/en-us\\/GUID-C6DE86F5-38A3-496E-A872-F833E1E5280D.html\\\" frameborder=\\\"0\\\" allowfullscreen=\\\"\\\" width=\\\"100%\\\" height=\\\"100%\\\" scrolling=\\\"no\\\"><\\/iframe>\\n\\n<\\/div>\", \"variant_display_name\": \"QuTScloud 1 Core - 1 Month\", \"extendable\": true, \"app_display_name\": \"QuTScloud\", \"is_perpetual\": \"false\", \"is_bundle\": false, \"transferable\": true, \"support_org\": false, \"image_label\": \"QuTScloud 1 Core - 1 Month\" }, \"app_display_name\": \"QuTScloud\", \"channel\": null, \"product_id\": \"2302\" }",
       "status": "valid",
       "subscription_status": "valid",
       "legacy": 0,
       "apply_date": "2020-01-01T00:00:00SST",
       "created_at": "2020-01-01T00:00:00+00:00",
       "remaining_days": 24,
       "api_check_date": "2020-01-01T00:00:00Z",
       "floating_uuid": "7067ef17-1474-4042-abd3-27584e915eaa",
       "floating_token": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
       "license_check_period": 43200,
       "is_partial_deactivated": 0,
       "used_seats": 1,
       "unsubscribed_used_seats": 0,
       "unsubscribed_valid_until": "",
       "api_check_status": "fail"
     }
   ]
 }
'


if [ "$1" == "floating_refresh" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
if [ "$1" == "online_activate" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
if [ "$1" == "check" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
if [ "$1" == "floating_refresh" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
if [ "$1" == "installed_list" ] ; then
 echo "$installed_list"
 exit 0
fi
if [ "$1" == "online_get" ] ; then
 echo "$online_get"
 exit 0
fi
/usr/local/bin/qlicense_tool_old $@
eof

	chmod a+x /usr/local/bin/qlicense_tool
fi  # end of: if ! grep "fake_qlicense_tool"
```

其实我觉得里面很多都是不做验证的，要的其实只是license_info_json_str中的东西，所以没有必要写这么多，不过我也没功夫去缩减，差不多可以也就行了。

打开网页刷新一下看看

![](/img/qnap-fake-activate-1.png)



发现已经找到了许可证，再点一下安装看看呢，好像可以进入下一步了

![](/img/qnap-fake-activate-2.png)



![](/img/qnap-fake-activate-3.png)



貌似一直卡在安装的地方了，一直不动，检查一下qlicense_tool，发现已经被LicenseCenter的版本覆盖了，顺手改了回去。

等了一会之后，发现安装完成了，可以使用设置的用户名密码登录了，应该是更新的qlicense_tool生效了

因为LicenseCenter启动的脚本会调用`/etc/init.d/QDevelop.sh`，所以我们可以把修改的操作写到这个脚本，让qlicense_tool更新后也可以被patch，这样就不用守着安装进程来patch

```shell
function do_restart_qdevelop() {
    # restart qdevelop for using different site key pair
    if [ -f "/etc/init.d/QDevelop.sh" ]; then
        /etc/init.d/QDevelop.sh restart &> /dev/null
    fi
}
```



更新一下刚才的脚本再试试看

## 激活脚本（第二版）

```shell
#!/bin/bash

# 劫持域名
sed -i "s/^#conf-file=\/etc\/dnsmasq.more.conf.*\$/conf-file=\/etc\/dnsmasq.more.conf/" /etc/dnsmasq.conf
echo "address=/myqnapcloud.com/127.0.0.1" > /etc/dnsmasq.more.conf
echo "address=/myqnapcloud.cn/127.0.0.1" >> /etc/dnsmasq.more.conf
echo "address=/myqnapcloud.com.cn/127.0.0.1" >> /etc/dnsmasq.more.conf
killall dnsmasq
/sbin/dnsmasq

cat > /etc/init.d/QDevelop.sh <<"EOF"
if ! grep "fake_qlicense_tool" /usr/local/bin/qlicense_tool 2>/dev/null >/dev/null ; then
        mv /usr/local/bin/qlicense_tool /usr/local/bin/qlicense_tool_old
        cat >/usr/local/bin/qlicense_tool <<"eof"
#!/bin/sh
# fake_qlicense_tool

online_get='
{
   "code": 0,
   "message": "success",
   "result": {
     "license_id": "111111111111111111111111",
     "license_key": "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX",
     "license_name": "QuTScloud 1 Core - 1 Month",
     "status": "valid",
     "transferable": 1,
     "is_self_check": 1,
     "is_floating": 1,
     "is_subscription": 1,
     "is_single_device_multi_seat": 0,
     "type": "device",
     "product_id": 2302,
     "product_name": "QuTScloud 1 Core - 1 Month",
     "product_type": "vQTS_Cloud",
     "app_internal_name": "vqtscloud",
     "app_display_name": "QuTScloud",
     "app_min_version": "c4.4.2",
     "available_seats": 0,
     "total_free_unsubscribed": 0,
     "duration": {
       "year": 0,
       "month": 1,
       "day": 0
     },
     "device": [
     ],
     "created_at": "2020/ 1/ 1",
     "expires_at": "2029/ 1/ 1"
   }
 }
'

installed_list='
{
   "code": 0,
   "message": "success",
   "result": [
     {
       "id": "a51345fc-e45d-4e10-b6bb-df3b647c6cd4",
       "dif_id": "a51345fc-e45d-4e10-b6bb-df3b647c6cd4",
       "dif_signature": "xxxxxxxxxxxxxxxxxxxxxx",
       "license_id": "1111111111111111111",
       "mac": "00:00:00:00:00:00",
       "hwsn": "11111111111111111111111111",
       "suid": "111111111111111111111111111",
       "model": "QuTScloud",
       "fw_build_version": "c5.0.0.1919 (20220119)",
       "license_info_json_str": "{ \"sku\": \"LS-QUTSCLOUD-1CR-1M-EI\", \"valid_until\": \"2029-01-01 00:00:00.000000\", \"app_internal_name\": \"vqtscloud\", \"valid_from\": \"2020-01-01 00:00:00.000000\", \"product_type\": \"vQTS_Cloud\", \"name\": \"QuTScloud 1 Core - 1 Month\", \"license_name\": \"QuTScloud 1 Core - 1 Month\", \"feature\": null, \"applied_at\": \"2020-01-01 00:00:00.000000\", \"categories\": [ \"vQTS_Cloud\" ], \"owner\": [ \"xxxxxxxxxxxxxxxxxxx\" ], \"attributes\": { \"is_floating\": true, \"ext_check_type\": \"product.product_type\", \"aw_sarp2_is_used_advanced_pricing\": \"Use config\", \"00cpu_limit\": \"1\", \"small_image_label\": \"QuTScloud 1 Core - 1 Month\", \"is_subscription\": true, \"thumbnail_label\": \"QuTScloud 1 Core - 1 Month\", \"device_type\": \"vqts_cld\", \"purchase_before_installed\": \"false\", \"external_service\": false, \"is_self_check\": true, \"product_image_size\": \"Default\", \"type\": \"device\", \"msrp_display_actual_price_type\": \"Use config\", \"grace_period_days\": \"21\", \"gift_message_available\": \"No\", \"app_internal_name\": \"vqtscloud\", \"plan_title\": \"1 Core\", \"quota_device\": \"1\", \"expiry_warning_day\": \"-1\", \"upgradeable\": true, \"immediate_activate\": true, \"product_class\": \"vQTS_Cloud\", \"amrolepermissions_owner\": \"0\", \"duration_month\": \"1\", \"app_min_version\": \"c4.4.2\", \"license_activation_info\": \"<div class=\\\"qSW-pd-desc\\\"  id=\\\"qSW-pd-detail-license\\\">\\n    \\n    <iframe class=\\\"resize_height iframe_license_activation\\\" id=\\\"iframe_license_activation\\\" src=\\\"https:\\/\\/docs.qnap.com\\/operating-system\\/qts\\/4.5.x\\/en-us\\/GUID-C6DE86F5-38A3-496E-A872-F833E1E5280D.html\\\" frameborder=\\\"0\\\" allowfullscreen=\\\"\\\" width=\\\"100%\\\" height=\\\"100%\\\" scrolling=\\\"no\\\"><\\/iframe>\\n\\n<\\/div>\", \"variant_display_name\": \"QuTScloud 1 Core - 1 Month\", \"extendable\": true, \"app_display_name\": \"QuTScloud\", \"is_perpetual\": \"false\", \"is_bundle\": false, \"transferable\": true, \"support_org\": false, \"image_label\": \"QuTScloud 1 Core - 1 Month\" }, \"app_display_name\": \"QuTScloud\", \"channel\": null, \"product_id\": \"2302\" }",
       "status": "valid",
       "subscription_status": "valid",
       "legacy": 0,
       "apply_date": "2020-01-01T00:00:00SST",
       "created_at": "2020-01-01T00:00:00+00:00",
       "remaining_days": 24,
       "api_check_date": "2020-01-01T00:00:00Z",
       "floating_uuid": "7067ef17-1474-4042-abd3-27584e915eaa",
       "floating_token": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
       "license_check_period": 43200,
       "is_partial_deactivated": 0,
       "used_seats": 1,
       "unsubscribed_used_seats": 0,
       "unsubscribed_valid_until": "",
       "api_check_status": "fail"
     }
   ]
 }
'


if [ "$1" == "floating_refresh" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
if [ "$1" == "online_activate" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
if [ "$1" == "check" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
if [ "$1" == "floating_refresh" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
if [ "$1" == "installed_list" ] ; then
 echo "$installed_list"
 exit 0
fi
if [ "$1" == "online_get" ] ; then
 echo "$online_get"
 exit 0
fi
/usr/local/bin/qlicense_tool_old $@
eof

	chmod a+x /usr/local/bin/qlicense_tool
fi  # end of: if ! grep "fake_qlicense_tool"

# 延迟调用两次
if [ "$1" != "replace_ql" ]; then
    (sleep 1 && sh /etc/init.d/QDevelop.sh replace_ql)&
    (sleep 5 && sh /etc/init.d/QDevelop.sh replace_ql)&
fi
EOF

chmod a+x /etc/init.d/QDevelop.sh
/etc/init.d/QDevelop.sh


```

![](/img/qnap-fake-activate-4.png)



webui一直显示未找到许可证，看一下F12，原来是一个新的cgi会去寻找license

```
Request URL: http://192.168.2.120:8080/cgi-bin/qid/qlicenseRequest.cgi?sid=7rmjqsro&cmd=get_installed_license_list&_dc=1648320931779
Request Method: GET
```

而且这个程序链接了`libqlicense.so`库，瞬间又啪啪啪打脸了

```
[/home/httpd/cgi-bin/qid] # ldd qlicenseRequest.cgi
        linux-vdso.so.1 (0x00007fff0cdcd000)
        libuLinux_NAS.so.0 => /usr/lib/libuLinux_NAS.so.0 (0x00007f3011f25000)
        libuLinux_cgi.so.0 => /usr/lib/libuLinux_cgi.so.0 (0x00007f3011d13000)
        libuLinux_nasauth.so.1 => /usr/lib/libuLinux_nasauth.so.1 (0x00007f3011b10000)
        libqlicense.so => /mnt/ext/opt/LicenseCenter/lib/libqlicense.so (0x00007f30118c9
        ...
```

要不把这个也打上patch，写个脚本试试看

## 激活脚本（第三版，最终版？）

```shell
#!/bin/bash

# 劫持域名
sed -i "s/^#conf-file=\/etc\/dnsmasq.more.conf.*\$/conf-file=\/etc\/dnsmasq.more.conf/" /etc/dnsmasq.conf
echo "address=/myqnapcloud.com/127.0.0.1" > /etc/dnsmasq.more.conf
echo "address=/myqnapcloud.cn/127.0.0.1" >> /etc/dnsmasq.more.conf
echo "address=/myqnapcloud.com.cn/127.0.0.1" >> /etc/dnsmasq.more.conf
killall dnsmasq
/sbin/dnsmasq

cat > /etc/init.d/QDevelop.sh <<"EOF"
# patch qlicenseRequest.cgi
if ! grep "fake_qlicense_tool" /home/httpd/cgi-bin/qid/qlicenseRequest.cgi 2>/dev/null >/dev/null ; then
        mv /home/httpd/cgi-bin/qid/qlicenseRequest.cgi /home/httpd/cgi-bin/qid/qlicenseRequest.cgi.old
        cat >/home/httpd/cgi-bin/qid/qlicenseRequest.cgi <<"eof"
#!/bin/sh
# fake_qlicense_tool
if echo $QUERY_STRING |grep get_installed_license_list 2>/dev/null >/dev/null ; then
    echo -n 'Content-type: application/json; charset="UTF-8"'
    printf "\n\n"
	echo '{
   "code": 0,
   "message": "success",
   "total_count": 1,
   "result": [
     {
       "id": "a51345fc-e45d-4e10-b6bb-df3b647c6cd4",
       "dif_id": "a51345fc-e45d-4e10-b6bb-df3b647c6cd4",
       "dif_signature": "xxxxxxxxxxxxxxxxxxxxxx",
       "license_id": "1111111111111111111",
       "status": "valid",
       "subscription_status": "valid",
       "legacy": 0,
       "apply_date": "2020-01-01T00:00:00SST",
       "created_at": "2020-01-01T00:00:00+00:00",
       "remaining_days": 100,
       "api_check_date": "2020-01-01T00:00:00Z",
       "is_partial_deactivated": 0,
       "used_seats": 1,
       "unsubscribed_used_seats": 0,
       "unsubscribed_valid_until": "",
       "api_check_status": "success",
       "hw_info": {
         "mac": "00:00:00:00:00:00",
         "hwsn": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
         "suid": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
         "model": "QuTScloud"
       },
       "license_info": {
         "sku": "LS-QUTSCLOUD-1CR-1M-EI",
         "valid_until": "2029-01-01 00:00:00.000000",
         "app_internal_name": "vqtscloud",
         "valid_from": "2020-01-01 00:00:00.000000",
         "product_type": "vQTS_Cloud",
         "name": "QuTScloud 1 Core - 1 Month",
         "license_name": "QuTScloud 1 Core - 1 Month",
         "feature": null,
         "applied_at": "2020-01-01 00:00:00.000000",
         "categories": [
           "vQTS_Cloud"
         ],
         "owner": [
           "xxxxxxxxxxxxxxxxxxx"
         ],
         "attributes": {
           "is_floating": true,
           "ext_check_type": "product.product_type",
           "aw_sarp2_is_used_advanced_pricing": "Use config",
           "cpu_limit": "1",
           "small_image_label": "QuTScloud 1 Core - 1 Month",
           "is_subscription": true,
           "thumbnail_label": "QuTScloud 1 Core - 1 Month",
           "device_type": "vqts_cld",
           "purchase_before_installed": "false",
           "external_service": false,
           "is_self_check": true,
           "product_image_size": "Default",
           "type": "device",
           "msrp_display_actual_price_type": "Use config",
           "grace_period_days": "21",
           "gift_message_available": "No",
           "app_internal_name": "vqtscloud",
           "plan_title": "1 Core",
           "quota_device": "1",
           "expiry_warning_day": "-1",
           "upgradeable": true,
           "immediate_activate": true,
           "product_class": "vQTS_Cloud",
           "amrolepermissions_owner": "0",
           "duration_month": "1",
           "app_min_version": "c4.4.2",
           "license_activation_info": "<div class=\"qSW-pd-desc\"  id=\"qSW-pd-detail-license\">\n    \n    <iframe class=\"resize_height iframe_license_activation\" id=\"iframe_license_activation\" src=\"https://docs.qnap.com/operating-system/qts/4.5.x/en-us/GUID-C6DE86F5-38A3-496E-A872-F833E1E5280D.html\" frameborder=\"0\" allowfullscreen=\"\" width=\"100%\" height=\"100%\" scrolling=\"no\"></iframe>\n\n</div>",
           "variant_display_name": "QuTScloud 1 Core - 1 Month",
           "extendable": true,
           "app_display_name": "QuTScloud",
           "is_perpetual": "false",
           "is_bundle": false,
           "transferable": true,
           "support_org": false,
           "image_label": "QuTScloud 1 Core - 1 Month"
         },
         "app_display_name": "QuTScloud",
         "channel": null,
         "product_id": "2302"
       }
     }
   ]
 }'
	exit 0
fi
/home/httpd/cgi-bin/qid/qlicenseRequest.cgi.old
eof
chmod a+x /home/httpd/cgi-bin/qid/qlicenseRequest.cgi
fi 

# patch qlicense_tool
if ! grep "fake_qlicense_tool" /usr/local/bin/qlicense_tool 2>/dev/null >/dev/null ; then
        mv /usr/local/bin/qlicense_tool /usr/local/bin/qlicense_tool_old
        cat >/usr/local/bin/qlicense_tool <<"eof"
#!/bin/sh
# fake_qlicense_tool

online_get='
{
   "code": 0,
   "message": "success",
   "result": {
     "license_id": "111111111111111111111111",
     "license_key": "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX",
     "license_name": "QuTScloud 1 Core - 1 Month",
     "status": "valid",
     "transferable": 1,
     "is_self_check": 1,
     "is_floating": 1,
     "is_subscription": 1,
     "is_single_device_multi_seat": 0,
     "type": "device",
     "product_id": 2302,
     "product_name": "QuTScloud 1 Core - 1 Month",
     "product_type": "vQTS_Cloud",
     "app_internal_name": "vqtscloud",
     "app_display_name": "QuTScloud",
     "app_min_version": "c4.4.2",
     "available_seats": 0,
     "total_free_unsubscribed": 0,
     "duration": {
       "year": 0,
       "month": 1,
       "day": 0
     },
     "device": [
     ],
     "created_at": "2020/ 1/ 1",
     "expires_at": "2029/ 1/ 1"
   }
 }
'

installed_list='
{
   "code": 0,
   "message": "success",
   "result": [
     {
       "id": "a51345fc-e45d-4e10-b6bb-df3b647c6cd4",
       "dif_id": "a51345fc-e45d-4e10-b6bb-df3b647c6cd4",
       "dif_signature": "xxxxxxxxxxxxxxxxxxxxxx",
       "license_id": "1111111111111111111",
       "mac": "00:00:00:00:00:00",
       "hwsn": "11111111111111111111111111",
       "suid": "111111111111111111111111111",
       "model": "QuTScloud",
       "fw_build_version": "c5.0.0.1919 (20220119)",
       "license_info_json_str": "{ \"sku\": \"LS-QUTSCLOUD-1CR-1M-EI\", \"valid_until\": \"2029-01-01 00:00:00.000000\", \"app_internal_name\": \"vqtscloud\", \"valid_from\": \"2020-01-01 00:00:00.000000\", \"product_type\": \"vQTS_Cloud\", \"name\": \"QuTScloud 1 Core - 1 Month\", \"license_name\": \"QuTScloud 1 Core - 1 Month\", \"feature\": null, \"applied_at\": \"2020-01-01 00:00:00.000000\", \"categories\": [ \"vQTS_Cloud\" ], \"owner\": [ \"xxxxxxxxxxxxxxxxxxx\" ], \"attributes\": { \"is_floating\": true, \"ext_check_type\": \"product.product_type\", \"aw_sarp2_is_used_advanced_pricing\": \"Use config\", \"00cpu_limit\": \"1\", \"small_image_label\": \"QuTScloud 1 Core - 1 Month\", \"is_subscription\": true, \"thumbnail_label\": \"QuTScloud 1 Core - 1 Month\", \"device_type\": \"vqts_cld\", \"purchase_before_installed\": \"false\", \"external_service\": false, \"is_self_check\": true, \"product_image_size\": \"Default\", \"type\": \"device\", \"msrp_display_actual_price_type\": \"Use config\", \"grace_period_days\": \"21\", \"gift_message_available\": \"No\", \"app_internal_name\": \"vqtscloud\", \"plan_title\": \"1 Core\", \"quota_device\": \"1\", \"expiry_warning_day\": \"-1\", \"upgradeable\": true, \"immediate_activate\": true, \"product_class\": \"vQTS_Cloud\", \"amrolepermissions_owner\": \"0\", \"duration_month\": \"1\", \"app_min_version\": \"c4.4.2\", \"license_activation_info\": \"<div class=\\\"qSW-pd-desc\\\"  id=\\\"qSW-pd-detail-license\\\">\\n    \\n    <iframe class=\\\"resize_height iframe_license_activation\\\" id=\\\"iframe_license_activation\\\" src=\\\"https:\\/\\/docs.qnap.com\\/operating-system\\/qts\\/4.5.x\\/en-us\\/GUID-C6DE86F5-38A3-496E-A872-F833E1E5280D.html\\\" frameborder=\\\"0\\\" allowfullscreen=\\\"\\\" width=\\\"100%\\\" height=\\\"100%\\\" scrolling=\\\"no\\\"><\\/iframe>\\n\\n<\\/div>\", \"variant_display_name\": \"QuTScloud 1 Core - 1 Month\", \"extendable\": true, \"app_display_name\": \"QuTScloud\", \"is_perpetual\": \"false\", \"is_bundle\": false, \"transferable\": true, \"support_org\": false, \"image_label\": \"QuTScloud 1 Core - 1 Month\" }, \"app_display_name\": \"QuTScloud\", \"channel\": null, \"product_id\": \"2302\" }",
       "status": "valid",
       "subscription_status": "valid",
       "legacy": 0,
       "apply_date": "2020-01-01T00:00:00SST",
       "created_at": "2020-01-01T00:00:00+00:00",
       "remaining_days": 24,
       "api_check_date": "2020-01-01T00:00:00Z",
       "floating_uuid": "7067ef17-1474-4042-abd3-27584e915eaa",
       "floating_token": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
       "license_check_period": 43200,
       "is_partial_deactivated": 0,
       "used_seats": 1,
       "unsubscribed_used_seats": 0,
       "unsubscribed_valid_until": "",
       "api_check_status": "fail"
     }
   ]
 }
'


if [ "$1" == "floating_refresh" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
if [ "$1" == "online_activate" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
if [ "$1" == "check" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
if [ "$1" == "floating_refresh" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
if [ "$1" == "installed_list" ] ; then
 echo "$installed_list"
 exit 0
fi
if [ "$1" == "online_get" ] ; then
 echo "$online_get"
 exit 0
fi
/usr/local/bin/qlicense_tool_old $@
eof

	chmod a+x /usr/local/bin/qlicense_tool
fi  # end of: if ! grep "fake_qlicense_tool"

# 延迟调用两次
if [ "$1" != "replace_ql" ]; then
    (sleep 1 && sh /etc/init.d/QDevelop.sh replace_ql)&
    (sleep 5 && sh /etc/init.d/QDevelop.sh replace_ql)&
fi
EOF
chmod a+x /etc/init.d/QDevelop.sh
/etc/init.d/QDevelop.sh



```

这下，看起来似乎是真的正常了，而且弹出窗口要建立存储池

![](/img/qnap-fake-activate-5.png)





新增一个静态卷后，等大概五分钟，文件系统也都创建好了，至于为什么这么慢，好像是因为要等待mdadm以及drdb初始化啥的，后台一直在刷新状态等待

![](/img/qnap-fake-activate-6.png)





## 问题

- 还有`storage_util`尚未处理，qlicense在许可证发生变化的时候会调用此命令来修改系统支持的功能，不过目前看好像并不影响实际使用，应该只有证书失效的时候才会调用，后面再看看
- patch系统文件之后，可能会提示系统被篡改，这是因为安装LicenseCenter的时候添加了一些文件的签名到系统数据库中，可以在脚本中删除这些sqlite中的数据项，这个同样没什么影响，系统只是会隔一段时间提醒你要重启，关掉不管也不会发生什么事情，总共就5个文件被签名了，不过我们修改的文件并不在这些路径上，所以应该没关系吧？

![](/img/qnap-fake-activate-7.png)





# 2. 方案二：注入密钥及签发许可证

在上一篇中，我们已经可以自己随意给系统签发许可证了，所以，在这个方案里，只需要为自己签发一个许可证就可以了。

需要注意的是，因为在脱离服务器连接后，无法对许可证进行floating refresh，因此还是需要对qlicense_tool打patch，让它执行floating refresh的时候返回成功。

这里实现的脚本还是用到了`/etc/init.d/QDevelop.sh`来替换系统密钥，为了方便起见，这里使用提前生成好的证书，方便自己手动再签发许可证。



## 激活脚本

```shell
#!/bin/sh
# 劫持域名
sed -i "s/^#conf-file=\/etc\/dnsmasq.more.conf.*\$/conf-file=\/etc\/dnsmasq.more.conf/" /etc/dnsmasq.conf
echo "address=/myqnapcloud.com/127.0.0.1" > /etc/dnsmasq.more.conf
echo "address=/myqnapcloud.cn/127.0.0.1" >> /etc/dnsmasq.more.conf
echo "address=/myqnapcloud.com.cn/127.0.0.1" >> /etc/dnsmasq.more.conf
killall dnsmasq
/sbin/dnsmasq

exec 2>/dev/null

# 1. 替换密钥
#openssl ecparam  -name secp384r1 -genkey -out key.pem
#openssl ec -in key.pem -pubout -out public.pem

echo "===>replace init script"
cat > /etc/init.d/QDevelop.sh <<"EOF"
cat > /etc/config/qlicense/qlicense_private_key.pem<<eof
-----BEGIN EC PARAMETERS-----
BgUrgQQAIg==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MIGkAgEBBDCwGh6rxUT1P7mxIyJV49gN4v3wA0IVx88m5qJA/IoBC2Sdvze9haRf
J3sqj7jans6gBwYFK4EEACKhZANiAAQOzny0UleWCmZPYNFZ5nSdSy1mZwmG2YHm
8Y+2376R0Q9VyjzU9NHxE8QpBA4EP9MwqYi/kekqO0ry6ht4hREHZNmYl7IXcQIQ
49OlNuIHpz5YpiEktw+o+q2lU8HU0fQ=
-----END EC PRIVATE KEY-----
eof

cat > /etc/config/qlicense/qlicense_public_key.pem<<eof
-----BEGIN PUBLIC KEY-----
MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAEDs58tFJXlgpmT2DRWeZ0nUstZmcJhtmB
5vGPtt++kdEPVco81PTR8RPEKQQOBD/TMKmIv5HpKjtK8uobeIURB2TZmJeyF3EC
EOPTpTbiB6c+WKYhJLcPqPqtpVPB1NH0
-----END PUBLIC KEY-----
eof

if ! grep "fake_qlicense_tool" /usr/local/bin/qlicense_tool 2>/dev/null >/dev/null ; then
        mv /usr/local/bin/qlicense_tool /usr/local/bin/qlicense_tool_old
        cat >/usr/local/bin/qlicense_tool <<"eof"
#!/bin/sh
# fake_qlicense_tool

if [ "$1" == "floating_refresh" -o "$1" == "local_check" ] ; then
 echo '{"code": 0, "message": "success"}'
 exit 0
fi
/usr/local/bin/qlicense_tool_old $@
eof
chmod a+x /usr/local/bin/qlicense_tool
fi

if [ "$1" != "replace_ql" ];then
    # run me again after 1s to overwrite qlicense_tool
	(sleep 1 && sh /etc/init.d/QDevelop.sh replace_ql)&
	(sleep 5 && sh /etc/init.d/QDevelop.sh replace_ql)&
fi

EOF

chmod a+x /etc/init.d/QDevelop.sh
/etc/init.d/QDevelop.sh

# 2. 生成dif并读取

echo "===>generate dif"
mkdir /mnt/.fake_active
cd /mnt/.fake_active

rm -rf *.lif *.dif dif.* lif.*

qlicense_tool generate_dif > dif.info
dif_path=`jq -r .result dif.info`

dif_data=`jq -r .data $dif_path`
dif_nonce=`jq -r .nonce $dif_path`
dif_sign=`jq -r .signature $dif_path`

echo -n "$dif_data" | openssl enc -base64 -d -A | openssl enc -d -aes-256-cbc -md md5 -k $dif_nonce -salt -out dif.json

dif_id=`jq -r .id dif.json`
hw_info=`jq -r .hw_info dif.json`

# 3. 生成lif
echo "===>generate lif"

license_id=`uuidgen -t | tr -d "-" | head -c 24`
cat > lif.json<<eof
{
    "created_at": "$(date -d "1 hour" +"%Y-%m-%dT%H:%M:%S%z")",
    "dif_id": "$dif_id",
    "dif_signature": "$dif_sign",
    "license_id": "$license_id",
    "license_info": {
        "sku": "LS-QUTSCLOUD-NO-LIMIT",
        "valid_until": "None",
        "app_internal_name": "vqtscloud",
        "valid_from": "2020-01-02 03:04:05.000000",
        "product_type": "vQTS_Cloud",
        "name": "QuTScloud",
        "license_name": "QuTScloud No Limit",
        "feature": null,
        "applied_at": "2020-01-02 03:04:05.000000",
        "categories": [
            "vQTS_Cloud"
        ],
        "owner": [
			"000000000000000000000000"
        ],
        "attributes": {
            "is_floating": false,
            "ext_check_type": "product.product_type",
            "aw_sarp2_is_used_advanced_pricing": "Use config",
            "cpu_limit": "100",
            "small_image_label": "QuTScloud No Limit",
            "is_subscription": true,
            "thumbnail_label": "QuTScloud No Limit",
            "device_type": "vqts_cld",
            "purchase_before_installed": "false",
            "external_service": false,
            "is_self_check": true,
            "product_image_size": "Default",
            "type": "device",
            "msrp_display_actual_price_type": "Use config",
            "grace_period_days": "21",
            "gift_message_available": "No",
            "app_internal_name": "vqtscloud",
            "plan_title": "No Limit",
            "quota_device": "1",
            "expiry_warning_day": "-1",
            "upgradeable": true,
            "immediate_activate": true,
            "product_class": "vQTS_Cloud",
            "amrolepermissions_owner": "0",
            "duration_month": "1",
            "app_min_version": "c4.4.2",
            "license_activation_info": "<div class=\"qSW-pd-desc\"  id=\"qSW-pd-detail-license\">\n    \n    <iframe class=\"resize_height iframe_license_activation\" id=\"iframe_license_activation\" src=\"https://docs.qnap.com/operating-system/qts/4.5.x/en-us/GUID-C6DE86F5-38A3-496E-A872-F833E1E5280D.html\" frameborder=\"0\" allowfullscreen=\"\" width=\"100%\" height=\"100%\" scrolling=\"no\"></iframe>\n\n</div>",
            "variant_display_name": "QuTScloud No Limit",
            "extendable": true,
            "app_display_name": "QuTScloud",
            "is_perpetual": "false",
            "is_bundle": false,
            "transferable": true,
            "support_org": false,
            "image_label": "QuTScloud No Limit"
        },
        "app_display_name": "QuTScloud",
        "channel": null,
        "product_id": "2302"
    },
    "id": "$lif_id",
    "hw_info": $hw_info
}
eof

uuid=`uuidgen`
openssl enc -e -aes-256-cbc -md md5  -in lif.json -k $uuid -salt -out lif.data
openssl dgst -sha256 -sign /etc/config/qlicense/qlicense_private_key.pem lif.data > lif.sign

lif_data=`openssl enc -base64 -e -in lif.data -A`
lif_sign=`openssl enc -base64 -e -in lif.sign -A`

cat >$license_id.lif<<eof
{
    "nonce": "$uuid", 
    "data": "$lif_data", 
    "signature": "$lif_sign"
}
eof

# 4.注册lif
qlicense offline_activate -p `pwd`/$license_id.lif

```



## 问题

这个方案存在的问题是

- 仍然需要给qlicense_tool打patch以支持floating_refresh
- 由于屏蔽了myQNAPcloud的域名，导致product_list也无法获取，虽然这个感觉没啥用，不过没有下载的话，app center里面需要购买许可证的app不会显示需要购买许可证，看起来和正版的系统不一样心里总有点不平衡
- 不知道太久不做floating_refresh系统是否会报错，或者需要离线更新证书，目前没有看到有这种情况，系统文件也似乎没有处理floating过期的逻辑，不过cgi我大部分没有逆向，讲不定cgi里面有





# 3. 方案三：架设license manager 服务器



请参考这篇==> [【番外】史上最简单安装QutsCloud的办法 ]({{< ref "qnap-simple-install.md" >}})

