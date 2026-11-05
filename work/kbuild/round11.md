# ROUND 11

- run：42046779758（提交 41103a7c444cfb5dbbe7b5b97dac80c39cc9741e）
- 结果：失败；步骤：编译 Image。
- 日志：ci11/kernel-419-image/build.log。

错误原文：

```text
kernel/printk/printk.c:1799:6: error: ‘printk_disable_uart’ undeclared (first use in this function); did you mean ‘printk_safe_init’?
kernel/printk/printk.c:1800:5: error: implicit declaration of function ‘get_boot_mode’; did you mean ‘getboottime’? [-Werror=implicit-function-declaration]
kernel/printk/printk.c:1800:24: error: ‘MSM_BOOT_MODE__FACTORY’ undeclared (first use in this function)
kernel/printk/printk.c:1801:24: error: ‘MSM_BOOT_MODE__RF’ undeclared (first use in this function)
kernel/printk/printk.c:1802:24: error: ‘MSM_BOOT_MODE__WLAN’ undeclared (first use in this function)
mm/vmscan.c:4672:3: error: ‘direct_vm_swappiness’ undeclared (first use in this function); did you mean ‘vm_swappiness’?
mm/vmscan.c:4692:31: error: ‘direct_vm_swappiness’ undeclared (first use in this function); did you mean ‘vm_swappiness’?
mm/vmscan.c:4719:3: error: implicit declaration of function ‘proc_create’ [-Werror=implicit-function-declaration]
```

归类：厂商宏关闭后，使用方与声明方的条件编译不一致。

改动：新增 compat/source-guards.patch，由 prep_source.sh 应用。UART 厂商过滤代码与声明共同受 OPLUS_BUG_STABILITY 控制；direct_vm_swappiness 在 HYBRIDSWAP_SWAPD 启用时也声明；vmscan.c 显式包含 proc_fs.h。保持设备配置基线不变。

下一轮：等待 ROUND 12，确认上述编译错误消失。

另一个已确认问题：第五遍 obj 扫描会把 msm-y 组成的 msm.o 当成缺失源码注释掉。下一轮单独修复，避免误删显示等复合驱动。
