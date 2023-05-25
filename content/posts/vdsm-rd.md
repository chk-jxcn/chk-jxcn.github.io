---
title: "Virtual DSM 逆向笔记 (重打包rd.gz)"
date: 2022-04-18
categories:
- VDSM
- DSM
typora-root-url: ..\..\static
---



重新打包rd.gz后，可能会发现内核无法解压rd.gz，这是因为格式有点不一样

<!--more-->



{{< toc >}}



# 1. LZMA文件格式

参考https://svn.python.org/projects/external/xz-5.0.3/doc/lzma-file-format.txt

Header是13字节的三部分组成

```
+------------+----+----+----+----+--+--+--+--+--+--+--+--+
| Properties |  Dictionary Size  |   Uncompressed Size   |
+------------+----+----+----+----+--+--+--+--+--+--+--+--+
```





# 2. DSM的内核解压LZMA

有一个简单的判断去跳过第一个lzma后的内容，准确来说并不是校验或者检查

```c
#ifdef MY_ABC_HERE
		if (my_inptr == 0) {
			printk(KERN_INFO "decompress cpio completed and skip redundant lzma\n");
			break;
		}
#endif /* MY_ABC_HERE */
```

decompress 返回的指针偏移为0则表示跳过后面的lzma



lzma算法中对返回指针的设置

```c
#ifdef MY_ABC_HERE
	if (posp) {
		if (get_pos(&wr) == header.dst_size)
			*posp = 0;
		else
			*posp = rc.ptr-rc.buffer;
	}
#else
	if (posp)
		*posp = rc.ptr-rc.buffer;
#endif /* MY_ABC_HERE */
```



因此如果要让4.4的内核准确加载rd.gz，则需要修改uncompressed size，默认情况这个属性是会设置成0xFFFFFFFFFFFFFFFF



lzma创建的文件头

```shell
head -c 15 conf.lzma | hexdump -e  '20/1 "%02x" "\n"'
5d00008000ffffffffffffffff0011
```



rd.gz的文件头

```shell
head -c 15 rd.xz | hexdump -e  '20/1 "%02x" "\n"'
5d0000000400a81e01000000000018
```

`00a81e01`按照littleend来算是18786304字节，刚好就是解压后的大小

```shell
ls -l rd
-rw-r--r-- 1 root root 18786304 Apr 17 20:18 rd
```



另外，4.4似乎没有对rd.gz签名，看了一下，grub有对内核及rd.gz做checksum，但是显然是md5抽出一些字节组成的

```shell
bash-4.4# cat grub_cksum.syno
(hd0,1)/zImage Encrypted: 9d432fe3b2c8f9bc7
(hd0,1)/rd.gz Encrypted: 6a5d37c7e969461df
bash-4.4# md5sum zImage
9fd8453126fce43fb823c38cf309b1c7  zImage
bash-4.4# md5sum rd.gz
64aa55d13271c578e19b6b094a6e14df  rd.gz
```

