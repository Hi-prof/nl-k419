# ROUND 23

- run：42069146380（提交 3eeb20484b402930b0f6b39bd108b9d887129416）
- 结果：失败；步骤：编译 Image。C/汇编编译完成，失败发生于 vmlinux 链接。
- 日志：ci23/kernel-419-image/build.log。

错误原文（代表项）：

```text
fork.c:(.text+0x2924): undefined reference to `update_user_tasklist'
vmscan.c:(.text+0x5260): undefined reference to `is_reclaim_should_cancel'
logo.c:(.ref.text+0x1c): undefined reference to `logo_linux_clut224'
ufshcd.c:(.text+0x2b2c): undefined reference to `ufsf_slave_configure'
avc.c:(.text+0x1c90): relocation truncated to fit: R_AARCH64_ADR_PREL_PG_HI21 against symbol `selinux_state' defined in .bss.rtic section in security/selinux/hooks.o
```

归类：链接所需对象未进入构建；另有独立的 RTIC BSS 链接布局问题。

核实：缺失的 UFS 扩展、任务内存统计和进程回收均有真实源码。OplusKernelEnvConfig.mk 无条件添加 C 宏，但 Makefile 又依据同名 Make 变量决定对象，云编译没有 Android 产品构建传入的 yes 值。logo_linux_clut224.c 由 .ppm 生成，缺失源扫描误删其 .o，虽仍生成 .c 但未编入归档。

改动：为已确认缺对象的六个 OPLUS_FEATURE_* Make 变量设置 yes，与既有 C 宏保持一致；缺失源扫描保留由 PPM/PBM/PGM 生成的对象。全部使用真实实现，未添加 UFS 空桩。

验证：源码扫描回归检查覆盖 logo 图像输入、真实缺失源、复合对象及生成对象；工作流 YAML 和 Shell/Python 语法检查。

下一轮：ROUND 24，核对缺对象符号是否消失；随后单独修复 RTIC BSS 被放置于 STABS_DEBUG 后且位于 __bss_stop/_end 之外的问题。
