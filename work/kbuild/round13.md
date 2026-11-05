# ROUND 13

- run：42055980673（提交 53c093f37cdf3af34904becfe3602880d1891c94）
- 结果：失败；步骤：编译 Image。头文件生成和 bounds.s 冒烟已通过，ROUND 11/12 的错误消失。
- 日志：ci13/kernel-419-image/build.log。

错误原文：

```text
kernel/sched/fair.c:7066:2: error: implicit declaration of function ‘trace_sched_cpu_sel’; did you mean ‘trace_sched_cpu_util’? [-Werror=implicit-function-declaration]
kernel/sched/fair.c:7073:4: error: implicit declaration of function ‘test_task_ux’; did you mean ‘set_task_rq’? [-Werror=implicit-function-declaration]
kernel/sched/fair.c:7075:4: error: ‘sysctl_prefer_silver’ undeclared (first use in this function)
```

归类：厂商源码缺失后被迫关闭宏，导致未受宏保护的调用仍引用厂商声明。

核实结果：OPPO 另外公开了 android_kernel_modules_and_devicetree_oppo_sm7250 仓库，存在完全同名的 oppo/sm7250_s_12.1_reno4_5g 分支，当前提交 ee75bb30c9cf3b297c778093511c596dfff71136。主内核仓库中的悬空符号链接原本指向该配套仓库的 vendor 目录；其 kernel/msm-4.19 目录还提供显示、相机和视频 techpack。此前并非这些源码均未公开，而是构建缺少配套仓库及正确目录布局。

配置对比：ROUND 11 生成配置丢掉基线中 108 个已启用项，其中包括 TOUCHPANEL_OPLUS 和多款触屏驱动，故现有剥离流程即使链接成功也不能满足基础驱动要求。

改动：本轮修正源码组装，合并配套 techpack 并恢复 kernel/msm-4.19 + vendor 布局。厂商源码就绪时保留原功能宏和调度辅助配置，使用 slub_track.c 原有的两个 kmalloc_debug_* 导出；既有缺失源码修补保留为兜底。修正 obj 扫描以保留复合对象、生成目标和预编译对象，避免误删 msm.o。

验证：使用上游真实 MSM Makefile，确认 msm.o 保留；检查生成对象、已有源文件及缺失厂商源的处理。继续运行 Shell/Python/YAML 语法检查及源码补丁应用检查。

下一轮：ROUND 14，验证配套源码布局、触屏配置和完整 Image 构建。
