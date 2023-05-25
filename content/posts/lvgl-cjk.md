---
title: "在lvgl中显示中文"
date: 2023-05-09
typora-root-url: ..\..\static
---

lvgl有很多种方法显示中文，但是esp32的内存太小，有一些方法就显得不太现实。
下面都是基于micropython的测试，lvgl 9.0，不过其他的版本应该差不太多

<!--more-->



# lvgl显示中文的方法

## 嵌入字体

把字形对应的bitmap放在C源文件的数组中，内置的字体基本上是这种形式，lvgl还提供了一个在线转换工具。

以前我在u8g2上面试过类似的东西https://zhuanlan.zhihu.com/p/60200639 ，不过u8g2就完全只是点阵字体，字体里面完全不包含点阵之外的信息，lvgl添加了一些字体信息在源文件里面

## 运行时加载

这里又分好几种：

1. 加载lvgl自己的字体，https://github.com/lvgl/lv_font_conv/blob/master/doc/font_spec.md，这是一个lvgl自己搞的font格式，有一些限制，比如数量，和颜色深度，但是基本上8bit的深度肉眼也看不太出来了。
   - 好处：渲染速度非常快；比较方便，官方自带工具支持
   - 缺点：非常占内存，需要把所有的位图加载到内存中；文件体积过大；字体高度固定
2. 加载freetype字体，可以用freetype或者tiny_ttf，lv_micropython默认就开启了tiny_ttf的支持，所以我这里只试了tiny_ttf，要在esp32上用freetype应该也不容易，要移植。
   - 好处：占用空间很小，不管是存储还是内存，tiny_ttf有一个可以编译期设定的LRU缓存，默认是4096byte，不过我增加大小尝试后感觉对性能没改善；字体大小随意设置，因为是运行时从矢量字体渲染出来的
   - 缺点：渲染特别特别慢，如果是动画，简直惨不忍睹，一秒一帧都难

3. 使用imgfont，这个我没有试，参考官方文档https://docs.lvgl.io/master/others/imgfont.html



# micropython例子

因为micropython本身已经占了很多空间，所以内嵌加不了多少字体，但是micropython使用运行时加载字体很方便，用下面这个例子来测试一下

```python
import lvgl as lv
import time
lv.init()
scr = lv.obj()
lv.scr_load(scr)
time.sleep(1)
from lv_utils import event_loop
event_loop = event_loop(freq=20)

# ...

import fs_driver
fs_drv = lv.fs_drv_t()
fs_driver.fs_register(fs_drv, 'S')
# font_Number = lv.font_load("S:font.bin") # 加载bin字体
# font_Number = lv.tiny_ttf_create_file("S:font.ttf", 30) # 加载freetype字体

btn = lv.btn(scr)
btn.align(lv.ALIGN.CENTER, 0, 0)
label = lv.label(btn)
label.set_text("荆轲刺秦王，两条毛腿肩上扛")
#label.set_align( lv.ALIGN.CENTER)
label.set_style_text_color( lv.color_hex( 0xFFFFFF ), lv.PART.MAIN | lv.STATE.DEFAULT )
label.set_style_text_opa( 255, lv.PART.MAIN| lv.STATE.DEFAULT )
label.set_style_text_font( font_Number, lv.PART.MAIN | lv.STATE.DEFAULT )
```

需要注意的是，lvgl的bin字体不能太大，否则加载会失败，我最大只加载到40k左右，尽量还是小一点，因为有时没有检测错误的机会就直接reset了。

freetype就没有限制了，随便多大都可以，因为只有渲染的时候才会去读，所以特别特别慢，缓存可能设置大一点会有用，毕竟不用重新生成bitmap了。



# 效果



其实看起来差不多，起码肉眼看不出区别，不过RGB666有个问题，因为缓冲区只有20线，所以只要字体高度超过20，那么滚动动画时就会有撕裂感，RGB565就不会，因为高度有48线。

![](/img/fontbin.png)

![](/img/fontttf.png)

