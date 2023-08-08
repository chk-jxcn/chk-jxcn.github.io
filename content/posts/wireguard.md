---
title: "利用ipfw对wireguard进行网关分配以及大陆地址分流"
date: 2023-08-08
categories:
- vpn
typora-root-url: ..\..\static
---

用ipfw来路由wireguard不同peer的报文，算是比较折腾的做法了

<!--more-->



现在公司有好几个出口的网关，在不同的地点，现在想要做到的是：

员工通过wireguard接入后，可以通过网页选择哪个节点作为默认路由，最好也可以为自己添加一些路由。



# iptables



如果是用iptables，可以用用fwmark来分配peer进行路由的路由表。

比如下面这样

```
# iptable rules
iptables -A PREROUTING -m set --match-set [clients route to gateway1] src -j MARK --set-mark 1
iptables -A PREROUTING -m set --match-set [clients route to gateway2] src -j MARK --set-mark 2
# route rules
ip route add default gateway1 table 1
ip route add default gateway1 table 2
ip rule add fwmark 1 table 1
ip rule add fwmark 2 table 2
```



这样设置的话，虽然默认路由是能满足，但是如果为每个用户添加路由的话，则每个用户都要有个自己的路由表

```
iptables -A PREROUTING -s client1 -j MARK --set-mark 1
iptables -A PREROUTING -s client2 -j MARK --set-mark 2
iptables -A PREROUTING -s client3 -j MARK --set-mark 3
```



当然也可以用iptable来路由，假如每个用户都有2个ipset，里面是对应路由到对应网关的subnet，则需要添加iptables规则

```
iptable -A PREROUTING -s src of client1 -m set --match-set [clien1 gateway1 route] dst -j MARK --set-mark 1
iptable -A PREROUTING -s src of client1 -m set --match-set [clien1 gateway2 route] dst -j MARK --set-mark 2
iptable -A PREROUTING -s src of client2 -m set --match-set [clien2 gateway2 route] dst -j MARK --set-mark 1
iptable -A PREROUTING -s src of client2 -m set --match-set [clien2 gateway2 route] dst -j MARK --set-mark 2
```

上面都是我的假想，实际上我用的FreeBSD，显然没有iptables可用。



# IPFW



ipfw 是FreeBSD上默认的防火墙，有个很厉害的地方是，它的table支持key-value，也就是根据匹配到key来提取value，支持fwd，nat，skipto，call，tag等等，我在其他防火墙上从未见过有类似功能的东西。

ipfw用来做路由匹配最简单的方法是divert，利用userspace的程序来解析报文，然后根据需要走的路由返回一个rule number来skipto，不过需要自己实现程序来匹配ip地址，实现起来应该比较简单，但是性能调优应该蛮麻烦，只是用来满足现在的vpn带宽的话绰绰有余。

```
# disable one_pass
ipfw add 2000 divert 10086 ip from client subnet to any in via $if

ipfw add 3000 fwd tablearg from table(client default gw) to any out via $wan
ipfw add 3001 fwd gw1 from client subnet to any out via $wan
ipfw add 3002 fwd gw2 from client subnet to any out via $wan
```

假如wan有两个网关，这里可以根据divert的结果选择跳转到某个网关。

如果要做nat的话就需要加tag，因为nat只能在fwd之前，也就是说不能直接跳转到fwd了：

```
# disable one_pass
ipfw add 2000 divert 10086 ip from client subnet to any in via $if

ipfw add 3000 skipto 4000 from any to any tag 1
ipfw add 3001 skipto 4000 from any to any tag 2

ipfw add 4000 nat 1 from any to any via $wan

ipfw add 5001 fwd gw1 from client subnet to any out via $wan tagged 1
ipfw add 5002 fwd gw2 from client subnet to any out via $wan tagged 2
```



不过这里有一个小问题，如果有两个wan口，每个wan口有两个网关怎么办？这里的问题是nat只在出口的接口上转换，转换后不会重新路由。所以有多个wan的话还是需要添加路由表，但是路由表只是选哪个接口出去，这样就只需要等于wan口数的路由表即可。

```
# disable one_pass
ipfw add 2000 divert 10086 ip from client subnet to any in via $if

ipfw add 3000 skipto 3100 from any to any tag 1
ipfw add 3001 skipto 3102 from any to any tag 2
ipfw add 3002 skipto 3100 from any to any tag 3
ipfw add 3003 skipto 3103 from any to any tag 4

ipfw add 3100 setfib 1 from any to any
ipfw add 3101 skipto 4000 from any to any
ipfw add 3102 setfib 2 from any to any

ipfw add 4000 nat 1 from any to any via $wan1
ipfw add 4001 nat 2 from any to any via $wan2

ipfw add 5000 fwd gw1 from client subnet to any out via $wan1 tagged 1
ipfw add 5001 fwd gw2 from client subnet to any out via $wan2 tagged 2
ipfw add 5002 fwd gw3 from client subnet to any out via $wan1 tagged 3
ipfw add 5003 fwd gw4 from client subnet to any out via $wan2 tagged 4
```

在nat之前指定路由表，就可以指定报文的出口接口，这样报文才会路由到不同的出口。



如果不用divert则可以使用类似iptables的规则，不过ipfw的table支持参数，因此也就不需要那么多条规则，这也是我现在在用的规则

```
03000 skipto tablearg ip from table(wg_net) to any
03002 skipto 6000 tag tablearg ip from 192.168.195.2 to table(192.168.195.2) in via vmx0
03004 skipto 6000 tag tablearg ip from 192.168.195.3 to table(192.168.195.3) in via vmx0
03006 skipto 6000 tag tablearg ip from 192.168.195.4 to table(192.168.195.4) in via vmx0
03008 skipto 6000 tag tablearg ip from 192.168.195.5 to table(192.168.195.5) in via vmx0
03010 skipto 6000 tag tablearg ip from 192.168.195.6 to table(192.168.195.6) in via vmx0
03012 skipto 6000 tag tablearg ip from 192.168.195.7 to table(192.168.195.7) in via vmx0
...(many clients)

04001 skipto 6000 ip from table(no_cn_src) to any
04002 skipto 6000 tag 1 ip from 192.168.195.0/24 to table(cn) in via vmx0
05000 skipto 6000 tag 5 ip from 192.168.195.0/24 to 192.168.77.0/24 in via vmx0
05001 skipto 6000 tag 3 ip from 192.168.195.0/24 to 192.168.64.0/18 in via vmx0
05002 skipto 6000 tag tablearg ip from table(wg_cli_gw) to any in via vmx0
05003 skipto 6000 tag 2 ip from 192.168.195.0/24 to any in via vmx0
05004 skipto 6000 tag 3 ip from 192.168.2.0/24 to 192.168.64.0/18 in via vmx0
06001 setfib 1 tagged 1
06002 setfib 2 tagged 2
06003 setfib 2 tagged 3
06004 setfib 3 tagged 4
06005 setfib 3 tagged 5
07001 nat 1 ip from any to 192.168.2.15 in via vmx0
07002 nat 2 ip from any to 192.168.196.3 in via tap0
07003 nat 3 ip from any to 192.168.197.3 in via tap1
07004 nat 1 ip from not 192.168.2.0/24 to not 192.168.195.0/24,192.168.2.0/24 out via vmx0
07005 nat 2 ip from not 192.168.196.0/24 to any out via tap0
07006 nat 3 ip from not 192.168.197.0/24 to any out via tap1
08001 fwd 192.168.2.84 ip from any to any out via vmx0 tagged 1
08002 fwd 192.168.196.2 ip from any to any out via tap0 tagged 2
08003 fwd 192.168.196.1 ip from any to any out via tap0 tagged 3
08004 fwd 192.168.197.2 ip from any to any out via tap1 tagged 4
08005 fwd 192.168.197.1 ip from any to any out via tap1 tagged 5

```

每个和client的ip一样的table存储这个用户的自定义路由，wg_cli_gw存储默认路由，no_cn_src存储没有路由china ip的client ip，cn则是china ip列表

所以如果需要修改默认路由和用户自定义路由，只需要修改这两个table即可，ipfw规则和路由表都不需要变动。

如果实现divert的用户程序的话，应该和table的算法差不多，个人感觉，除非有特别多的client，不然性能上没什么优势。

用pf的话，基本上和iptables一样，需要在入口打tag，因为出口一定会先进行nat，这样按照ip就匹配不到了。不像ipfw，出口可以在nat之前进行匹配。



# DNS



每一个网关都有两个对应的DNS，分别对应china ip是否开启，这里我用dnsmasq套overtrue来解决dns forward和解析， ipfw里面使用一个nat table来重定向53

```
02001 nat tablearg udp from 192.168.2.15 4053-4057 to table(dns_nat) out via vmx0
02002 nat tablearg udp from table(dns_nat) to any 53 in via vmx0
```

