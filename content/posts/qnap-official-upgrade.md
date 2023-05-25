---
title: "QutsCloud 逆向笔记 - 无侵入式补丁及支持官方升级的可能性"
date: 2022-03-27
categories:
- qutscloud
typora-root-url: ..\..\static
thumbnailImagePosition: "left"
thumbnailImage: /img/qnap-official-upgrade-cover.png
---



通常在完成补丁后，这个补丁就可以插入到initrd，并且重新签名，这样就可以通过签名校验。但是升级之后，initrd会被覆盖，所以，升级后如果不重新生成initrd的话，补丁就会失效。

本篇的目的是尝试加载多个initrd来实现支持官方升级，就像老骥伏枥的牛年大礼包一样。



<!--more-->



tg交流群：https://t.me/qutscloud



个人更推荐使用SYSLINUX，比较简单不容易出错，可以优先试试

{{< toc >}}






# 1. 使用GRUB2.04



只想简单安装的同学请点击[这里]({{< ref "#简易操作" >}})



从官方地址下载下来的镜像，boot loader是GRUB 1.99，位于/dev/sda1，分区大小大概为2M。这个版本的grub不支持加载多个initrd[^1]，所以需要升级到GRUB 2.04或以上的版本。

```
/dev/mapper/dom1          2020      1328       584  69% /boot
```



从ubuntu的官网下载个GRUB 2.06的安装包看看，结果还没安装，这一堆文件大小就已经超过2M了，安装的时候还要生成core.img，不过可能也就几十K。

```shell
[~/i386-pc] # du -s
2636    .
```



也不知道QNAP加载device mapping的设置是存在配置里还是从分区表里读出来的，不过暂时先不动分区表，试试看给GRUB瘦瘦身，要是还是不行的话就算了，搞搞syslinux，syslinux才大概1M左右。（PS: Qutscloud是根据parted输出的结果来创建dm table，上层应用基本都是用domX来访问硬盘分区，所以移动分区位置正常情况不会影响使用，不过考虑到patch的简便性，这里不考虑增大boot分区的大小）

删除了一堆用不到的文件后看看大小

```shell
[~/i386-pc] # rm regexp.mod net.mod zstd.mod zfs* grub-ntldr-img  functional_test.mod  bsd.mod xnu.mod gdb.mod  gcry_* btrfs.mod syslinuxcfg.mod legacycfg.mod
[~/i386-pc] # du -s
1880    .
```



还有100多KB，再生成个core.img最多50KB，脚本最多10KB，感觉勉强可以塞下了

找个ubuntu的机器安装一下，然后copy出来启动看看

---

ubuntu 20.04的grub默认是2.02，升级要下载500多M的更新，于是安装了个ubuntu21.10，默认grub是2.04，那就用这个好了，将qnap的镜像附加为第二块硬盘后启动

```shell
#!/bin/sh

# 准备需要copy的东西
cd
mkdir i386-pc
mkdir boot
cp /boot/grub/i386-pc/* i386-pc
( cd i386-pc && rm regexp.mod zstd.mod zfs* grub-ntldr-img  functional_test.mod  bsd.mod xnu.mod gdb.mod  gcry_* btrfs.mod syslinuxcfg.mod legacycfg.mod xnu* mpi.mod efiemu.mod xzio.mod ehci.mod ahci.mod legacy_password_test.mod *.img)

# 为sdb安装grub
# 为sdb1重新调整大小, 预留511个block写core.img，不调整会报下面的错误，因为分区1和mbr之间的空隙塞不进core.img
# Installing for i386-pc platform.
# grub-install: warning: your embedding area is unusually small.  core.img won't fit in it..
# grub-install: error: embedding is not possible, but this is required for cross-disk install.
cat <<eof | sfdisk /dev/sdb
label: dos
label-id: 0xb66e61e9
device: /dev/sdb
unit: sectors
sector-size: 512

/dev/sdb1 : start=         512, size=        3840, type=83
/dev/sdb2 : start=        4352, size=      484608, type=83, bootable
/dev/sdb3 : start=      488960, size=      484608, type=83
/dev/sdb4 : start=      973568, size=       34048, type=5
/dev/sdb5 : start=      973600, size=       16608, type=83
/dev/sdb6 : start=      990240, size=       17376, type=83
eof

# 生成core.img
cat <<eof > /boot/grub/i386-pc/load.cfg
set root=(hd0,msdos1)
set prefix=($root)'/' #this line seems useless
eof

grub-mkimage -v --directory '/usr/lib/grub/i386-pc' --prefix '/' --output '/boot/grub/i386-pc/core.img'  --format 'i386-pc'  --compression 'auto'  --config '/boot/grub/i386-pc/load.cfg' 'ext2' 'part_msdos' 'biosdisk'

# 写入mbr及core.img
grub-bios-setup --verbose --directory='/boot/grub/i386-pc' '/dev/sdb'

# 创建文件系统，复制grub的模块
mke2fs -t ext2 /dev/sdb1
mount /dev/sdb1 boot
mkdir boot/i386-pc
cp i386-pc/* boot/i386-pc/


# 写入启动项
cat <<eof > boot/grub.cfg
play 480 440 1
### END /etc/grub.d/00_header ###

### BEGIN /etc/grub.d/05_debian_theme ###
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray
### END /etc/grub.d/05_debian_theme ###

### BEGIN /etc/grub.d/10_linux ###
menuentry 'DOM kernel X86' --class ubuntu --class gnu-linux --class gnu --class os {
        insmod ext2
        set root='(hd0,2)'
        linux   /boot/bzImage root=/dev/ram0 rw
        initrd  /boot/initrd.boot /boot/patch.boot
}
menuentry 'DOM kernel X86 backup' --class ubuntu --class gnu-linux --class gnu --class os {
        insmod ext2
        set root='(hd0,3)'
        linux   /boot/bzImage root=/dev/ram0 rw
        initrd  /boot/initrd.boot
}
menuentry 'Recovery Mode' --class ubuntu --class gnu-linux --class gnu --class os {
        insmod ext2
        set root='(hd0,2)'
        linux   /boot/bzImage root=/dev/ram0 rw qnap_recovery_mode=1
        initrd  /boot/initrd.boot
}

set timeout=10
eof
umount boot

```

将镜像的硬盘从另外一台虚拟机启动试试看，好像已经可以了

![](/img/qnap-official-upgrade-1.png)

![](/img/qnap-official-upgrade-2.png)



可以看到，grub已经换成我们安装的2.04版本的grub，而且initrd参数也默认会加载两个initrd

启动qutscloud后，创建一个patch.boot来试试看

```shell
#!/bin/sh

# 创建/etc/init.d/QDevelop.sh
cat <<eof > /etc/init.d/QDevelop.sh
#!/bin/sh

echo "patched!!!"
eof
chmod a+x /etc/init.d/QDevelop.sh

# 保存到patch.boot
mkdir /boot
mount /dev/mapper/dom2 /boot/
echo /etc/init.d/QDevelop.sh | cpio -o -H newc  > /boot/boot/patch.boot
umount /boot
```



再次重启qutscloud，发现这个文件完好无损的躺在rootfs里，执行位也没变，可以用来作为patch的方式。

```shell
[~] # reboot
[~] #
login as: admin
admin@192.168.2.120's password:
[~] # ls /etc/init.d/QDevelop.sh
/etc/init.d/QDevelop.sh*
[~] # sh /etc/init.d/QDevelop.sh
patched!!!
```



不过有一个小问题，fdisk会报告磁柱未对齐，WTF？这个鬼玩意也不知道是从那里读的，不过应该没啥问题，这也不知道啥古董年代的fdisk。

```shell
[/boot] # fdisk -l /dev/sda

Disk /dev/sda: 515 MB, 515899392 bytes
64 heads, 32 sectors/track, 492 cylinders
Units = cylinders of 2048 * 512 = 1048576 bytes

   Device Boot      Start         End      Blocks   Id  System
/dev/sda1               1           3        1920   83  Linux
Partition 1 does not end on cylinder boundary.
/dev/sda2   *           3         239      242304   83  Linux
Partition 2 does not end on cylinder boundary.
/dev/sda3             239         476      242304   83  Linux
Partition 3 does not end on cylinder boundary.
/dev/sda4             476         492       17024    5  Extended
/dev/sda5             476         484        8304   83  Linux
/dev/sda6             484         492        8688   83  Linux

```



## 简易操作

另外，不想自己手动安装grub的同学，我也准备了镜像 [grub.img](/file/grub.img)

这部分镜像包含MBR到第一个分区的结束，直接dd到sda或者镜像后重启即可

```shell
# dd到本机硬盘
dd if=grub.img of=/dev/sda bs=512
# dd到镜像文件，避免截断镜像文件
dd if=grub.img of=qutscloud.img bs=512 conv=notrunc
```

PS: 上面的镜像未经测试，请谨慎操作



# 2. 使用SYSLINUX替换GRUB

因为syslinux不支持从其他硬盘读取文件，所以如果要从sda2启动的话，syslinux也必须安装在sda2，qutscloud的镜像默认启动分区是sda2，因此安装syslinux的默认mbr就好，使用下面的脚本安装syslinux到sda2，由于安装在sda2，大小也就没有了sda1的2M的限制了

Note: 直接在QutsCloud启动后登录进的ssh内执行即可，不需要准备其他机器

```shell
#!/bin/sh
mkdir /boot; mount /dev/mapper/dom2 /boot
# wget https://ftp5.gwdg.de/pub/linux/archlinux/core/os/x86_64/syslinux-6.04.pre2.r11.gbf6db5b4-3-x86_64.pkg.tar.xz
wget --no-check-certificate https://jxcn.org/file/syslinux-6.04.pre2.r11.gbf6db5b4-3-x86_64.pkg.tar.xz
tar xf syslinux-6.04.pre2.r11.gbf6db5b4-3-x86_64.pkg.tar.xz -C /
cp /usr/lib/syslinux/bios/*.c32 /boot/syslinux/
extlinux --install /boot/syslinux
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/bios/mbr.bin of=/dev/sda

cat <<eof >/boot/syslinux/syslinux.cfg
DEFAULT qutscloud
PROMPT 0        # Set to 1 if you always want to display the boot: prompt
TIMEOUT 50

UI menu.c32

# Refer to http://syslinux.zytor.com/wiki/index.php/Doc/menu
MENU TITLE Select Menu
#MENU BACKGROUND splash.png
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std


LABEL qutscloud
    MENU LABEL QutsCloud with patch (see https://jxcn.org)
    LINUX ../boot/bzImage
    APPEND root=/dev/ram0 rw
    INITRD ../boot/initrd.boot,../boot/patch.boot

LABEL qutscloudnopatch
    MENU LABEL QutsCloud
    LINUX ../boot/bzImage
    APPEND root=/dev/ram0 rw
    INITRD ../boot/initrd.boot

LABEL reboot
        MENU LABEL Reboot
        COM32 reboot.c32

LABEL poweroff
        MENU LABEL Poweroff
        COM32 poweroff.c32
eof

umount /boot
```

重启一下看看，感觉正常

![](/img/qnap-official-upgrade-3.png)



**注意：如果找不到patch.boot，syslinux会无法启动，可以选择下面的no patch的启动项启动**

像上一段一样生成一个patch.boot再启动，发现patch都生效了

```shell
[/] # umount /boot
[/] #
login as: admin
admin@192.168.2.124's password:
[~] #
[~] #
[~] # ls /etc/init.d/QDevelop.sh
/etc/init.d/QDevelop.sh*
[~] #
```

相比GRUB，个人更推荐syslinux，不用修改分区表，而且在qutscloud的ssh内就可以完成安装，非常简便。

虽然在boot目录下面加了个文件夹，不过没有什么影响。



这么说起来，既然syslinux都可以装到其他盘，那grub安装到其他盘也不过分吧，不过sda1还是需要重建，没有syslinux简单。

# 3. EFI

目前qutscloud的镜像有下面几个问题无法直接使用EFI启动

- 硬盘头部的主GPT分区表的位置与第一个分区的部分扇区重复
  - 主GPT分区表位置在1到33扇区，而qutscloud的第一分区从32扇区开始，有两个扇区重复了
- 硬盘末尾的备份GPT分区表与最后一个分区重叠
  - 备份GPT分区表从-33到-1扇区，而这些扇区已经全部分配给最后一个分区了
- 第一分区过小，几乎无法作为ESP分区使用（2M不到）



第一个和第二个问题很好解决，主GPT分区表可以通过调整sda1的起始扇区留出空间，备份GPT则只要给镜像分配大一点的空间就可以（qutscloud强制要求启动硬盘要预留用户数据空间）

第三个的话就有点麻烦，除非把sda1后面的分区往后挪，否则怎么倒腾也最多只有2M



由于EFI启动不是很紧要的事情，暂时就先不整了吧





[^1]: https://www.phoronix.com/scan.php?page=news_item&px=GRUB-Multiple-Early-Initrd

