# ROUND 25

- run：42072720765，全部步骤成功。
- 链接：https://github.com/Hi-prof/nl-k419/actions/runs/42072720765
- 构建提交：d4aae133f2392c80b115cbc08f688db4dd4589d0。
- 主内核：oppo-source/android_kernel_oppo_sm7250，554371aca734463e121f040efa9e5d2001603ed9。
- 配套源码：oppo-source/android_kernel_modules_and_devicetree_oppo_sm7250，ee75bb30c9cf3b297c778093511c596dfff71136。
- 两仓分支：oppo/sm7250_s_12.1_reno4_5g。
- 本地归档：ci25/kernel-419-image/；Actions 完整日志：ci25-actions.log。

改动：沿用 ROUND 24 的 RTIC BSS 布局修复；本次仅补充成功记录。

## 镜像与配置验收

- Image：ci25/kernel-419-image/ksrc/arch/arm64/boot/Image。
- 文件大小：40,062,984 字节。
- SHA-256：`018b36afb96d551338703662dd6f17426f7b7111e8c35cda9bad1b7ca89e0c38`。
- arm64 头魔数：偏移 0x38，`41 52 4d 64`。
- 头部 image_size：47,566,848 字节，包含运行时内存范围，与文件长度含义不同。
- kernel.release：`4.19.157-perf+`。
- 下列配置逐行断言通过：

```text
# CONFIG_MODULE_SIG_FORCE is not set
# CONFIG_MODVERSIONS is not set
CONFIG_MODULE_SIG=y
CONFIG_LOCALVERSION="-perf"
CONFIG_64BIT=y
CONFIG_ARM64=y
CONFIG_MODULES=y
CONFIG_TOUCHPANEL_OPLUS=y
CONFIG_DRM_MSM=y
CONFIG_SCSI_UFS_QCOM=y
CONFIG_WLAN=y
CONFIG_CNSS_UTILS=y
```

原始 config/device.config 的 SHA-256 仍为 `7C0EDB3CE6B8AE7CBF8B9C9EDCF0853F2B66FC6CD84017C18568256ED06FD760`。

## 导出与链接布局

Module.symvers 精确导出：

```text
0x00000000 kmalloc_debug_caches vmlinux EXPORT_SYMBOL
0x00000000 kmalloc_debug_enable vmlinux EXPORT_SYMBOL
```

System.map 地址：

```text
ffffff800a6b5008 __bss_start
ffffff800a6b6000 selinux_state
ffffff800a6ec5e8 kmalloc_debug_caches
ffffff800a6ec6e4 kmalloc_debug_enable
ffffff800add4968 __bss_stop
ffffff800addd000 _end
```

云端和本地均通过 `__bss_start <= selinux_state < __bss_stop <= _end` 断言。两个 kmalloc_debug 符号来自配套厂商源码实现。

## 驱动与日志复核

本地 Python 检查了配置、编译记录及 System.map 中的链接符号：

| 范围 | build.log 记录示例 | System.map 符号示例 |
| --- | --- | --- |
| 触屏 | oplus_touchscreen/Focal/ft3518/focal_drivers_ft3518.o | register_common_touch_device |
| 显示 | techpack/display/msm/dp/dp_usbpd.o | sde_encoder_is_dsi_display |
| UFS | drivers/scsi/oufs/ufs-qcom.o | ufs_qcom_probe |
| WLAN/CNSS 支撑 | drivers/net/wireless/cnss_genl/cnss_nl.o | cnss_utils_set_wlan_mac_address |

build.log（1,127,092 字节）、prepare.log（27,538 字节）、smoke.log（14,374 字节）均已下载。build.log 末尾完成 `LD vmlinux`、`SYSMAP System.map`、`OBJCOPY arch/arm64/boot/Image`。

验证命令：`gh run view 42072720765 -R Hi-prof/nl-k419 --json status,conclusion,headSha,url,jobs` 返回 success；`gh run download 42072720765 -R Hi-prof/nl-k419 -D work/kbuild/ci25` 成功；本地 `python -c $check` 的镜像、配置、导出、BSS、基线哈希、日志和驱动证据断言全部通过。

## 尚未验证的范围

基线原先启用、最终未启用的项目共 14 个：

```text
CONFIG_ARCH_SUPPORTS_SHADOW_CALL_STACK
CONFIG_CC_HAS_AUTO_VAR_INIT_PATTERN
CONFIG_CC_HAS_AUTO_VAR_INIT_ZERO
CONFIG_CC_HAS_KASAN_SW_TAGS
CONFIG_CC_HAVE_SHADOW_CALL_STACK
CONFIG_CC_IS_CLANG
CONFIG_DEBUG_INFO
CONFIG_KASAN_STACK_ENABLE
CONFIG_MODULE_SIG_ALL
CONFIG_MODULE_SIG_FORCE
CONFIG_MODVERSIONS
CONFIG_OPLUS_FEATURE_DNS_HOOK
CONFIG_OPLUS_FEATURE_STATS_CALC
CONFIG_TOUCHPANEL_ALGORITHM
```

其中包含按要求关闭的模块选项、调试与编译器能力项，以及未恢复的 DNS_HOOK、STATS_CALC、TOUCHPANEL_ALGORITHM 三个厂商选项。

未进行 boot 镜像重打包、实机启动或第三方 .ko 加载测试。版本字符串一致、配置和链接检查通过，不能据此认定运行 ABI 已兼容；WLAN/CNSS 支撑已编入，也不能据此认定设备 Wi-Fi 已通过运行验证。
