---
title: "QutsCloud 逆向笔记 - qlicense设备标识文件及许可证文件"
date: 2022-03-25
categories:
- qutscloud
thumbnailImagePosition: "top"
thumbnailImage: /img/qnap-license-cover.png
typora-root-url: ..\..\static
---



QutsCloud以及app center都是一套license系统，所以知道了怎么生成license之后理论上app center 里面需要购买的app也可以激活。

本篇介绍QNAP的license结构，如何解密license，以及如何生成一个系统可以接受的license。

<!--more-->



{{< toc >}}



tg交流群：https://t.me/qutscloud



术语：

- `license manager` ：QNAP的license manager页面功能，由远程服务器提供
- `dif`：设备标识文件，每个机器上面每次生成的都是不一样的，用来生成lif，激活后与lif形成一一对应
- `lif`：许可证文件，与dif一起保存于系统中，为系统提供授权的许可



# 1. license激活流程

## 在线激活流程

当在QNAP软件商店购买软件后，QNAP的license manager 会为购买的授权生成一个序列号，在QTS的许可证中心可以输入此序列号添加许可证到本机

![](/img/qnap-license-1.png)



许可证中心会调用qlicense_tool对此序列号验证，并且从QNAP license manager下载许可证文件，具体的操作差不多像下面这样

- 调用web api验证序列号有效
- 上传生成的dif设备标识文件
- 下载许可证文件lif
- 激活许可证

实际调用的命令是下面这样子

- `qlicense_tool online_get -k [license key]` - 检查序列号是不是有效
- `qlicense_tool online_activate -k [license key]` - 激活序列号，包含了上传dif以及下载lif

其中调用的api为，具体的调用参数以及返回值，在后面的小节中会分析

- `GET https://license.api.myqnapcloud.cn/v1.0/license/license_key_info?license_key=XXXXXXXXXX`
- `POST https://license.api.myqnapcloud.cn/v1.1/license/[License ID]/activation`
- `GET https://license.api.myqnapcloud.cn/v1.2/license/[随机值]/download_pkg?license_key=XXXXXXXXXXXXXXX`

qutscloud默认都是用在线激活，在启动的页面也只有输入license key的地方，没有地方下载设备标识文件，也没有上传许可证文件的地方，甚至license manager 也没有上传dif的地方。

## 离线激活流程

不过app center的其他的app提供离线激活的方式，在许可证中心可以看到，脱机激活则是将dif用base64编码到url中，然后QNAP的license manager就会提示下载对应授权的lif文件

![](/img/qnap-license-4.png)



点击Generate Activation URL后，会打开一个新的网页，url为

`https://license.qnap.com/#/my_license?device_name=[DEVICE NAME]&dif=[BASE64 encode dif]`

![](/img/qnap-license-3.png)

该网页提供授权的列表，点击激活就可以下载使用dif激活的lif文件

![](/img/qnap-license-2.png)

上传下载的lif文件到许可证中心就把这个许可添加到系统里了

对应执行的命令则是：

- `qlicense_tool generate_dif` - 生成 dif 设备标识文件，并打印路径

  - ```json
    # qlicense_tool generate_dif
    {"code": 0, "message": "success", "result": "/etc/config/qlicense/dif/unused/28f4574d-5c7d-4fc1-82bb-e45653518b64.dif"}
    
    ```

- `qlicense_tool offline_activation -p [lif path] ` - 在系统中激活lif文件，成功就只打印个success

  - ```json
    {"code": 0, "message": "success" }
    ```




## dif, lif 文件格式

从激活的流程可以看，dif和lif是激活许可的关键文件

- `dif` - 系统根据当前系统信息及时间加密生成的一个设备标识文件，license manager根据dif生成对应授权的lif文件后，即会把该授权绑定在这个设备上

  - ```json
    // dif 文件中的内容
    {
        "nonce": "93995d89-aadd-495f-b00b-e344e4a63a7c",  //<-随机生成的uuid
        "app_id": "0vi23432423egfdsscwklkjdw23s9001",  //<-固定值
        "data": "BASE64编码后的本体", 
        "signature": "BASE64编码的签名"
    }
    ```

  - ```json
    // data解密后的内容
    {
        "id": "9d7f4699-2419-4f51-a5eb-8867c3cb7dd0",	// <- 随机生成
        "device_id": "", 
        "device_type": "VQTS_CLD", 
        "inode": "13374", 			// dif在文件系统中的inode，防止文件被替换
        "created_at": "2020-01-02T03:04:05Z", 
        "floating_uuid": "a220ce32-5d0f-4cda-a7d5-0ef8891898b3", 
        "floating_token": "xxxxxxxxxxxxxxxxxxx", 
        "hw_info": {
            "mac": "XXXXXXXXXX", 
            "hwsn": "I[suid]", 
            "suid": "[suid]", 
            "model": "QuTScloud", 
            "fw_build_version": "c5.0.0.1919 (20220119)", 
            "device_hostname": "[device name]"
        }
    }
    ```

- `lif` - license manager 根据dif里的信息以及用户现有的授权，生成lif文件，这个文件里面包含了dif里的设备信息以及许可证信息

  - ```json
    // lif中的内容，格式与dif一样，但是没有app id了
    {
        "nonce": "93995d89-aadd-495f-b00b-e344e4a63a7c",  //<-随机生成的uuid
        "data": "BASE64编码后的本体", 
        "signature": "BASE64编码的签名"
    }
    ```

  - ```json
    // data解密后的内容
    {
        "license_check_period": 43200,
        "floating_token": "xxxxxxxxxxxxxxxxxx",
        "created_at": "2020-01-02T01:22:38+00:00",
        "dif_id": "xxxxxxxxxxxxxxxxxxx", // dif data中的id
        "dif_signature": "xxxxxxxxxxx", // dif的签名，也就是signature中内容
        "floating_uuid": "xxxxxxxxxxxxxxxxxxxxxxx",
        "license_id": "xxxxxxxxxxxxxxxxxxxxxxxxxx",
        "license_info": {
            // license的名字，参数等等一堆变量
        },
        "id": "xxxxxxxxxxxxxxxxxxx",
        "hw_info": {
            // 与dif中的hw_info一致
        }
    }
    ```



## dif, lif 文件加解密及签名

dif和lif使用同一套加解密以及签名的方法，确实很多函数都是共用的，唯一的区别就是dif在本机更新的时候可以进行加解密和重新签名，而lif就只有解密和验证签名的过程。

### 加密和解密

设备标识文件以及许可证文件都有如下的结构

```json
{
    "nonce": "93995d89-aadd-495f-b00b-e344e4a63a7c",  //<-随机生成的uuid
    "data": "BASE64编码后的本体", 
    "signature": "BASE64编码的签名"
}
```

如上所示，data中是加密的数据，nonce是加密密钥的一部分，data部分是使用nonce加盐作为密钥的aes-256-cbc算法进行加密的，openssl本身就可以支持这一操作，使用下面的命令即可对其进行加密及解密

```shell
# 加密lif
lif_json_path=lif.json
lif_path=output.lif
uuid=`uuidgen`
openssl enc -e -aes-256-cbc -md md5  -in $lif_json_path -k $uuid -salt -out lif.data

lif_data=`openssl enc -base64 -e -in lif.data -A`
cat >$lif_path<<eof
{
    "nonce": "$uuid", 
    "data": "$lif_data"
 }
eof

# 解密dif
dif_path=input.dif
dif_data=`jq -r .data $dif_path`
dif_nonce=`jq -r .nonce $dif_path`

echo -n "$dif_data" | openssl enc -base64 -d -A | openssl enc -d -aes-256-cbc -md md5 -k $dif_nonce -salt -out dif.json

```

output.lif 就是加密后的lif，而dif.json就是解密后的dif，可以使用命令`qlicense_tool generate_dif`手动生成dif解密试试看

### 签名的生成及校验

dif是使用`/etc/config/qlicense/qlicense_private_key.pem`进行签名的，而lif使用同文件夹下的`qlicense_public_key.pem` 进行签名的校验

这两个文件在`initrd.boot`中存在，但是安装LicenseCenter之后会被覆盖，链接到LicenseCenter中安装文件中，不过不用担心，这两个密钥官方应该不怎么会更新，因为老版本没有更新密钥的指令，要更新会是一件比较麻烦的事情

```shell
# ls -l /etc/config/qlicense/qlicense_*
lrwxrwxrwx 1 admin administrators 56 2022-03-25 05:40 /etc/config/qlicense/qlicense_private_key.pem -> /mnt/ext/opt/LicenseCenter/conf/qlicense_private_key.pem
lrwxrwxrwx 1 admin administrators 55 2022-03-25 05:40 /etc/config/qlicense/qlicense_public_key.pem -> /mnt/ext/opt/LicenseCenter/conf/qlicense_public_key.pem
```

同样的，dif与lif使用相同的方法进行签名及校验

```shell
# 签名
openssl dgst -sha256 -sign ../qlicense_private_key.pem dif.data > dif.sign
# 校验
openssl dgst -sha256 -verify ../qlicense_public_key.pem -signature lif.data lif.sign
```



## 生成一个lif

下面就举个小例子，尝试生成一个vqtscloud的许可证文件，为了方便起见，把public和private key设置成一对

```shell
exec 2>/dev/null

# 劫持域名
sed -i "s/^#conf-file=\/etc\/dnsmasq.more.conf.*\$/conf-file=\/etc\/dnsmasq.more.conf/" /etc/dnsmasq.conf
echo "address=/myqnapcloud.com/127.0.0.1" > /etc/dnsmasq.more.conf
echo "address=/myqnapcloud.cn/127.0.0.1" >> /etc/dnsmasq.more.conf
echo "address=/myqnapcloud.com.cn/127.0.0.1" >> /etc/dnsmasq.more.conf
killall dnsmasq
/sbin/dnsmasq

# 1. 替换密钥
mkdir /mnt/.fake_active
cd /mnt/.fake_active

echo "===>replace qlicense key"
openssl ecparam  -name secp384r1 -genkey -out private.pem
cp private.pem /etc/config/qlicense/qlicense_private_key.pem
openssl ec -in private.pem -pubout -out public.pem
cp public.pem /etc/config/qlicense/qlicense_public_key.pem

# 2. 生成dif并读取

echo "===>generate dif"

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
# note created_at 应该与本机时间差距小于1天

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
openssl dgst -sha256 -sign private.pem lif.data > lif.sign

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
qlicense_tool offline_activate -p `pwd`/$license_id.lif
```

试一下看看，看起来没啥问题

```
[/mnt/.fake_active] # sh active.sh
===>replace qlicense key
===>generate dif
===>generate lif
{"code": 0, "message": "success"}
```

到网页上看看，似乎也没有问题，点一下继续使用此许可证看看呢。

![](/img/qnap-license-6.png)

只要一点击继续使用此许可证，你就会发现，无论怎么点击，都一直停留在这个页面，点击后调用url

```http
http://xxxxxxxxxx:8080/cgi-bin/quick/quick.cgi?todo=floating_refresh_installed_license&license_id=86221f76acea11eca189000c&_=1648288992417
```
但是每次都返回失败
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Storage>
<DiskError>0</DiskError>
<DiskErrorCode>none</DiskErrorCode>
<floating_refresh_ret>-11</floating_refresh_ret>
<license_error_code>-11</license_error_code>
<Result>success</Result>
</Storage>
```

这是因为安装qutscloud的时候还会对已经安装的license尝试做floating refresh，quick.cgi调用命令`qlicense_tool floating_refresh`来进行这一操作，在命令行中试试看

```shell
[/mnt/.fake_active] # qlicense_tool floating_refresh -i 86221f76acea11eca189000c
{"code": -11, "message": "floating license refresh failed"}
```

运行这个命令确实会出错，解决的办法有两种

- 使用一个脚本hook qlicense_tool，使其floating_refresh只返回`{"code": 0, "message": "sucess"}`，像下面这样

  - ```shell
    if [ "$1" == "floating_refresh" -o "$1" == "local_check" ] ; then
     echo '{"code": 0, "message": "success"}'
     exit 0
    fi
    /usr/local/bin/qlicense_tool_old $@
    ```

- 架设一个实现floating refresh的服务器，让系统可以更新许可证，可以参考下面的floating refresh小节



# 2. 本地激活

QTS系统支持离线下载dif并且上传到license manager激活，而qutscloud对应的许可证点击上传dif后只显示序列号，这两个看起来其实有一点点区别，虽然本文开头的时候讲解过，但是还是一起介绍一下好了，水水字数也是不错的。

## QTS系统离线激活

使用命令生成dif文件，或者直接在许可证中心下载dif

```shell
# qlicense_tool generate_dif
{"code": 0, "message": "success", "result": "/etc/config/qlicense/dif/unused/1fa6f575-e1be-44e9-868a-8be5aa5aec9a.dif"}

```

将dif文件的内容copy出来或者下载下来，上传到license manager

![](/img/qnap-license-5.png)

上传之后license manager便会下载一个lif，可以将其导入到许可证中心激活

## QutsCloud离线激活

**需要注意，上传dif文件的按钮仅QTS系统可用，qutscloud系统的许可证不支持上传dif设备标识文件**，并且只支持浮动许可证类型，如果要下载qutscloud系统类型的lif的话，只能使用生成的url

```shell
dif_path=input.dif
devicename=`hostname`
dif=`base64 $dif_path | tr -d "\n="`  # delete \n and padding
echo "Please access follow link to download lif"
echo "https://license.qnap.com/#/my_license?device_name=$hostname&dif=$dif"
```

访问生成的url就可以去下载lif了

除了在许可证中心上传lif激活，也可以使用如下命令进行离线激活

```shell
qlicense_tool offline_activate -k [lif file path]
```



# 3. 在线激活



在线激活其实与离线激活没有太大的区别，只是根据序列号来标识license，然后根据上传的dif生成lif

系统使用的api按照如下顺序调用(数据已脱敏，请按照字面值填写对应字段)

## 获取license key信息

- `GET https://license.api.myqnapcloud.cn/v1.0/license/license_key_info`

请求
```http
GET https://license.api.myqnapcloud.cn/v1.0/license/license_key_info?license_key=xxxxxxxxxxxxxxxxxx HTTP/1.1
Host: license.api.myqnapcloud.cn
Accept: application/json
X-QNAP-APP-ID: 55e6b4311375643a39aeb9a4					<== 固定值
X-QNAP-SUBAPP-ID: 55e6b4311375643a39aeb9a4				<== 固定值
X-QNAP-MODEL: QuTScloud
X-QNAP-FIRMWARE: c5.0.0_20220119
X-QNAP-DIGEST: xxxxxxxxxxxxxxxxxxxxxxxxxxxxx			<== sha1("$hwsn$suid")
X-QNAP-APP-VER: c5.0.0_20220119
X-QNAP-DEVICE-HOSTNAME: NAS123456						<== hostname
Authorization: Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxx <= access_token (不在本篇讨论范围内)
```

响应
```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=UTF-8
Transfer-Encoding: chunked
Connection: keep-alive
Server: nginx
Etag: "d5cf93a49c0e7f15a43ad44bab62f75b4c05466e"
Cache-Control: no-store
Access-Control-Allow-Origin: *
X-Via: 10.0.0.250
X-Via: 172.17.0.241

ab6   <== 已format
{
   "message":"OK.",
   "code":0,
   "result":[
      {
         "updated_at":"2020-01-02T03:04:05.000000",
         "device_type":[
            "VQTS_CLD"
         ],
         "duration":{
            "year":0,
            "day":0,
            "month":1
         },
         "app_min_version":"c4.4.2",
         "activation_ip":"xxxxxxxxxxxxxx",
         "seats_info":{
            "total_free_unsubscribed":0,
            "total_activated":0,
            "lif_download_path":"",
            "seat_list":{
               
            },
            "max_seats":1,
            "available_seats":1,
            "total_seats":1,
            "total_unsubscribed":0
         },
         "license_id":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
         "type":"device",
         "status":"valid",
         "product":{
            "sku":"LS-QUTSCLOUD-1CR-1M-EI",
            "product_type":"vQTS_Cloud",
            "product_id":"2302",
            "categories":[
               "vQTS_Cloud"
            ],
            "name":"QuTScloud 1 Core - 1 Month"
         },
         "app_display_name":"QuTScloud",
         "license_name":"QuTScloud 1 Core - 1 Month",
         "activated_at":"2020-01-02T03:04:05.000000",
         "quota":{
            "max_user":0,
            "max_device":1
         },
         "expires_at":"2020-01-02T03:04:05.000000",
         "hashed":true,
         "available_seats":1,
         "license_key":"XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
         "app_internal_name":"vqtscloud",
         "transferable":true,
         "created_at":"2020-01-02T03:04:05.000000",
         "license_credit":[
            {
               "duration":{
                  "year":0,
                  "day":0,
                  "month":1
               },
               "applied_date":"2020-01-02T03:04:05.000000",
               "license_credit_id":"xxxxxxxxxxxxxxxxxxxxx"
            }
         ],
         "attributes":{
            "is_floating":true,
            "ext_check_type":"product.product_type",
            "aw_sarp2_is_used_advanced_pricing":"Use config",
            "app_min_version":"c4.4.2",
            "purchase_before_installed":"false",
            "small_image_label":"QuTScloud 1 Core - 1 Month",
            "is_subscription":true,
            "thumbnail_label":"QuTScloud 1 Core - 1 Month",
            "device_type":"vqts_cld",
            "cpu_limit":"1",
            "external_service":false,
            "plan_title":"1 Core",
            "is_self_check":true,
            "product_image_size":"Default",
            "msrp_display_actual_price_type":"Use config",
            "grace_period_days":"21",
            "gift_message_available":"No",
            "variant_display_name":"QuTScloud 1 Core - 1 Month",
            "pre_gen_key":false,
            "app_display_name":"QuTScloud",
            "quota_device":"1",
            "ui_type":"Drop-down List",
            "expiry_warning_day":"-1",
            "upgradeable":true,
            "transferable":true,
            "amrolepermissions_owner":"0",
            "duration_month":"1",
            "product_class":"vQTS_Cloud",
            "license_activation_info":"<div class=\"qSW-pd-desc\"  id=\"qSW-pd-detail-license\">\n    \n    <iframe class=\"resize_height iframe_license_activation\" id=\"iframe_license_activation\" src=\"https://docs.qnap.com/operating-system/qts/4.5.x/en-us/GUID-C6DE86F5-38A3-496E-A872-F833E1E5280D.html\" frameborder=\"0\" allowfullscreen=\"\" width=\"100%\" height=\"100%\" scrolling=\"no\"></iframe>\n\n</div>",
            "app_internal_name":"vqtscloud",
            "extendable":true,
            "type":"device",
            "is_perpetual":"false",
            "is_bundle":false,
            "immediate_activate":true,
            "support_org":false,
            "image_label":"QuTScloud 1 Core - 1 Month"
         }
      }
   ]
}
0
```



## 上传dif并激活

- `POST https://license.api.myqnapcloud.cn/v1.1/license/xxxxxxxxxxxxxxxxxxxx/activation`

```http
POST https://license.api.myqnapcloud.cn/v1.1/license/xxxxxxxxxxxxxxxxxxxx/activation HTTP/1.1
Host: license.api.myqnapcloud.cn
Accept: application/json
X-QNAP-APP-ID: 55e6b4311375643a39aeb9a4
X-QNAP-SUBAPP-ID: 55e6b4311375643a39aeb9a4
X-QNAP-MODEL: QuTScloud
X-QNAP-FIRMWARE: c5.0.0_20220119
X-QNAP-DIGEST: xxxxxxxxxxxxxxxxxxxxx
X-QNAP-APP-VER: c5.0.0_20220119
X-QNAP-DEVICE-HOSTNAME: NAS123456
Authorization: Bearer xxxxxxxxxxxxxxxxxxx
Content-Length: 1135
Content-Type: multipart/form-data; boundary=------------------------75e48eb31ba4f5df
Expect: 100-continue

--------------------------75e48eb31ba4f5df
Content-Disposition: form-data; name="license_key"

XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
--------------------------75e48eb31ba4f5df
Content-Disposition: form-data; name="dif"; filename="xxxxxxxxxxxxx.dif"
Content-Type: application/octet-stream

{"nonce":"xxxxxxxxxxxx","app_id":"0vi23432423egfdsscwklkjdw23s9001","data":"xxxxxxxxxx","signature":"xxxxxxxxxxxxxxxxxx"}
--------------------------75e48eb31ba4f5df--

```

响应

```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=UTF-8
Transfer-Encoding: chunked
Connection: keep-alive
Server: nginx
Cache-Control: no-store
Access-Control-Allow-Origin: *
X-Via: 10.0.0.250
X-Via: 172.17.0.242

80
{"message": "OK.", "code": 0, "result": "https://license.api.myqnapcloud.cn/v1.2/license/[另一个ID]/download_pkg"}
0
```



## 下载lif

- `GET https://license.api.myqnapcloud.cn/v1.2/license/[另一个ID]/download_pkg?license_key=xxxxxxxxxxxxxxxxxxx`

请求

```http
GET https://license.api.myqnapcloud.cn/v1.2/license/[另一个ID]/download_pkg?license_key=xxxxxxxxxxxxxxxxxxx HTTP/1.1
Host: license.api.myqnapcloud.cn
Accept: application/json
X-QNAP-APP-ID: 55e6b4311375643a39aeb9a4
X-QNAP-SUBAPP-ID: 55e6b4311375643a39aeb9a4
X-QNAP-MODEL: QuTScloud
X-QNAP-FIRMWARE: c5.0.0_20220119
X-QNAP-DIGEST: xxxxxxxxxxxxxxxxxxxxx
X-QNAP-APP-VER: c5.0.0_20220119
X-QNAP-DEVICE-HOSTNAME: NAS123456
Authorization: Bearer xxxxxxxxxxxxxxxxxxx

```

响应，只是简单下载lif文件

```http
HTTP/1.1 200 OK
Content-Type: application/octet-stream
Transfer-Encoding: chunked
Connection: keep-alive
Server: nginx
Content-Disposition: attachment; filename=QLicense_QuTScloud_QuTScloud 1 Core - 1 Month_.lif; filename*=UTF-8''QLicense_QuTScloud_QuTScloud%201%20Core%20-%201%20Month.lif
X-Via: 10.0.0.251
X-Via: 172.17.0.241

1302
{
    "nonce": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", 
    "data": "xxxxxxxxxxxxxxxxxxxx

*** FIDDLER: RawDisplay truncated at 128 characters. Right-click to disable truncation. ***
```





# 4. floating refresh

QutsCloud与QTS不一样的地方在于，vm可能可以随便迁移，并不会对应一个固定的硬件，比如，可能虚拟机崩溃了需要重新安装或者云服务商换母鸡甚至跑路了要换供应商怎么办？这个时候重装后就完全是另外一台机器了，MAC地址以及硬盘，甚至cpu也发生了变化。

因此QNAP做了一个浮动许可证，这个许可证的精髓在于许可证文件并不是一直不变的，而是随着浮动更新而更新，每个许可证都附带一个floating uuid及floating token，qutscloud每隔一段时间就会去请求更新浮动许可证，上传新生成的dif文件，并且下载最新的lif，需要注意的是浮动更新没有过期时间，屏蔽QNAP的官方网站不会造成许可证失效。

所以一个许可证只能给一台机器用，获取最新的float token的那个得到后，其他的机器就无法获取到更新的float token了



下面看看它调用的API

## 检查是否有对应的许可证

- `POST https://license.api.myqnapcloud.cn/v1.1/license/device/installed`

请求

```http
POST https://license.api.myqnapcloud.cn/v1.1/license/device/installed HTTP/1.1
Host: license.api.myqnapcloud.cn
Accept: application/json
X-QNAP-APP-ID: 55e6b4311375643a39aeb9a4
X-QNAP-SUBAPP-ID: 55e6b4311375643a39aeb9a4
X-QNAP-MODEL: QuTScloud
X-QNAP-FIRMWARE: c5.0.0_20220119
X-QNAP-DIGEST: xxxxxxxxxxxxxxxxxxxxx
X-QNAP-APP-VER: c5.0.0_20220119
X-QNAP-DEVICE-HOSTNAME: NAS123456
Authorization: Bearer xxxxxxxxxxxxxxxxxxx
Content-Length: 59
Content-Type: application/x-www-form-urlencoded

{ "floating_uuid": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx" }
```

响应，注意响应中的一些字段会被检查，比如其中的status，日期等等

```http
HTTP/1.1 200 OK
Date: Wed, 23 Mar 2022 03:09:04 GMT
Content-Type: application/json; charset=UTF-8
Transfer-Encoding: chunked
Connection: keep-alive
Server: nginx
Cache-Control: no-store
Access-Control-Allow-Origin: *
X-Via: 10.0.0.250
X-Via: 172.17.0.242

f2b  <== formated json
{
   "message":"OK.",
   "code":0,
   "result":[
      {
         "updated_at":"2020-01-02T03:04:05.000000",
         "owner":[
            "xxxxxxxxxxxxxxxxx"
         ],
         "device_type":[
            "VQTS_CLD"
         ],
         "duration":{
            "year":0,
            "day":0,
            "month":1
         },
         "remain_days":11,
         "app_min_version":"c4.4.2",
         "activation_ip":"xxxxxxxxxxxxx",
         "seats_info":{
            "total_free_unsubscribed":0,
            "total_activated":1,
            "lif_download_path":"/v1.2/license/xxxxxxxxxxxxxxxxxxx/download_pkg",
            "seat_list":{
               "[floating uuid]":{
                  "status":"active",
                  "firmware":"c5.0.0.1919 (20220119)",
                  "last_updated_at":"2020-01-02T03:04:05.000000",
                  "deactivated":0,
                  "hostname":"xxxxxxxx",
                  "hwsn":"xxxxxxxxxxxxxxx",
                  "last_remote_ip":"xxxxxxxxxxxxxxxxx",
                  "unsubscribed":0,
                  "used_seats":1,
                  "lif_download_path":"/v1.2/license/xxxxxxxxxxxxxxxxx/download_pkg",
                  "model":"QuTScloud",
                  "device_id":""
               }
            },
            "max_seats":1,
            "available_seats":0,
            "total_seats":1,
            "total_unsubscribed":0
         },
         "license_id":"xxxxxxxxxxxxxxxxxxxxxx",
         "type":"device",
         "status":"valid",
         "product":{
            "sku":"LS-QUTSCLOUD-1CR-1M-EI",
            "product_type":"vQTS_Cloud",
            "product_id":"2302",
            "categories":[
               "vQTS_Cloud"
            ],
            "name":"QuTScloud 1 Core - 1 Month"
         },
         "app_display_name":"QuTScloud",
         "license_name":"QuTScloud 1 Core - 1 Month",
         "activated_at":"2020-01-02T03:04:05.000000",
         "quota":{
            "max_user":0,
            "max_device":1
         },
         "expires_at":"2020-01-02T03:04:05.000000",
         "hashed":true,
         "grace_period_status":"valid",
         "user":[
            
         ],
         "ownership":{
            "is_owner":false,
            "email":"xxxxxxxxxxxxx"
         },
         "device":[
            {
               "suid":"xxxxxxxxxxxxxxx",
               "activation":{
                  "status":"active",
                  "applied_at":"2020-01-02T03:04:05.000000",
                  "by_user":"",
                  "assigned_date":"2020-01-02T03:04:05.000000"
               },
               "hwsn":"xxxxxxxxxxxxxxxxxx",
               "license_file_id":"xxxxxxxxxxxxxxxxxxxxxx",
               "mac":"xxxxxxxxxxxxxxxxxxxxxxxx",
               "fw_build_version":"c5.0.0.1919 (20220119)",
               "floating_hash":"xxxxxxxxxxxxxxxxxxxxxxxxxxx",
               "floating_uuid":"xxxxxxxxxxxxxxxxxxxxx",
               "device_hostname":"xxxxxxxxxxxxx",
               "model":"QuTScloud",
               "remote_ip":"xxxxxxxxxxxxxxx",
               "device_id":""
            }
         ],
         "license_key":"xxxxxxxxxxxxxxxxxxxxxxx",
         "app_internal_name":"vqtscloud",
         "transferable":true,
         "created_at":"2020-01-02T03:04:05.000000",
         "license_credit":[
            {
               "duration":{
                  "year":0,
                  "day":0,
                  "month":1
               },
               "applied_date":"2020-01-02T03:04:05.000000",
               "license_credit_id":"xxxxxxxxxxxxxxxxxxxx"
            }
         ],
         "display_status":"valid",
         "attributes":{
            "is_floating":true,
            "ext_check_type":"product.product_type",
            "aw_sarp2_is_used_advanced_pricing":"Use config",
            "app_min_version":"c4.4.2",
            "purchase_before_installed":"false",
            "small_image_label":"QuTScloud 1 Core - 1 Month",
            "is_subscription":true,
            "thumbnail_label":"QuTScloud 1 Core - 1 Month",
            "device_type":"vqts_cld",
            "cpu_limit":"1",
            "external_service":false,
            "plan_title":"1 Core",
            "is_self_check":true,
            "product_image_size":"Default",
            "msrp_display_actual_price_type":"Use config",
            "grace_period_days":"21",
            "gift_message_available":"No",
            "variant_display_name":"QuTScloud 1 Core - 1 Month",
            "pre_gen_key":false,
            "app_display_name":"QuTScloud",
            "quota_device":"1",
            "ui_type":"Drop-down List",
            "expiry_warning_day":"-1",
            "upgradeable":true,
            "transferable":true,
            "amrolepermissions_owner":"0",
            "duration_month":"1",
            "product_class":"vQTS_Cloud",
            "license_activation_info":"<div class=\"qSW-pd-desc\"  id=\"qSW-pd-detail-license\">\n    \n    <iframe class=\"resize_height iframe_license_activation\" id=\"iframe_license_activation\" src=\"https://docs.qnap.com/operating-system/qts/4.5.x/en-us/GUID-C6DE86F5-38A3-496E-A872-F833E1E5280D.html\" frameborder=\"0\" allowfullscreen=\"\" width=\"100%\" height=\"100%\" scrolling=\"no\"></iframe>\n\n</div>",
            "app_internal_name":"vqtscloud",
            "extendable":true,
            "type":"device",
            "is_perpetual":"false",
            "is_bundle":false,
            "immediate_activate":true,
            "support_org":false,
            "image_label":"QuTScloud 1 Core - 1 Month"
         }
      }
   ]
}
0


```



## 更新token

- `POST https://license.api.myqnapcloud.cn/v1.1/license/[license id]/issue_token `

请求

```http
POST https://license.api.myqnapcloud.cn/v1.1/license/xxxxxxxxxxxxxxxxxxxxxx/issue_token HTTP/1.1
Host: license.api.myqnapcloud.cn
Accept: application/json
X-QNAP-APP-ID: 55e6b4311375643a39aeb9a4
X-QNAP-SUBAPP-ID: 55e6b4311375643a39aeb9a4
X-QNAP-MODEL: QuTScloud
X-QNAP-FIRMWARE: c5.0.0_20220119
X-QNAP-DIGEST: xxxxxxxxxxxxxxxxxxxxx
X-QNAP-APP-VER: c5.0.0_20220119
X-QNAP-DEVICE-HOSTNAME: NAS123456
Authorization: Bearer xxxxxxxxxxxxxxxxxxx
Content-Length: 1293
Content-Type: multipart/form-data; boundary=------------------------ddbe6dd4e98e74fd
Expect: 100-continue

--------------------------ddbe6dd4e98e74fd
Content-Disposition: form-data; name="license_key"

xxxxxxxxxxx
--------------------------ddbe6dd4e98e74fd
Content-Disposition: form-data; name="dif"; filename="xxxxxxxxxxxxxxxxx.dif"
Content-Type: application/octet-stream

{"nonce":"e5dfa617-3b82-4f8e-9fcc-43559b983ae7","app_id":"0vi23432423egfdsscwklkjdw23s9001","data":"xxxxxxxxxxx","signature":"xxxxxxxx"}
--------------------------ddbe6dd4e98e74fd--

```

响应

```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=UTF-8
Transfer-Encoding: chunked
Connection: keep-alive
Server: nginx
Cache-Control: no-store
Access-Control-Allow-Origin: *
X-Via: 10.0.0.251
X-Via: 172.17.0.242

80
{"message": "OK.", "code": 0, "result": "https://license.api.myqnapcloud.cn/v1.2/license/xxxxxxxxxxxxxxxxxxxxx/download_pkg"}
0

```





## 下载lif

- `GET https://license.api.myqnapcloud.cn/v1.2/license/xxxxxxxxxxxxxx/download_pkg?license_key=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

请求

```http
GET https://license.api.myqnapcloud.cn/v1.2/license/xxxxxxxxxxxxxx/download_pkg?license_key=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx HTTP/1.1
Host: license.api.myqnapcloud.cn
Accept: application/json
X-QNAP-APP-ID: 55e6b4311375643a39aeb9a4
X-QNAP-SUBAPP-ID: 55e6b4311375643a39aeb9a4
X-QNAP-MODEL: QuTScloud
X-QNAP-FIRMWARE: c5.0.0_20220119
X-QNAP-DIGEST: xxxxxxxxxxxxxxxxxxxxx
X-QNAP-APP-VER: c5.0.0_20220119
X-QNAP-DEVICE-HOSTNAME: NAS123456
Authorization: Bearer xxxxxxxxxxxxxxxxxxx

```



响应

```http
HTTP/1.1 200 OK
Content-Type: application/octet-stream
Transfer-Encoding: chunked
Connection: keep-alive
Server: nginx
Content-Disposition: attachment; filename=QLicense_QuTScloud_QuTScloud 1 Core - 1 Month.lif; filename*=UTF-8''QLicense_QuTScloud_QuTScloud%201%20Core%20-%201%20Month.lif
X-Via: 10.0.0.250
X-Via: 172.17.0.241

1302
{
    "nonce": "xxxxxxxxxxxxxxxxxx", 
    "data": "xxxxxxxxxxxxxxxxxxxxxxx

*** FIDDLER: RawDisplay truncated at 128 characters. Right-click to disable truncation. ***
```



# 5. 小结



这篇弄明白了QNAP的license的生成与解密，以及api激活以及浮动更新的流程，模拟一个license manager差不多的服务器应该不是难事。