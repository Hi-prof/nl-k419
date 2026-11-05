# ROUND 12

- run：42049261604（提交 2122477e27c71dae2f5e7a3dd344dac7c9b9250c）
- 结果：失败；步骤：生成头文件并冒烟编译 bounds.s。
- 日志：ci12/kernel-419-image/smoke.log。

错误原文：

```text
./include/linux/lockref.h:19:10: fatal error: generated/bounds.h: No such file or directory
   19 | #include <generated/bounds.h>
      |          ^~~~~~~~~~~~~~~~~~~~
compilation terminated.
make[2]: *** [scripts/Makefile.build:339: scripts/mod/empty.o] Error 1
```

归类：全局强制包含头文件引入构建依赖环。nl_forced.h 提前包含 proc_fs.h，经 fs.h、dcache.h、lockref.h 引用尚未生成的 bounds.h。

改动：移除三个编译命令中的全局 -include 及相关降级警告选项，保留按源码定位的 source-guards.patch；移除 nl_compat.c 中重复添加的两个全局定义，避免 direct_vm_swappiness 重复定义。原有 nl_forced.h 文件保留，但不再参与构建。

验证：Shell 语法、内嵌 Python 语法、source-guards.patch 应用检查、git diff --check。

下一轮：ROUND 13，确认 prepare 和 bounds.s 恢复通过，并读取 Image 编译的后续错误。
