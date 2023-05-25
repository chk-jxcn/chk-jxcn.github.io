---
title: "Virtual DSM 逆向笔记 (在kvm中运行VDSM)"
date: 2022-04-16
categories:
- VDSM
- DSM
typora-root-url: ..\..\static
---





DSM中使用qemu来运行VDSM，那么不考虑串口通信，能直接在kvm中启动VDSM吗？

<!--more-->



{{< toc >}}



# 1. redpill小组的尝试

参考文档：[https://github.com/RedPill-TTG/dsm-research/blob/master/VDSM/vdsm-investigation.md](https://github.com/RedPill-TTG/dsm-research/blob/master/VDSM/vdsm-investigation.md)

根据redpill的实验，VDSM只检查vhost scsi的地址，然后映射到synoboot，直接设置qemu中的参数就可以达到同样的效果。



其实DSM中是使用virt来运行的，可以直接看到配置，虚拟机的uuid会上传到服务器，所以打了个码

```xml
<domain type='kvm' id='2' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>xxxxxxxxUUIDxxxxxxxxxxx</name>
  <uuid>xxxxxxxxUUIDxxxxxxxxxxx</uuid>
  <title>DSM instance: test</title>
  <memory unit='KiB'>1048576</memory>
  <currentMemory unit='KiB'>1048576</currentMemory>
  <memoryBacking>
    <hugepages/>
    <locked/>
  </memoryBacking>
  <vcpu placement='static'>1</vcpu>
  <resource>
    <partition>/machine</partition>
  </resource>
  <os>
    <type arch='x86_64' machine='pc-i440fx-2.2'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
    <hap/>
  </features>
  <cpu mode='host-passthrough'>
    <topology sockets='1' cores='1' threads='1'/>
  </cpu>
  <clock offset='variable' adjustment='-6' basis='utc'>
    <timer name='rtc' tickpolicy='catchup' track='guest'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/local/bin/qemu-system-x86_64</emulator>
    <controller type='usb' index='0' model='piix3-uhci'>
      <alias name='usb'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'>
      <alias name='pci.0'/>
    </controller>
    <controller type='virtio-serial' index='0'>
      <alias name='virtio-serial0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </controller>
    <interface type='ethernet'>
      <mac address='02:11:32:2b:0f:e6'/>
      <script path='no'/>
      <target dev='tap0211322b0fe6'/>
      <model type='virtio'/>
      <alias name='net0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </interface>
    <serial type='pty'>
      <source path='/dev/pts/0'/>
      <target port='0'/>
      <alias name='serial0'/>
    </serial>
    <console type='pty' tty='/dev/pts/0'>
      <source path='/dev/pts/0'/>
      <target type='serial' port='0'/>
      <alias name='serial0'/>
    </console>
    <channel type='unix'>
      <source mode='bind' path='/tmp/synohostvmcomm/guest_interface/xxxxxxxxUUIDxxxxxxxxxxx'/>
      <target type='virtio' name='vchannel' state='connected'/>
      <alias name='channel0'/>
      <address type='virtio-serial' controller='0' bus='0' port='1'/>
    </channel>
    <memballoon model='virtio'>
      <alias name='balloon0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </memballoon>
    <rng model='virtio'>
      <backend model='random'>/dev/random</backend>
      <alias name='rng0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x1c' function='0x0'/>
    </rng>
  </devices>
  <qemu:commandline>
    <qemu:arg value='-device'/>
    <qemu:arg value='vhost-scsi-pci,virtqueue_size=256,cmd_per_lun=250,wwpn=naa.119ec5c1-4c72-490c-8e30-1e0551503def,addr=0xa,id=vdisk_119ec5c1-4c72-490c-8e30-1e0551503def,set_driverok=off,num_queues=1,max_sectors=16384,boot_tpgt=1,bootindex=1'/>
    <qemu:arg value='-device'/>
    <qemu:arg value='vhost-scsi-pci,virtqueue_size=256,cmd_per_lun=250,wwpn=naa.b447b54f-6941-4c10-b5be-01f23b872556,addr=0xb,id=vdisk_b447b54f-6941-4c10-b5be-01f23b872556,set_driverok=off,num_queues=1,max_sectors=16384,boot_tpgt=1,bootindex=2'/>
    <qemu:arg value='-device'/>
    <qemu:arg value='vhost-scsi-pci,virtqueue_size=256,cmd_per_lun=250,wwpn=naa.0a4aecb5-61c6-4f27-a9f6-46fdbacc45c1,addr=0xc,id=vdisk_0a4aecb5-61c6-4f27-a9f6-46fdbacc45c1,set_driverok=off,num_queues=1,max_sectors=16384,boot_tpgt=1,bootindex=3'/>
  </qemu:commandline>
</domain>

```



其中DSM运行的QEMU参数，有virt的话这部分其实没什么必要了

```
/usr/local/bin/qemu-system-x86_64 -name xxxxxxxxUUIDxxxxxxxxxxx -S -machine pc-i440fx-2.2,accel=kvm,usb=off -cpu host -m 1024 -mem-prealloc -mem-path /dev/virtualization/libvirt/qemu -realtime mlock=on -smp 1,sockets=1,cores=1,threads=1 -uuid xxxxxxxxUUIDxxxxxxxxxxx -nographic -no-user-config -nodefaults -chardev socket,id=charmonitor,path=/var/lib/libvirt/qemu/d21d9bf9-8a8d-40a4-912c-8760914e9442.monitor,server,nowait -mon chardev=charmonitor,id=monitor,mode=control -rtc base=2022-04-05T13:57:31,clock=vm,driftfix=slew -global kvm-pit.lost_tick_policy=discard -no-hpet -no-shutdown -boot strict=on -device piix3-usb-uhci,id=usb,bus=pci.0,addr=0x1.0x2 -device virtio-serial-pci,id=virtio-serial0,bus=pci.0,addr=0x3 -netdev tap,ifname=tap0211322b0fe6,script=no,id=hostnet0,vhost=on,vhostfd=20 -device virtio-net-pci,netdev=hostnet0,id=net0,mac=02:11:32:2b:0f:e6,bus=pci.0,addr=0x2 -chardev pty,id=charserial0 -device isa-serial,chardev=charserial0,id=serial0 -chardev socket,id=charchannel0,path=/tmp/synohostvmcomm/guest_interface/d21d9bf9-8a8d-40a4-912c-8760914e9442,server,nowait -device virtserialport,bus=virtio-serial0.0,nr=1,chardev=charchannel0,id=channel0,name=vchannel -device virtio-balloon-pci,id=balloon0,bus=pci.0,addr=0x4 -object rng-random,id=objrng0,filename=/dev/random -device virtio-rng-pci,rng=objrng0,id=rng0,bus=pci.0,addr=0x1c -device vhost-scsi-pci,virtqueue_size=256,cmd_per_lun=250,wwpn=naa.119ec5c1-4c72-490c-8e30-1e0551503def,addr=0xa,id=vdisk_119ec5c1-4c72-490c-8e30-1e0551503def,set_driverok=off,num_queues=1,max_sectors=16384,boot_tpgt=1,bootindex=1 -device vhost-scsi-pci,virtqueue_size=256,cmd_per_lun=250,wwpn=naa.b447b54f-6941-4c10-b5be-01f23b872556,addr=0xb,id=vdisk_b447b54f-6941-4c10-b5be-01f23b872556,set_driverok=off,num_queues=1,max_sectors=16384,boot_tpgt=1,bootindex=2 -device vhost-scsi-pci,virtqueue_size=256,cmd_per_lun=250,wwpn=naa.0a4aecb5-61c6-4f27-a9f6-46fdbacc45c1,addr=0xc,id=vdisk_0a4aecb5-61c6-4f27-a9f6-46fdbacc45c1,set_driverok=off,num_queues=1,max_sectors=16384,boot_tpgt=1,bootindex=3 -msg timestamp=on
```



# 2. 试一下



这里我照抄了这部分的参数，其他先随便设置一下

```
qemu-system-x86_64 -nographic -netdev tap,ifname=tap0211322b0fe6,script=no,id=hostnet0 -device virtio-net-pci,netdev=hostnet0,id=net0,mac=02:11:32:2b:0f:e6 -m 1024 -device virtio-serial-pci,id=virtio-serial0,bus=pci.0 -chardev socket,id=charchannel0,path=d21d9bf9-8a8d-40a4-912c-8760914e9442,server,nowait -device virtserialport,bus=virtio-serial0.0,nr=1,chardev=charchannel0,id=channel0,name=vchannel -device virtio-scsi-pci,id=hw-synoboot,bus=pci.0,addr=0xa -drive file=boot2.img,if=none,id=drive-synoboot,format=raw,cache=none,aio=native,detect-zeroes=on -device scsi-hd,bus=hw-synoboot.0,channel=0,scsi-id=0,lun=0,drive=drive-synoboot,id=synoboot0,bootindex=1 -device virtio-scsi-pci,id=hw-synosys,bus=pci.0,addr=0xb -drive file=sys.img,if=none,id=drive-synosys,format=raw,cache=none,aio=native,detect-zeroes=on -device scsi-hd,bus=hw-synosys.0,channel=0,scsi-id=0,lun=0,drive=drive-synosys,id=synosys0,bootindex=2 -device virtio-scsi-pci,id=hw-userdata,bus=pci.0,addr=0xc -drive file=data.img,if=none,id=drive-userdata,format=raw,cache=none,aio=native,detect-zeroes=on -device scsi-hd,bus=hw-userdata.0,channel=0,scsi-id=0,lun=0,drive=drive-userdata,id=userdata0,bootindex=3 -rtc base=2022-04-05T13:57:31,clock=vm,driftfix=slew -enable-kvm
```



看起来基本上都能运行，只是有一部分检查无法通过

```
qemu-system-x86_64: warning: host doesn't support requested feature: CPUID.80000001H:ECX.svm [bit 2]
SeaBIOS (version 1.13.0-1ubuntu1.1)


iPXE (http://ipxe.org) 00:03.0 CA00 PCI2.10 PnP PMM+3FF8C7E0+3FECC7E0 CA00



Booting from Hard Disk...
GRUB Loading stage1.5.


GRUB loading, please wait...
[    0.000000] Initializing cgroup subsys cpuset
[    0.000000] Initializing cgroup subsys cpu
[    0.000000] Initializing cgroup subsys cpuacct
[    0.000000] Linux version 4.4.180+ (root@build15) (gcc version 7.5.0 (GCC) ) #42218 SMP Mon Oct 18 19:17:55 CST1
[    0.000000] Command line: root=/dev/sda1 ihd_num=0 netif_num=0 syno_hw_version=VirtualDSM vender_format_version5
[    0.000000] KERNEL supported cpus:
[    0.000000]   Intel GenuineIntel
[    0.000000]   AMD AuthenticAMD
[    0.000000] x86/fpu: Legacy x87 FPU detected.
[    0.000000] e820: BIOS-provided physical RAM map:
[    0.000000] BIOS-e820: [mem 0x0000000000000000-0x000000000009fbff] usable
[    0.000000] BIOS-e820: [mem 0x000000000009fc00-0x000000000009ffff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000000f0000-0x00000000000fffff] reserved
[    0.000000] BIOS-e820: [mem 0x0000000000100000-0x000000003ffd6fff] usable
[    0.000000] BIOS-e820: [mem 0x000000003ffd7000-0x000000003fffffff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000feffc000-0x00000000feffffff] reserved
[    0.000000] BIOS-e820: [mem 0x00000000fffc0000-0x00000000ffffffff] reserved
[    0.000000] NX (Execute Disable) protection: active
[    0.000000] extended physical RAM map:
[    0.000000] reserve setup_data: [mem 0x0000000000000000-0x000000000009fbff] usable
[    0.000000] reserve setup_data: [mem 0x000000000009fc00-0x000000000009ffff] reserved
[    0.000000] reserve setup_data: [mem 0x00000000000f0000-0x00000000000fffff] reserved
[    0.000000] reserve setup_data: [mem 0x0000000000100000-0x0000000001df1da7] usable
[    0.000000] reserve setup_data: [mem 0x0000000001df1da8-0x0000000001df1db7] usable
[    0.000000] reserve setup_data: [mem 0x0000000001df1db8-0x000000003ffd6fff] usable
[    0.000000] reserve setup_data: [mem 0x000000003ffd7000-0x000000003fffffff] reserved
[    0.000000] reserve setup_data: [mem 0x00000000feffc000-0x00000000feffffff] reserved
[    0.000000] reserve setup_data: [mem 0x00000000fffc0000-0x00000000ffffffff] reserved
[    0.000000] SMBIOS 2.8 present.
[    0.000000] Hypervisor detected: KVM
[    0.000000] Kernel/User page tables isolation: disabled
[    0.000000] e820: last_pfn = 0x3ffd7 max_arch_pfn = 0x400000000
[    0.000000] x86/PAT: Configuration [0-7]: WB  WT  UC- UC  WB  WT  UC- UC
[    0.000000] found SMP MP-table at [mem 0x000f5c80-0x000f5c8f] mapped at [ffff8800000f5c80]
[    0.000000] RAMDISK: [mem 0x3faa1000-0x3ffc6fff]
[    0.000000] ACPI: Early table checksum verification disabled
[    0.000000] ACPI: RSDP 0x00000000000F5AB0 000014 (v00 BOCHS )
[    0.000000] ACPI: RSDT 0x000000003FFE156F 000030 (v01 BOCHS  BXPCRSDT 00000001 BXPC 00000001)
[    0.000000] ACPI: FACP 0x000000003FFE144B 000074 (v01 BOCHS  BXPCFACP 00000001 BXPC 00000001)
[    0.000000] ACPI: DSDT 0x000000003FFE0040 00140B (v01 BOCHS  BXPCDSDT 00000001 BXPC 00000001)
[    0.000000] ACPI: FACS 0x000000003FFE0000 000040
[    0.000000] ACPI: APIC 0x000000003FFE14BF 000078 (v01 BOCHS  BXPCAPIC 00000001 BXPC 00000001)
[    0.000000] ACPI: HPET 0x000000003FFE1537 000038 (v01 BOCHS  BXPCHPET 00000001 BXPC 00000001)
[    0.000000] kvm-clock: Using msrs 4b564d01 and 4b564d00
[    0.000000] kvm-clock: cpu 0, msr 0:3ffd5001, primary cpu clock
[    0.000000] kvm-clock: using sched offset of 3659902059 cycles
[    0.000000] clocksource: kvm-clock: mask: 0xffffffffffffffff max_cycles: 0x1cd42e4dffb, max_idle_ns: 8815905914s
[    0.000000] Zone ranges:
[    0.000000]   DMA      [mem 0x0000000000001000-0x0000000000ffffff]
[    0.000000]   DMA32    [mem 0x0000000001000000-0x000000003ffd6fff]
[    0.000000]   Normal   empty
[    0.000000] Movable zone start for each node
[    0.000000] Early memory node ranges
[    0.000000]   node   0: [mem 0x0000000000001000-0x000000000009efff]
[    0.000000]   node   0: [mem 0x0000000000100000-0x000000003ffd6fff]
[    0.000000] Initmem setup node 0 [mem 0x0000000000001000-0x000000003ffd6fff]
[    0.000000] ACPI: PM-Timer IO Port: 0x608
[    0.000000] ACPI: LAPIC_NMI (acpi_id[0xff] dfl dfl lint[0x1])
[    0.000000] IOAPIC[0]: apic_id 0, version 17, address 0xfec00000, GSI 0-23
[    0.000000] ACPI: INT_SRC_OVR (bus 0 bus_irq 0 global_irq 2 dfl dfl)
[    0.000000] ACPI: INT_SRC_OVR (bus 0 bus_irq 5 global_irq 5 high level)
[    0.000000] ACPI: INT_SRC_OVR (bus 0 bus_irq 9 global_irq 9 high level)
[    0.000000] ACPI: INT_SRC_OVR (bus 0 bus_irq 10 global_irq 10 high level)
[    0.000000] ACPI: INT_SRC_OVR (bus 0 bus_irq 11 global_irq 11 high level)
[    0.000000] Using ACPI (MADT) for SMP configuration information
[    0.000000] ACPI: HPET id: 0x8086a201 base: 0xfed00000
[    0.000000] smpboot: Allowing 1 CPUs, 0 hotplug CPUs
[    0.000000] PM: Registered nosave memory: [mem 0x00000000-0x00000fff]
[    0.000000] PM: Registered nosave memory: [mem 0x0009f000-0x0009ffff]
[    0.000000] PM: Registered nosave memory: [mem 0x000a0000-0x000effff]
[    0.000000] PM: Registered nosave memory: [mem 0x000f0000-0x000fffff]
[    0.000000] PM: Registered nosave memory: [mem 0x01df1000-0x01df1fff]
[    0.000000] PM: Registered nosave memory: [mem 0x01df1000-0x01df1fff]
[    0.000000] e820: [mem 0x40000000-0xfeffbfff] available for PCI devices
[    0.000000] Booting paravirtualized kernel on KVM
[    0.000000] clocksource: refined-jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 191096994039141s
[    0.000000] setup_percpu: NR_CPUS:128 nr_cpumask_bits:128 nr_cpu_ids:1 nr_node_ids:1
[    0.000000] PERCPU: Embedded 33 pages/cpu @ffff88003f800000 s95448 r8192 d31528 u2097152
[    0.000000] KVM setup async PF for cpu 0
[    0.000000] kvm-stealtime: cpu 0, msr 3f80f180
[    0.000000] Built 1 zonelists in Zone order, mobility grouping on.  Total pages: 257887
[    0.000000] Kernel command line: root=/dev/sda1 ihd_num=0 netif_num=0 syno_hw_version=VirtualDSM vender_format_5
[    0.000000] Internal HD num: 0
[    0.000000] Internal netif num: 0
[    0.000000] Synology Hardware Version: VirtualDSM
[    0.000000] Vender format version: 2
[    0.000000] PID hash table entries: 4096 (order: 3, 32768 bytes)
[    0.000000] Dentry cache hash table entries: 131072 (order: 8, 1048576 bytes)
[    0.000000] Inode-cache hash table entries: 65536 (order: 7, 524288 bytes)
[    0.000000] Memory: 1012832K/1048020K available (5354K kernel code, 868K rwdata, 1672K rodata, 1004K init, 1556)
[    0.000000] Hierarchical RCU implementation.
[    0.000000]  Build-time adjustment of leaf fanout to 64.
[    0.000000]  RCU restricting CPUs from NR_CPUS=128 to nr_cpu_ids=1.
[    0.000000] RCU: Adjusting geometry for rcu_fanout_leaf=64, nr_cpu_ids=1
[    0.000000] NR_IRQS:8448 nr_irqs:256 16
[    0.000000] Console: colour dummy device 80x25
[    0.000000] console [ttyS0] enabled
[    0.000000] clocksource: hpet: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 19112604467 ns
[    0.000000] tsc: Detected 2112.012 MHz processor
[    0.187005] Calibrating delay loop (skipped) preset value.. 4224.02 BogoMIPS (lpj=2112012)
[    0.189288] pid_max: default: 32768 minimum: 301
[    0.190602] ACPI: Core revision 20150930
[    0.192718] ACPI: 1 ACPI AML tables successfully acquired and loaded
[    0.194642] Security Framework initialized
[    0.195897] AppArmor: AppArmor initialized
[    0.197064] Mount-cache hash table entries: 2048 (order: 2, 16384 bytes)
[    0.198915] Mountpoint-cache hash table entries: 2048 (order: 2, 16384 bytes)
[    0.201727] Initializing cgroup subsys io
[    0.202915] Initializing cgroup subsys memory
[    0.204193] Initializing cgroup subsys devices
[    0.205641] Initializing cgroup subsys freezer
[    0.207391] CPU: Physical Processor ID: 0
[    0.208926] Last level iTLB entries: 4KB 0, 2MB 0, 4MB 0
[    0.210516] Last level dTLB entries: 4KB 0, 2MB 0, 4MB 0, 1GB 0
[    0.212211] Speculative Store Bypass: Vulnerable
[    0.262384] Freeing SMP alternatives memory: 24K
[    0.287843] x2apic enabled
[    0.290081] Switched APIC routing to physical x2apic.
[    0.296761] ..TIMER: vector=0x30 apic1=0 pin1=2 apic2=-1 pin2=-1
[    0.399724] smpboot: CPU0: Intel QEMU Virtual CPU version 2.5+ (family: 0x6, model: 0x6, stepping: 0x3)
[    0.402455] Performance Events: Broken PMU hardware detected, using software events only.
[    0.405653] Failed to access perfctr msr (MSR c2 is 0)
[    0.407007] x86: Booted up 1 node, 1 CPUs
[    0.408108] smpboot: Total of 1 processors activated (4224.02 BogoMIPS)
[    0.410926] devtmpfs: initialized
[    0.412107] clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 1911260446275000 ns
[    0.414466] futex hash table entries: 256 (order: 2, 16384 bytes)
[    0.416289] NET: Registered protocol family 16
[    0.417629] cpuidle: using governor ladder
[    0.418700] cpuidle: using governor menu
[    0.419795] ACPI: bus type PCI registered
[    0.420822] acpiphp: ACPI Hot Plug PCI Controller Driver version: 0.5
[    0.422617] PCI: Using configuration type 1 for base access
[    0.426823] ACPI: Added _OSI(Module Device)
[    0.427928] ACPI: Added _OSI(Processor Device)
[    0.429092] ACPI: Added _OSI(3.0 _SCP Extensions)
[    0.430317] ACPI: Added _OSI(Processor Aggregator Device)
[    0.433266] ACPI: Interpreter enabled
[    0.434215] ACPI: (supports S0 S4 S5)
[    0.435197] ACPI: Using IOAPIC for interrupt routing
[    0.436465] PCI: Using host bridge windows from ACPI; if necessary, use "pci=nocrs" and report a bug
[    0.441606] ACPI: PCI Root Bridge [PCI0] (domain 0000 [bus 00-ff])
[    0.443217] acpi PNP0A03:00: _OSC: OS supports [ASPM ClockPM Segments MSI]
[    0.444906] acpi PNP0A03:00: _OSC failed (AE_NOT_FOUND); disabling ASPM
[    0.446597] acpi PNP0A03:00: fail to add MMCONFIG information, can't access extended PCI configuration space un.
[    0.449724] acpiphp: Slot [3] registered
[    0.450869] acpiphp: Slot [4] registered
[    0.451947] acpiphp: Slot [5] registered
[    0.452979] acpiphp: Slot [6] registered
[    0.454024] acpiphp: Slot [7] registered
[    0.455058] acpiphp: Slot [8] registered
[    0.456104] acpiphp: Slot [9] registered
[    0.457182] acpiphp: Slot [10] registered
[    0.458266] acpiphp: Slot [11] registered
[    0.459357] acpiphp: Slot [12] registered
[    0.460765] acpiphp: Slot [13] registered
[    0.461917] acpiphp: Slot [14] registered
[    0.462962] acpiphp: Slot [15] registered
[    0.464036] acpiphp: Slot [16] registered
[    0.465084] acpiphp: Slot [17] registered
[    0.466137] acpiphp: Slot [18] registered
[    0.467245] acpiphp: Slot [19] registered
[    0.468328] acpiphp: Slot [20] registered
[    0.469441] acpiphp: Slot [21] registered
[    0.470457] acpiphp: Slot [22] registered
[    0.471552] acpiphp: Slot [23] registered
[    0.472600] acpiphp: Slot [24] registered
[    0.473667] acpiphp: Slot [25] registered
[    0.474737] acpiphp: Slot [26] registered
[    0.475790] acpiphp: Slot [27] registered
[    0.476867] acpiphp: Slot [28] registered
[    0.477883] acpiphp: Slot [29] registered
[    0.478925] acpiphp: Slot [30] registered
[    0.479960] acpiphp: Slot [31] registered
[    0.480935] PCI host bridge to bus 0000:00
[    0.482029] pci_bus 0000:00: root bus resource [io  0x0000-0x0cf7 window]
[    0.483737] pci_bus 0000:00: root bus resource [io  0x0d00-0xffff window]
[    0.485369] pci_bus 0000:00: root bus resource [mem 0x000a0000-0x000bffff window]
[    0.487172] pci_bus 0000:00: root bus resource [mem 0x40000000-0xfebfffff window]
[    0.488976] pci_bus 0000:00: root bus resource [mem 0x100000000-0x17fffffff window]
[    0.490762] pci_bus 0000:00: root bus resource [bus 00-ff]
[    0.497788] pci 0000:00:01.1: legacy IDE quirk: reg 0x10: [io  0x01f0-0x01f7]
[    0.499493] pci 0000:00:01.1: legacy IDE quirk: reg 0x14: [io  0x03f6]
[    0.501076] pci 0000:00:01.1: legacy IDE quirk: reg 0x18: [io  0x0170-0x0177]
[    0.502805] pci 0000:00:01.1: legacy IDE quirk: reg 0x1c: [io  0x0376]
[    0.505812] pci 0000:00:01.3: quirk: [io  0x0600-0x063f] claimed by PIIX4 ACPI
[    0.507574] pci 0000:00:01.3: quirk: [io  0x0700-0x070f] claimed by PIIX4 SMB
[    0.570304] ACPI: PCI Interrupt Link [LNKA] (IRQs 5 *10 11)
[    0.574866] ACPI: PCI Interrupt Link [LNKB] (IRQs 5 *10 11)
[    0.579149] ACPI: PCI Interrupt Link [LNKC] (IRQs 5 10 *11)
[    0.583727] ACPI: PCI Interrupt Link [LNKD] (IRQs 5 10 *11)
[    0.588147] ACPI: PCI Interrupt Link [LNKS] (IRQs *9)
[    0.592641] ACPI: Enabled 2 GPEs in block 00 to 0F
[    0.597781] vgaarb: setting as boot device: PCI:0000:00:02.0
[    0.599130] vgaarb: device added: PCI:0000:00:02.0,decodes=io+mem,owns=io+mem,locks=none
[    0.601005] vgaarb: loaded
[    0.601659] vgaarb: bridge control possible 0000:00:02.0
[    0.603400] SCSI subsystem initialized
[    0.604825] pps_core: LinuxPPS API ver. 1 registered
[    0.606095] pps_core: Software ver. 5.3.6 - Copyright 2005-2007 Rodolfo Giometti <giometti@linux.it>
[    0.608332] PTP clock support registered
[    0.609710] PCI: Using ACPI for IRQ routing
[    0.612488] HPET: 3 timers in total, 0 timers will be used for per-cpu timer
[    0.614527] clocksource: Switched to clocksource kvm-clock
[    0.623386] AppArmor: AppArmor Filesystem Enabled
[    0.624572] pnp: PnP ACPI init
[    0.625799] pnp: PnP ACPI: found 6 devices
[    0.633321] clocksource: acpi_pm: mask: 0xffffff max_cycles: 0xffffff, max_idle_ns: 2085701024 ns
[    0.635680] NET: Registered protocol family 2
[    0.637498] TCP established hash table entries: 8192 (order: 4, 65536 bytes)
[    0.639227] TCP bind hash table entries: 8192 (order: 5, 131072 bytes)
[    0.640828] TCP: Hash tables configured (established 8192 bind 8192)
[    0.642451] UDP hash table entries: 512 (order: 2, 16384 bytes)
[    0.643947] UDP-Lite hash table entries: 512 (order: 2, 16384 bytes)
[    0.645570] NET: Registered protocol family 1
[    0.646730] pci 0000:00:00.0: Limiting direct PCI/PCI transfers
[    0.648210] pci 0000:00:01.0: PIIX3: Enabling Passive Release
[    0.649618] pci 0000:00:01.0: Activating ISA DMA hang workarounds
[    0.751002] Trying to unpack rootfs image as initramfs...
[    1.483985] decompress cpio completed and skip redundant lzma
[    1.486048] Freeing initrd memory: 5272K
[    1.488845] audit: initializing netlink subsys (disabled)
[    1.490304] audit: type=2000 audit(1650036047.015:1): initialized
[    1.492057] Initialise system trusted keyring
[    1.532074] VFS: Disk quotas dquot_6.6.0
[    1.533302] VFS: Dquot-cache hash table entries: 512 (order 0, 4096 bytes)
[    1.535805] Key type asymmetric registered
[    1.537024] Asymmetric key parser 'x509' registered
[    1.538562] Block layer SCSI generic (bsg) driver version 0.4 loaded (major 251)
[    1.540771] io scheduler noop registered (default)
[    1.542352] pci_hotplug: PCI Hot Plug PCI Core version: 0.5
[    1.544001] pciehp: PCI Express Hot Plug Controller Driver version: 0.4
[    2.207555] Serial: 8250/16550 driver, 4 ports, IRQ sharing disabled
[    2.233864] serial8250: ttyS0 at I/O 0x3f8 (irq = 4, base_baud = 115200) is a 16550A
[    2.488605] tsc: Refined TSC clocksource calibration: 2111.995 MHz
[    2.490598] clocksource: tsc: mask: 0xffffffffffffffff max_cycles: 0x1e7173d7e16, max_idle_ns: 440795242568 ns
[    2.510016] brd: module loaded
[    2.511126] Loading iSCSI transport class v2.0-870.
[    2.527599] rdac: device handler registered
[    2.567978] rtc_cmos 00:00: RTC can wake from S4
[    2.614076] rtc_cmos 00:00: rtc core: registered rtc_cmos as rtc0
[    2.616821] rtc_cmos 00:00: alarms up to one day, y3k, 114 bytes nvram, hpet irqs
[    2.619042] i2c /dev entries driver
[    2.620273] md: raid1 personality registered for level 1
[    2.621983] NET: Registered protocol family 17
[    2.623407] Key type dns_resolver registered
[    2.682913] mce: Using 10 MCE banks
[    2.684624] registered taskstats version 1
[    2.685684] Loading compiled-in untrusted X.509 certificates
[    2.687118] Loading compiled-in X.509 certificates
[    2.688575] Loaded X.509 cert 'Synology SDG kernel module signing key: 7bd0b0d6bcd31651c22ce3978bdc8c8bdc417329'
[    2.700941] Loaded X.509 cert 'Synology Root Certification Authority: f2c075361f168425f8b5ef31b796406c3aab2089'
[    2.703502] Loaded X.509 cert 'Synology Kernel Module Signing Certification Authority: 600839b5d127e0e11d817a31'
[    2.706359] Loaded X.509 cert 'Synology kernel module signing key: 4646ce54489669338118a3b1286da156ac366fa5'
[    2.708720] page_owner is disabled
[    2.709619] AppArmor: AppArmor sha1 policy hashing enabled
[    2.712335] rtc_cmos 00:00: setting system clock to 2022-04-05 13:57:37 UTC (1649167057)
[    2.718281] Freeing unused kernel memory: 1004K
[    2.719550] Write protecting the kernel read-only data: 8192k
[    2.724195] Freeing unused kernel memory: 780K
[    2.726098] Freeing unused kernel memory: 376K
START /linuxrc.syno
START /linuxrc.syno.impl
Insert basic USB modules...
:: Loading module usb-common ... [  OK  ]
:: Loading module usbcore[    2.794331] ACPI: bus type USB registered
[    2.795665] usbcore: registered new interface driver usbfs
[    2.797163] usbcore: registered new interface driver hub
[    2.798721] usbcore: registered new interface driver ethub
[    2.800030] usbcore: registered new device driver usb
 ... [  OK  ]
:: Loading module ehci-hcd[    2.829329] ehci_hcd: USB 2.0 'Enhanced' Host Controller (EHCI) Driver
 ... [  OK  ]
:: Loading module ehci-pci[    2.842038] ehci-pci: EHCI PCI platform driver
 ... [  OK  ]
:: Loading module uhci-hcd[    2.858363] uhci_hcd: USB Universal Host Controller Interface driver
 ... [  OK  ]
:: Loading module xhci-hcd ... [  OK  ]
Insert net driver(Mindspeed only[    2.897921] kvmx64_synobios: loading out-of-tree module taints kernel.
[    2.899498] kvmx64_synobios: module license 'Synology Inc.' taints kernel.
[    2.901056] Disabling lock debugging due to kernel taint
)...
[    2.906966] synobios ioctl TCGETS /dev/ttyS1 failed
[    2.908160] synobios unable to set termios of /dev/ttyS1
[    2.909734] 2022-4-5 13:57:37 UTC
[    2.910585] synobios: load, major number 201
[    2.911590] Brand: Synology
[    2.912231] Model: VirtualDSM
[    2.913092] set group disks wakeup number to 4, spinup time deno 7
[    2.914558] synobios cpu_arch proc entry initialized
[    2.915758] synobios crypto_hw proc entry initialized
[    2.917031] synobios syno_platform proc entry initialized
Starting /usr/syno/bin/synocfgen...
/usr/syno/bin/synocfgen returns 0
[    2.936797] Module [kvmx64_synobios] is removed.
[    2.938030] synobios: unload
[    2.966061] ACPI: PCI Interrupt Link [LNKC] enabled at IRQ 11
[    2.988789] ACPI: PCI Interrupt Link [LNKD] enabled at IRQ 10
[    3.012155] ACPI: PCI Interrupt Link [LNKB] enabled at IRQ 10
[    3.096633] scsi host0: Virtio SCSI HBA
[    3.116792] scsi 0:0:0:0: Direct-Access     QEMU     QEMU HARDDISK            2.5+ PQ: 0 ANSI: 5
[    3.120051] sd 0:0:0:0: [synoboot] 20971520 512-byte logical blocks: (10.7 GB/10.0 GiB)
[    3.122834] sd 0:0:0:0: [synoboot] Write Protect is off
[    3.126104] sd 0:0:0:0: [synoboot] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
[    3.139711]  synoboot: synoboot1 synoboot2
[    3.141852] sd 0:0:0:0: [synoboot] Attached SCSI disk
[    4.630342] scsi host1: Virtio SCSI HBA
[    4.649272] scsi 1:0:0:0: Direct-Access     QEMU     QEMU HARDDISK            2.5+ PQ: 0 ANSI: 5
[    4.652311] sd 1:0:0:0: [sda] 20971520 512-byte logical blocks: (10.7 GB/10.0 GiB)
[    4.654653] sd 1:0:0:0: [sda] Write Protect is off
[    4.656765] sd 1:0:0:0: [sda] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
[    4.668950]  sda: sda1 sda2 sda3
[    4.677075] sd 1:0:0:0: [sda] Attached SCSI disk
[    6.183225] scsi host2: Virtio SCSI HBA
[    6.199259] scsi 2:0:0:0: Direct-Access     QEMU     QEMU HARDDISK            2.5+ PQ: 0 ANSI: 5
[    6.201698] sd 2:0:0:0: [sdb] 41943040 512-byte logical blocks: (21.5 GB/20.0 GiB)
[    6.203790] sd 2:0:0:0: [sdb] Write Protect is off
[    6.205676] sd 2:0:0:0: [sdb] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
[    6.217820]  sdb: sdb1
[    6.222958] sd 2:0:0:0: [sdb] Attached SCSI disk
Partition Version=0
Partition layout is not DiskStation style.
NOT EXECUTE /sbin/e2fsck.
Mou[    7.822695] EXT4-fs (sda1): couldn't mount as ext3 due to feature incompatibilities
nting /dev/sda1 /tmpRoot
[    7.830399] EXT4-fs (sda1): mounted filesystem with ordered data mode. Opts: (null)
cat: can't open '/tmp/fsck.root.log': No such file or directory
------------upgrade
Begin upgrade procedure
e2fsck 1.44.1 (24-Mar-2018)
Mount data partition: /dev/sda3 -> /[    7.886709] EXT4-fs (sda3): couldn't mount as ext3 due to feature incompatis
tmpData
[    7.891876] EXT4-fs (sda3): mounted filesystem with ordered data mode. Opts: (null)
No upgrade file exists
End upgrade procedure
============upgrade
------------bootup-smallupdate
[    8.876286] EXT4-fs (sda3): couldn't mount as ext3 due to feature incompatibilities
[    8.879729] EXT4-fs (sda3): mounted filesystem with ordered data mode. Opts: (null)
Try bootup smallupdate
chroot: can't execute '/usr/syno/sbin/synoupgrade': No such file or directory
Failed to synoupgrade --bootup-smallupdate [127]
Exit on error [6] bootup-smallupdate failed...
Tue Apr  5 13:57:43 UTC 2022
/dev/sda1 /tmpRoot ext4 rw,relatimeumount: /etc/mtab: No such file or directory
linuxrc.syno failed on 6
starting pid 4705, tty '': '/etc/rc'
:: Starting /etc/rc
:: Mounting procfs ... [  OK  ]
:: Mounting tmpfs ... [  OK  ]
:: Mounting devtmpfs ... [  OK  ]
:: Mounting devpts ... [  OK  ]
:: Mounting sysfs ... [  OK  ]
[    8.986365] random: syno_swap_ctl: uninitialized urandom read (4 bytes read, 71 bits of entropy available)
[    8.992899] Adding 3145724k swap on /dev/sda2.  Priority:-1 extents:1 across:3145724k
:: Loading module sg[    9.025481] sd 0:0:0:0: Attached scsi generic sg0 type 0
[    9.028400] sd 1:0:0:0: Attached scsi generic sg1 type 0
[    9.032161] sd 2:0:0:0: Attached scsi generic sg2 type 0
 ... [  OK  ]
:: Loading module fat ... [  OK  ]
:: Loading module vfat ... [  OK  ]
:: Loading module udp_tunnel ... [  OK  ]
:: Loading module ip6_udp_tunnel ... [  OK  ]
:: Loading module vxlan ... [  OK  ]
:: Loading module igbvf[    9.098507] igbvf: Intel(R) Gigabit Virtual Function Driver - 2.3.8.2
[    9.100810] igbvf: Copyright (c) 1999-2015 Intel Corporation.
 ... [  OK  ]
:: Loading module be2net ... [  OK  ]
:: Loading module ixgbevf[    9.120177] ixgbevf: Intel(R) 10GbE PCI Express Virtual Function Driver - version 4.5.3
[    9.122758] Copyright(c) 1999 - 2019 Intel Corporation.
 ... [  OK  ]
:: Loading module i40evf[    9.133806] i40evf: Intel(R) 40-10 Gigabit Virtual Function Network Driver - version 3.5
[    9.137133] Copyright(c) 2013 - 2018 Intel Corporation.
 ... [  OK  ]
:: Loading module sunrpc[    9.157001] RPC: Registered named UNIX socket transport module.
[    9.159098] RPC: Registered udp transport module.
[    9.160700] RPC: Registered tcp transport module.
[    9.162296] RPC: Registered tcp NFSv4.1 backchannel transport module.
 ... [  OK  ]
:: Loading module grace ... [  OK  ]
:: Loading module lockd ... [  OK  ]
:: Loading module nfs ... [  OK  ]
:: Loading module nfsv3 ... [  OK  ]
mount: mounting /dev/bus/usb on /proc/bus/usb failed: No such file or directory
ln: /proc/bus/usb/devices: No such file or directory
:: Loading module synobios[    9.223061] synobios ioctl TCGETS /dev/ttyS1 failed
[    9.224653] synobios unable to set termios of /dev/ttyS1
[    9.226659] 2022-4-5 13:57:43 UTC
[    9.227892] synobios: load, major number 201
[    9.229279] Brand: Synology
[    9.230304] Model: VirtualDSM
[    9.231480] set group disks wakeup number to 4, spinup time deno 7
[    9.233469] synobios cpu_arch proc entry initialized
[    9.235187] synobios crypto_hw proc entry initialized
[    9.237046] synobios syno_platform proc entry initialized
 ... [  OK  ]
udhcpc: started, v1.30.1
eth0      Link encap:Ethernet  HWaddr 02:11:32:2B:0F:E6
          inet addr:169.254.253.20  Bcast:169.254.255.255  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:5 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:0 (0.0 B)  TX bytes:300 (300.0 B)

lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

:: Starting syslogd ... [  OK  ]
/etc/rc: line 283: /usr/syno/bin/syno_pstore_collect: not found
:: Starting scemd
[   15.369458] exdisplay_handler not implemented
[   15.371601] exdisplay_handler not implemented
[   15.373842] exdisplay_handler not implemented
:: Starting services in background
Starting findhostd in flash_rd...
Starting services in flash_rd...
Running /usr/syno/etc/rc.d/J01httpd.sh...
Starting httpd:80 in flash_rd...
Starting httpd:5000 in flash_rd...
[   15.403472] EXT4-fs (sda1): couldn't mount as ext3 due to feature incompatibilities
Running /usr/syno/etc/rc.d/J03ssdpd.sh...
[   15.409453] EXT4-fs (sda1): mounted filesystem with ordered data mode. Opts: (null)
/usr/bin/minissdpd -i eth0
[   15.433506] EXT4-fs (sda1): couldn't mount as ext3 due to feature incompatibilities
[   15.438629] EXT4-fs (sda1): mounted filesystem with ordered data mode. Opts: (null)
[   15.448590] EXT4-fs (sda1): couldn't mount as ext3 due to feature incompatibilities
(15): upnp:rootdevice
(51): uuid:upnp_SynologyNAS-0211322b0fe6::upnp:rootdevice
(60): Synology/synology_kvmx64_virtualdsm/7.0-42218/169.254.253.20
(47): http://169.254.253.20:5000/description-eth0.xml
[   15.457840] EXT4-fs (sda1): mounted filesystem with ordered data mode. Opts: (null)
Connected.
done.
/usr/syno/bin/reg_ssdp_service 169.254.253.20 0211322b0fe6 7.0-42218 synology_kvmx64_virtualdsm eth0
Running /usr/syno/etc/rc.d/J04synoagentregisterd.sh...
Starting synoagentregisterd...
Running /usr/syno/etc/rc.d/J30DisableNCQ.sh...
Running /usr/syno/etc/rc.d/J80ADTFanControl.sh...
Running /usr/syno/etc/rc.d/J98nbnsd.sh...
Starting nbnsd...
Running /usr/syno/etc/rc.d/J99avahi.sh...
Starting Avahi mDNS/DNS-SD Daemon
[   15.536002] random: avahi-daemon: uninitialized urandom read (4 bytes read, 81 bits of entropy available)
cname_load_conf failed:/var/tmp/nginx/avahi-aliases.conf
[   15.542243] random: avahi-daemon: uninitialized urandom read (8 bytes read, 81 bits of entropy available)
Starting guest daemons in flash_rd...
/etc/rc: line 312: /usr/syno/bin/synoguestsvcd: not found
:: Loading module usb-storage[   15.567376] usbcore: registered new interface driver usb-storage
 ... [  OK  ]
:: Loading module hid ... [  OK  ]
:: Loading module usbhid[   15.585679] usbcore: registered new interface driver usbhid
[   15.587096] usbhid: USB HID core driver
 ... [  OK  ]
[   15.595206] exdisplay_handler not implemented
Excution Error
============ Date ============
Tue Apr  5 13:57:49 UTC 2022
==============================
starting pid 5879, tty '': '/sbin/getty 115200 console'

Tue Apr  5 13:57:49 2022

VirtualDSM login:

```



# 3. Partition Version？



可以看到，最早出来的一个问题是

```
Partition Version=0
Partition layout is not DiskStation style.
```



它的实现在`/linuxrc.syno.impl`

```shell
#
# check if the partition match the format
#

CheckPartition()
{
	local skipCheck=0
	local RetPartition=0
	#
	# check if the partition match the format
	#
	if [ "$NoDiskSystem" = "yes" ]; then
		skipCheck=1
		echo "Skip check partition version"
	else
		/usr/syno/bin/synocheckpartition
		RetPartition="$?"
		echo "Partition Version=$RetPartition"
	fi

	ExecFsck=1
	if [ "$skipCheck" -eq 0 ] && [ "$RetPartition" -eq 0 ]; then
		echo "Partition layout is not DiskStation style."
		echo "NOT EXECUTE $FSCK."
		ExecFsck=0
	fi

	CheckUnknownSynoPartitionMigration "$RetPartition"

}
```



它会调用synocheckpartition来检查分区表是否是已知的版本（字面意思如此）

```
LOAD:00000000006E6AE8 qword_6E6AE8    dq 42A92h, 0C02F1h, 42A92h, 3Fh, 42A92h, 83h, 42AD1h, 0C02F1h, 82h, 2 dup(0FFFFFFFFFFFFFFFFh), 83h, 0, 2
LOAD:00000000006E6AE8                 dq 4BFD77h, 0FEF01h, 3EC10h, 3Fh, 4BFD77h, 83h, 4BFDB6h, 0FEF01h, 82h, 2 dup(0FFFFFFFFFFFFFFFFh), 83h, 0, 3
LOAD:00000000006E6AE8                 dq 816A2h, 0C02F1h, 3E82h, 3Fh, 816A2h, 83h, 816E1h, 0C02F1h, 82h, 2 dup(0FFFFFFFFFFFFFFFFh), 83h, 0, 5
LOAD:00000000006E6AE8                 dq 0B07AEh, 911E5h, 3E82h, 3Fh, 0B07AEh, 83h, 0B07EDh, 911E5h, 82h, 2 dup(0FFFFFFFFFFFFFFFFh), 83h, 0, 6
LOAD:00000000006E6AE8                 dq 4BFD77h, 3FFAC5h, 3EC10h, 3Fh, 4BFD77h, 83h, 4BFDB6h, 3FFAC5h, 82h, 2 dup(0FFFFFFFFFFFFFFFFh), 83h, 0, 7
LOAD:00000000006E6AE8                 dq 4BFF00h, 400000h, 40000h, 100h, 4BFF00h, 83h, 4C0000h, 400000h, 82h, 2 dup(0FFFFFFFFFFFFFFFFh), 83h, 0, 8
LOAD:00000000006E6AE8                 dq 4BFF00h, 400000h, 3F900h, 800h, 4BFF00h, 83h, 4C0700h, 400000h, 82h, 2 dup(0FFFFFFFFFFFFFFFFh), 83h, 0, 9
LOAD:00000000006E6AE8                 dq 1000000h, 400000h, 40000h, 2000h, 1000000h, 83h, 1002000h, 400000h, 82h, 2 dup(0FFFFFFFFFFFFFFFFh), 83h, 0, 100000001h
LOAD:00000000006E6AE8                 dq 1805A3h, 0C02F1h, 42AD1h, 3Fh, 1805A3h, 0FDh, 1805E2h, 0C02F1h, 0FDh, 2 dup(0FFFFFFFFFFFFFFFFh), 0FDh, 0, 100000002h
LOAD:00000000006E6AE8                 dq 4BFD77h, 0FEF01h, 3EC10h, 3Fh, 4BFD77h, 0FDh, 4BFDB6h, 0FEF01h, 0FDh, 2 dup(0FFFFFFFFFFFFFFFFh), 0FDh, 0
```



VDSM的格式是8

```
8 dq 4BFF00h, 400000h, 3F900h, 800h, 4BFF00h, 83h, 4C0700h, 400000h, 82h, 2 dup(0FFFFFFFFFFFFFFFFh), 83h, 0
     size     size     size    start size     type start    size     type [No start/size]            type end
```

所以sda应该按照上面的数字来编排分区表

```
Device     Boot   Start     End Sectors  Size Id Type
/dev/sda1          2048 4982527 4980480  2.4G 83 Linux
/dev/sda2       4982528 9176831 4194304    2G 82 Linux swap / Solaris
```





# 4. 似乎没啥用？



虽然不知道这些分区大概在什么时候创建，但是似乎不对的话应该也没什么影响才对，一来这个程序基本上不会修改任何东西，脚本里也只是判断要不要做e2fsc。

但是还是不知道为什么我的输出和redpill的输出不一样，是不是应该进入安装过程才行？

```
install.cgi: guest_command.c:86 Failed to retrieve message from host [timeout]
install.cgi: vdsm_get_update_deadline.c:41 Failed to get vdsm update deadline.
install.cgi: The vdsm is newer than license expire time.
install.cgi: ninstaller.c:2730(ErrFHOSTDoUpgrade) err=[-1]
install.cgi: ninstaller.c:2746(ErrFHOSTDoUpgrade) retv=[-65]
install.cgi: install.c:988 Upgrade for Installation by the download patch fail.
install.cgi: install.c:1290 Upgrade by the uploaded patch fail.
install.cgi: ninstaller.c:253 umount partition /tmpData
synoagentregisterd: guest_command.c:86 Failed to retrieve message from host [timeout]
synoagentregisterd: vdsm_serial.c:84 Failed to get vdsm sn
synoagentregisterd: vdsm_serial.c:128 Failed to get vdsm sn
<last 3 messages repeated forever>
```

