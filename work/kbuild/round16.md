# ROUND 16

- run：42058824213（提交 89ad262426bc7c436949fdb1d48d3cfd2557d7ff）
- 结果：失败；步骤：编译 Image。厂商补丁应用、配置和冒烟通过，rootguard 的原型错误消失。
- 日志：ci16/kernel-419-image/build.log。

错误原文：

```text
kernel/sched_assist/sched_assist_common.c:34:10: fatal error: sched_assist_trace.h: No such file or directory
make[2]: *** [scripts/Makefile.build:338: kernel/sched_assist/sched_assist_common.o] Error 1
make[1]: *** [scripts/Makefile.build:642: kernel/sched_assist] Error 2
```

归类：头文件已存在，但 Makefile 缺少搜索目录。文件位于同一厂商目录，源码通过 <sched_assist_trace.h> 引用，且文件尾的 TRACE_INCLUDE_PATH 为 .。

改动：在 sched_assist/Makefile 增加 ccflags-y += -I$(src)，让直接包含和 trace 重包含均能找到真实头文件。

验证：将厂商补丁实际应用于对应上游的两个文件，确认补丁和头文件路径匹配。

下一轮：ROUND 17，检查调度辅助对象及后续 Image 编译。
