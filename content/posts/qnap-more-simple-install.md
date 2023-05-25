---
title: "【番外】比《史上最简单安装QutsCloud的办法》还简单的办法"
date: 2022-04-26
categories:
- qutscloud
typora-root-url: ..\..\static
---



今天看到QutsCloud推送了新的版本，好奇之下看了一下更新历史

<!--more-->



{{< toc >}}



tg交流群：[https://t.me/qutscloud](https://t.me/qutscloud)

# 1. 原理

QuTScloud c5.0.1.1949 build 20220218的变更记录中有一条

`現在無須授權，即可使用安裝在 Virtualization Station 上的 QuTScloud。請注意，需要有授權中心 1.7.5 (或以上版本) 才可支援此功能。`

看了一下实现，是直接从脚本的结果来确定是否运行在QVS上，然后自己生成许可证对应的json

```C
int __fastcall qcloud_license_installed_special_list(lif_list_st *p_license_list, const char *app_internal_name)
{
  size_t v4; // rax
  int v5; // er12
  lif_raw_st *v6; // rdi
  char license_info_str[513]; // [rsp+0h] [rbp+0h] BYREF
  char tmp[1025]; // [rsp+210h] [rbp+210h] BYREF

  memset(tmp, 0, 0x400uLL);
  tmp[1024] = 0;
  memset(license_info_str, 0, 0x200uLL);
  license_info_str[512] = 0;
  qid_sys_get_device_type(tmp, 16LL);
  if ( strcmp(tmp, "VQTS_CLD") )
    return 0;
  util_system_cmd("/etc/init.d/get_cloud_platform.sh check_qnap | /bin/grep -E 'QCS|QVS'  2>/dev/null", tmp, 1024LL);
  if ( !tmp[0] || app_internal_name && *app_internal_name && strcmp(app_internal_name, "vqtscloud") )
    return 0;
  v4 = p_license_list->len;
  v5 = v4 - 1;
  if ( (int)v4 - 1 >= 0 )
  {
    v6 = &p_license_list->data[v5 + 1];
    do
    {
      --v5;
      memmove(v6, &v6[-1], 0x4CF8uLL);
      --v6;
    }
    while ( v5 != -1 );
    v4 = p_license_list->len;
  }
  p_license_list->len = v4 + 1;
  memset(p_license_list, 0, 0x4CF8uLL);
  *(_WORD *)p_license_list->data[0].license_id = 11565;
  qmemcpy(&p_license_list->data[0].license_info, "QuTScloud, 24+ Cores", 20);
  strcpy(p_license_list->data[0].status, "valid");
  p_license_list->data[0].legacy = 4;
  strcpy(p_license_list->data[0].license_info.app_internal_name, "vqtscloud");
  qmemcpy(p_license_list->data[0].license_info.license_name, "QuTScloud, 24+ Cores", 20);
  *(_WORD *)p_license_list->data[0].license_info.valid_from = 11565;
  *(_WORD *)p_license_list->data[0].license_info.valid_until = 11565;
  *(_WORD *)p_license_list->data[0].license_info.apply_date = 11565;
  snprintf(
    license_info_str,
    0x200uLL,
    "{\"name\": \"%s\", \"license_name\": \"%s\", \"app_internal_name\": \"%s\", \"valid_from\": \"%s\", \"valid_until\":"
    " \"%s\", \"attributes\": {\"cpu_limit\": \"0\"}}",
    p_license_list->data[0].license_info.name,
    p_license_list->data[0].license_info.license_name,
    p_license_list->data[0].license_info.app_internal_name,
    p_license_list->data[0].license_info.valid_from,
    p_license_list->data[0].license_info.valid_until);
  p_license_list->data[0].license_info.skip_check = 1;
  p_license_list->data[0].license_info_json_str = (char *)__strdup(license_info_str);
  return 0;
}
```



其中`/etc/init.d/get_cloud_platform.sh`判断是否QVS的语句

```shell
checkvnicqvs() {
    checkplatformvnicQVS="$(curl --connect-timeout 1 --max-time 1 -o /dev/null -s --insecure -w "%{http_code}" 'https://10.0.2.2/cgi-bin/sys/sysRequest.cgi')"
    [ "$1" = "-d" ] && echo "checkplatformvnicQVS:$checkplatformvnicQVS"
    echo "checkplatformvnicQVS:$checkplatformvnicQVS" >> $chkfn
}

```

很难想象这不是QNAP自己留出的口子，现在内卷这么严重了吗？



# 2. 补丁

安装后运行此脚本，安装请参考[【番外】史上最简单安装QutsCloud的办法 ]({{< ref "qnap-simple-install.md" >}})

**注意：仅支持QuTScloud c5.0.1.1949 build 20220218及之后的版本**

```
sudo curl -k https://jxcn.org/file/active2.sh | bash
```



# 3. 最后



相对[【番外】史上最简单安装QutsCloud的办法 ]({{< ref "qnap-simple-install.md" >}})更好的地方

- 这个patch只是让QutsCloud看起来像运行在QVS里面而已，所以几乎没有改动原镜像
- 可以登录QNAP ID，以及购买其他的许可证
- 因为许可证是qlicense自己生成的json，所以不会有失效的问题



但是因为所有的都是官方的东西，其他APP的许可证还是需要从官方购买，如果可以的话，尽量还是使用这个补丁，一来比较稳定，二来其他部分也能享受到官方的支持。



## 当然还有最重要的

**数据无价，请谨慎使用**

**数据无价，请谨慎使用**

**数据无价，请谨慎使用**