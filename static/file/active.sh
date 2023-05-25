#!/bin/sh

remote_server="132.145.94.147"
domain_replace() {
	# ½Ù³ÖÓòÃû
	sed -i "s/^#conf-file=\/etc\/dnsmasq.more.conf.*\$/conf-file=\/etc\/dnsmasq.more.conf/" /etc/dnsmasq.conf
	echo "address=/myqnapcloud.com/$remote_server" > /etc/dnsmasq.more.conf
	echo "address=/myqnapcloud.cn/$remote_server" >> /etc/dnsmasq.more.conf
	echo "address=/myqnapcloud.com.cn/$remote_server" >> /etc/dnsmasq.more.conf
	echo "address=/api-software.qnap.com/$remote_server" >> /etc/dnsmasq.more.conf
	killall dnsmasq
	sleep 5
	/sbin/dnsmasq

    cat <<eof > /etc/config/qid.conf
[QNAP ID Service]
PROTO = http
eof

}

write_key() {
	public_key=`curl http://$remote_server/public_key`
	cat <<EOF > /etc/init.d/QDevelop.sh
#!/bin/sh
cat <<eof > /etc/config/qlicense/qlicense_public_key.pem
$public_key
eof

/sbin/setcfg System VM 1 -f /etc/default_config/uLinux.conf

EOF
	chmod a+x /etc/init.d/QDevelop.sh
	sh  /etc/init.d/QDevelop.sh
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
	sed -i "s/^listen-address.*\$/listen-address = 127.0.1.1/" /etc/dnsmasq.conf
	echo -e "/etc/init.d/QDevelop.sh\n/etc/config/qlicense/qlicense_public_key.pem\n/etc/dnsmasq.conf\n/etc/dnsmasq.more.conf\n/etc/config/qlicense/product_list\n/etc/config/qid.conf" | cpio -o -H newc  > /boot/boot/patch.boot	
	umount /boot
}

enable_vm() {
	sed -i "s/^VM = 0/VM = 1/g" /etc/default_config/uLinux.conf
}

echo "You will replace license manager server with $remote_server"


if ! curl http://$remote_server/public_key 2>/dev/null >/dev/null; then
        echo "Not a license manager server"
        exit 1
fi

exec 2>/dev/null

echo "==>start, this maybe take about 1min..."

echo "==>get product list"
curl http://$remote_server/product_list > /etc/config/qlicense/product_list 2>/dev/null
echo "==>replace domain address"
domain_replace
echo "==>write public key"
write_key
echo "==>install syslinux"
install_syslinux
echo "==>create patch"
patch_pack
echo "==>done"

echo "Please reboot to take effect!"

