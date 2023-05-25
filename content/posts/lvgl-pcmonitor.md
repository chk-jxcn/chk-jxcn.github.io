---
title: "使用lvgl+micropython开发一个无线电脑性能监控小面板"
date: 2023-05-13
categories:
- lvgl
typora-root-url: ..\..\static
thumbnailImagePosition: "left"
thumbnailImage: /img/pcmonitor-cover.png
---

在可视化布局工具的帮助下，开发一个界面真的很简单。

<!--more-->

# 原理

简单一句话说，就是利用LibreHardwareMonitor的web端口，获取电脑当前的传感器信息，展示到桌面信息牌上面。

具体开发分三步走：

1. 设计UI
2. 调试接口
3. 把UI和接口调用组装到一起





# UI设计

UI使用lvgl官方的squareline studio，这个东西bug非常多，增加删除元素，编辑组件，添加图片，都有可能让整个项目损毁。

个人建议，先添加元素，大体能看出最后什么样子，然后备份好，再考虑增加图片字体修改颜色什么的。一旦工程文件损毁就再也无法恢复了，ctrl-z也不行。

而且所有的文件名不能带中文，路径也不能用中文，虽然这玩意的界面看起来很现代，但是。。。

下面是我设计的UI，类似windows的任务管理器，把显示区域分割成固定大小的部分，这样可以自由选择需要显示的传感器了。



![](/img/monitor_ui.png)



# python程序

把自动生成的UI程序改一改，添加处理json的部分，点这里查看 =>  [pcmonitor.py](/file/pcmonitor.py) 

另外，因为内存实在不够用，把RGB666的固件改成了10线，并且为micropython分配了更多内存。

也把urequests集成进去了，点这里下载 =>  [micropython-10L.bin](/file/micropython-10L.bin) 

micropython开发lvgl程序真的很方便，不用编译，ui生成出来可以直接运行看效果，模拟器都不用，但是esp32内存太小了，CPU利用率的右边的那个网格，本来是想用LED来显示不同核心的负载的，但是我估摸内存可能不够了，所以没有加进去。

有几个麻烦的地方：

1. 显示时间是直接从http的header获取，但是没有同步到rtc，这样就知道上次同步传感器什么时候（或许前面要加个同步时间？），用ntp也许也可以，但是吃内存。
2. 因为内存太小，直接下载整个json会爆内存（大概30多K），只能每次读几十byte，然后分割字符串，这里是手动处理的
3. 下载json经常会超时，后来在这个固件里关闭了wifi睡眠模式，并且每次读取socket后都会sleep一点时间，让系统有时间去处理别的事情，看起来好一些了
4. 内存太容易爆了，lvgl缓冲区够了，micropython内存又不够分配，micropython分配多了，wifi又启动不了（要吃50KB），目前大概给lvgl缓冲区13KB（只能分在DRAM，因为会按byte操作），micropython 90KB左右。真有点螺蛳壳里做道场的感觉，抠抠搜搜不敢放开用内存。



目前只是显示信息，按照我的设想，应该还要加点颜色变化，来提醒用户系统负载过高

下面有一长条空白，我想可以用来显示一些图标，比如微信来消息的时候，就闪动微信的图标，方便全屏游戏下接收提醒。

也许以后可以用esp32s3重新打个板，这样就可以用到8M的psram了。



# 运行状态



![pcmonitor-running](/img/pcmonitor-running.jpg)

现在的图表是10个数据点，可以改成80个，会更好看一点，因为和宽度一样看起来更像点阵，没有抗锯齿看起来那么难受

```
    cui_Chart2.set_point_count(80)
```

下面是80点数据的

![pc-monitor-80p](/img/pc-monitor-80p.png)



和桌面信息牌对比，这里边框的颜色还没改

![lvgl-compare](/img/lvgl-compare.png)