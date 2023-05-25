---
title: "QutsCloud 逆向笔记 - 激活思路及路线选择"
date: 2022-03-26
categories:
- qutscloud
draft: true
---



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
