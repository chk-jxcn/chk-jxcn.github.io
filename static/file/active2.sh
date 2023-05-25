#!/bin/sh


do_patch() {
	# enable QVS
	cat <<EOF > /etc/init.d/QDevelop.sh
#!/bin/sh
/sbin/setcfg System VM 1 -f /etc/default_config/uLinux.conf

EOF
	chmod a+x /etc/init.d/QDevelop.sh
	sh  /etc/init.d/QDevelop.sh
	cat <<"EOF" > /etc/init.d/get_cloud_platform.sh
#!/bin/sh
if [ "$1" = "check_qnap" ]; then
	echo "Platform = QVS"
	echo "SupportDiskInfo = no"
else
	echo "Platform = Unknown"
	echo "SupportDiskInfo = no"
fi
EOF
	chmod a+x /etc/init.d/get_cloud_platform.sh

}

install_syslinux() {
mkdir /boot; mount /dev/mapper/dom2 /boot
# wget https://ftp5.gwdg.de/pub/linux/archlinux/core/os/x86_64/syslinux-6.04.pre2.r11.gbf6db5b4-3-x86_64.pkg.tar.xz
wget -q --no-check-certificate https://jxcn.org/file/syslinux-6.04.pre2.r11.gbf6db5b4-3-x86_64.pkg.tar.xz
tar xf syslinux-6.04.pre2.r11.gbf6db5b4-3-x86_64.pkg.tar.xz -C /
cp /usr/lib/syslinux/bios/*.c32 /boot/syslinux/
extlinux --install /boot/syslinux
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/bios/mbr.bin of=/dev/mapper/dom

cat <<eof >/boot/syslinux/syslinux.cfg
DEFAULT qutscloud
PROMPT 0        # Set to 1 if you always want to display the boot: prompt
TIMEOUT 100

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
}

patch_pack() {
	echo -e "/etc/init.d/QDevelop.sh\n/etc/init.d/get_cloud_platform.sh\n" | cpio -o -H newc  > /boot/boot/patch.boot	
	umount /boot
}



echo "==>install syslinux"
install_syslinux
echo "==>create patch"
do_patch
patch_pack
echo "==>done"

echo "Please reboot to take effect!"


