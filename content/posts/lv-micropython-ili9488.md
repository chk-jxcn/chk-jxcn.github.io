---
title: "为桌面信息牌编译lvgl+micropython固件"
date: 2023-05-07
typora-root-url: ..\..\static
---

为xu大@xutoubee开源的桌面信息牌编译micropython固件，这样就可以自己随便愉快玩耍了。

大概有100K的heap可用，可能代码稍微多一点就要用mpy-cross了

<!--more-->

# 编译步骤



1. 参照https://github.com/lvgl/lv_micropython/blob/master/ports/esp32/README.md#setting-up-the-toolchain-and-esp-idf中的指导，安装esp-idf，我选择的是esp-idf v4.4，注意python应该安装3.8或以上，因为后面编译lv_micropython会有版本要求
2. 编译lv_micropython，如果按照首页的步骤，记得要`make submodules`
3. 添加ili9488并口的显示驱动，解压 [ili9488.zip](/file/ili9488.zip) 到ports/esp32，并且在main.c里合适的位置添加`ili9488_init()`，放在pyexe boot.py前面就可以
4. 重新编译`make LV_CFLAGS="-DLV_COLOR_DEPTH=16" BOARD=GENERIC`



如果修改了lvgl的配置，则要重新编译整个项目(我也不知道为什么，感觉是因为binding要重新编译)

```
rm build-GENERIC/config/sdkconfig.h
make LV_CFLAGS="-DLV_COLOR_DEPTH=16" BOARD=GENERIC
```



这个驱动是基于tft_espi修改的，现在只能给桌面信息牌用，I80的8位串口也就是MCU 8bit，支持RGB565和RGB666。

为了偷懒，把正反色塞进machine模块里了，固件里有，但是这个zip里没有，想要也可以选择自己在modmachine里参考现有的函数加上

```python
import machine
machine.invon() # 打开反显，ips屏幕需要打开反显
machine.invoff() # 关闭反显
```



基本上显示的驱动就是把tft_espi里面的init和并口通信部分copy出来，包装arduino的几个函数，理论上整个tft_espi也可以同样包一层，不过也用不上那么多。



# 固件下载



不知道micropython会不会有像nodemcu的cloud build那样的东西，也许大概是没有了，毕竟那么大的flash，全编译进去也占不了多大。(原来是有的=>https://github.com/pikasTech/PikaPython ，但是还在开发中，个人感觉可能还是ulisp这种形式更好，直接用arduino的库，移植到其他平台也很简单)

固件点这里下载=> [micropython.zip](/file/micropython.zip) 

里面包含好几个固件：

- micropython-RGB565-NOPERF-48L.bin： RGB565模式，关闭Performance monitor，缓冲区48线
- micropython-RGB565-PERF-48L.bin：RGB565模式，打开Performance monitor，缓冲区48线
- micropython-RGB666-NOPERF-20L.bin：RGB666模式，关闭Performance monitor，缓冲区20线
- micropython-RGB666-PERF-20L.bin：RGB666模式，打开Performance monitor，缓冲区20线



*RGB666模式因为一个像素要32位，分配48线会失败，所以这里用20线的缓冲区，如果有psram的话感觉可以分配一块全屏缓冲区。

**第一次刷固件前需要earse，以重新建立vfs，往vfs传输文件可以用ampy：`pip install adafruit-ampy`

(注意，此固件无法连接wifi，因为内存不够，连接wifi显示错误0x101，调整micropython的heap大小后就正常了，不过还没上传)

刷写固件可以用esptool.py或者flash_download_tool，配置如下：

esptool.py:

```
esptool.py -p (PORT) -b 460800 --before default_reset --after hard_reset \
--chip esp32  write_flash --flash_mode dio --flash_size detect   \
--flash_freq 40m 0x1000 build-GENERIC/bootloader/bootloader.bin  \
0x8000 build-GENERIC/partition_table/partition-table.bin 0x10000 \
build-GENERIC/micropython.bin
```

flash_download_tool

```
[DOWNLOAD PATH]
file_sel0 = 1
file_path0 = bin\bootloader.bin
file_offset0 = 0x00001000
file_sel1 = 1
file_path1 = bin\partition-table.bin
file_offset1 = 0x00008000
file_sel2 = 1
file_path2 = bin\micropython.bin
file_offset2 = 0x10000
```

![固件下载教程](/img/固件下载教程.png)



# 测试



用下面的代码测试

```python
import lvgl as lv
import time
lv.init()
scr = lv.obj()
lv.scr_load(scr)
time.sleep(1) # sleep 是必须的，不然会crash
from lv_utils import event_loop
event_loop = event_loop(freq=50) # 不能在C中调用task handler，因为分配内存引入了GC

cols = [0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00, 0xFF00FF, 0x00FFFF]
for x in range(6):
    ui_Panel2 = lv.obj(scr)
    ui_Panel2.set_width(int(320/12)+1)
    ui_Panel2.set_x(int(320/12*x))
    ui_Panel2.set_height(480)
    ui_Panel2.set_style_radius( 0, lv.PART.MAIN | lv.STATE.DEFAULT )
    ui_Panel2.set_style_bg_color( lv.color_hex( cols[x]), lv.PART.MAIN | lv.STATE.DEFAULT )
    ui_Panel2.set_style_bg_opa( 255, lv.PART.MAIN| lv.STATE.DEFAULT )
    ui_Panel2.set_style_bg_grad_dir( lv.GRAD_DIR.VER, lv.PART.MAIN | lv.STATE.DEFAULT )
    ui_Panel2.set_style_border_width( 0, lv.PART.MAIN | lv.STATE.DEFAULT )
    ui_Panel1 = lv.obj(scr)
    ui_Panel1.set_width(int(320/12)+1)
    ui_Panel1.set_x(int(320/12*(x+6)))
    ui_Panel1.set_height(480)
    ui_Panel1.set_style_radius( 0, lv.PART.MAIN | lv.STATE.DEFAULT )
    ui_Panel1.set_style_bg_color( lv.color_hex( 0xFFFFFF ), lv.PART.MAIN | lv.STATE.DEFAULT )
    ui_Panel1.set_style_bg_opa( 255, lv.PART.MAIN| lv.STATE.DEFAULT )
    ui_Panel1.set_style_bg_grad_color( lv.color_hex( cols[x]), lv.PART.MAIN | lv.STATE.DEFAULT )
    ui_Panel1.set_style_bg_grad_dir( lv.GRAD_DIR.VER, lv.PART.MAIN | lv.STATE.DEFAULT )
    ui_Panel1.set_style_border_width( 0, lv.PART.MAIN | lv.STATE.DEFAULT )
```



在不同固件下的表现：

### RGB666

![RGB666-2](/img/RGB666-2.png)



### RGB565

虽然只差一个bit，但是可以肉眼看出绿色显然和红蓝的颜色深度台阶并不一致，只不过色差没有上一篇里面显示图片那么大的差异

![RGB565-2](/img/RGB565-2.png)