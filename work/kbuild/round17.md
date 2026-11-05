# ROUND 17

- run：42059858393（提交 6590b2b）
- 结果：失败；步骤：编译 Image。调度辅助头文件问题已消失。
- 日志：ci17/kernel-419-image/build.log。

错误原文：

```text
block/uxio_first/uxio_first_opt.c:17:10: fatal error: trace/uxio_first_opt_trace.h: No such file or directory
kernel/time/alarmtimer.c:222:2: error: implicit declaration of function ‘alarmtimer_wakeup_count’ [-Werror=implicit-function-declaration]
drivers/base/power/wakeup.c:559:2: error: implicit declaration of function ‘wakeup_get_start_time’ [-Werror=implicit-function-declaration]
drivers/base/power/wakeup.c:965:26: error: ‘IRQ_NAME_ABORT’ undeclared (first use in this function)
drivers/base/power/wakeup.c:965:42: error: ‘WS_CNT_ABORT’ undeclared (first use in this function)
```

归类：实际存在的厂商头文件未进入编译搜索路径，或其预期链接未建立。

核实：uxio_first/trace/uxio_first_opt_trace.h 存在，Makefile 未添加本目录；wakelock_profiler 中存在所有缺失声明和常量，但 OplusKernelEnvConfig.mk 中自动建链逻辑使用不匹配当前布局的 ../vendor 和 ../kernel/msm-4.19 路径，导致 Kconfig 和头文件在 prep 阶段不可见。

改动：为 UX I/O 增加 -I$(src)；在源码准备前显式链接真实 wakelock profiler 目录和头文件，使缺失引用扫描与 olddefconfig 都能正确解析。

下一轮：ROUND 18，检查 UX I/O trace、wakelock 配置与电源管理调用。
