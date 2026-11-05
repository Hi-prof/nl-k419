# ROUND 24

- run：42072109893（提交 95d9fc0）
- 结果：失败；步骤：编译 Image。全部 C/汇编编译和归档完成，ROUND 23 缺符号错误均消失，链接仅剩 RTIC BSS 重定位问题。
- 日志：ci24/kernel-419-image/build.log。

错误原文：

```text
avc.c:(.text+0x1c90): relocation truncated to fit: R_AARCH64_ADR_PREL_PG_HI21 against symbol `selinux_state' defined in .bss.rtic section in security/selinux/hooks.o
hooks.c:(.text+0xb1c): relocation truncated to fit: R_AARCH64_ADR_PREL_PG_HI21 against `.bss.rtic'
hooks.c:(.text+0xb60): relocation truncated to fit: R_AARCH64_ADR_PREL_PG_HI21 against `.bss.rtic'
```

归类：厂商链接脚本布局错误。独立的 .bss.rtic 收集段位于 STABS_DEBUG/HEAD_SYMBOLS 之后，而 STABS_DEBUG 中多个段地址为 0；该段也在 __bss_stop 和 _end 之外，不能正确计入启动清零和镜像内存范围。

改动：通过 BSS_FIRST_SECTIONS 将现有 RTIC_BSS 纳入正常 BSS_SECTION，保留页对齐和 KEEP，移除结尾独立的重复 .bss 输出段。增加 System.map 地址断言，要求 __bss_start <= selinux_state < __bss_stop <= _end；同时严格核对版本、模块配置、两个导出和 arm64 Image 魔数。上传 System.map 和生成的 vmlinux.lds 便于复核。

验证：16 个补丁目标应用成功，BSS_FIRST_SECTIONS 定义位于 BSS_SECTION 展开前，独立尾段移除；工作流 YAML/Shell 和内嵌 Python 语法检查。

下一轮：ROUND 25，核对最终链接、Image 和全部验收断言。
