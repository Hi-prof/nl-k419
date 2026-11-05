# kernel-419 — 为 OPPO PDNM00 编一个允许加载自签/未签名模块的 4.19.157 内核

设备：OPPO PDNM00（骁龙 765G / SM7250 / lito），Android 12，`uname -r = 4.19.157-perf+`，
boot 分区 `/dev/block/sde11`，已解锁 BL（`ro.boot.flash.locked=0`、`verifiedbootstate=orange`）。

## 为什么要编这个

设备内核 `CONFIG_MODULE_SIG_FORCE=y`，`/sys/module/module/parameters/sig_enforce=Y`（0444，改不动），
任何非厂商密钥签名的 `.ko` 一律 `insmod: ERROR: could not insert module: Required key not available`。
目标模块已经拿到手并改过（去掉鉴权门闩，见下游仓库），只差一个肯收它的内核。

本仓库只做一件事：用设备自己的 `/proc/config.gz` 作为基线，编出
`4.19.157-perf+` 的 `Image`，其中三项被关掉：

| 项 | 设备原值 | 这里 | 作用 |
| --- | --- | --- | --- |
| `CONFIG_MODULE_SIG_FORCE` | y | n | 不再强制签名 |
| `CONFIG_MODULE_SIG_ALL` | y | n | 不签名模块 |
| `CONFIG_MODVERSIONS` | y | n | 不校验 `.ko` 的 `__versions` 符号 CRC |

`CONFIG_LOCALVERSION` 保持 `-perf`，所以 `uname -r` 仍是 `4.19.157-perf+`。

## 仓库内容

```
.github/workflows/kernel.yml   # 一键云编译（workflow_dispatch）
compat/nl_compat.c             # 补出目标模块需要的两个 OPPO 私有符号
compat/apply_compat.sh         # 把上面的文件挂进内核树
config/device.config           # 设备 /proc/config.gz 解压出来的真实配置（168,043 字节）
```

`nl_compat.c` 补的是 `kmalloc_debug_enable` / `kmalloc_debug_caches`：目标模块的 86 个导入符号里
只有这两个不在公开分支里（`mm/malloc_track` 在公开树是悬空符号链接，指向不存在的
`vendor/oplus/.../memleak_detect/malloc_track`）。设备 `/proc/kallsyms` 实测这两个是
`B`（vmlinux 主体）且有 `__ksymtab_`，所以必须由内核本体导出，否则 insmod 报 `Unknown symbol`。

## 怎么跑

1. Actions → **kernel-419** → Run workflow（默认参数即可：上游 `oppo-source/android_kernel_oppo_sm7250`，
   分支 `oppo/sm7250_s_12.1_reno4_5g`）
2. 约 60–120 分钟（4 核）。产物 `kernel-419-image`：
   - `ksrc/arch/arm64/boot/Image` ← 要的就是它
   - `ksrc/Module.symvers`、`ksrc/.config`、`build.log`
3. 本地刷机（**未执行，等确认**）：
   ```
   magiskboot unpack boot.img            # boot.img 从设备 /dev/block/sde11 dd 出来
   cp Image kernel
   magiskboot repack boot.img new-boot.img
   fastboot flash boot new-boot.img
   ```
   注意 `veritymode=enforcing`，可能还要 `fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img`。
   刷之前必须备份 `boot` 与 `vbmeta`（原机已有 `work\kbuild\boot_backup.img`，100,663,296 字节）。

## 已知风险

- 编译器版本与厂商（clang 10.0.7）不同，理论上存在结构体对齐差异；4.19 arm64 上风险低，
  真出问题表现为模块加载后行为异常而不是加载失败。
- 编译失败常见于 gcc 太新（4.19 对 gcc-12 不友好），workflow 已优先装 gcc-10 并加 `-Wno-error`。
- 仓库是 **public**：public 仓库的 Actions 有 4 核，private 只有 2 核，编 4.19 会慢一倍以上。
  代码本身全是 GPL 上游 + 我们自己写的 shim，不含任何私有内容。
