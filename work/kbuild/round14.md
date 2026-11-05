# ROUND 14

- run：42057563431（提交 93b4f821，完整 SHA 见 Actions 运行记录）
- 结果：失败；步骤：编译 Image。配套源码布局、基础驱动配置断言和 bounds.s 冒烟全部通过。
- 日志：ci14/kernel-419-image/build.log。

错误原文：

```text
arch/arm64/kernel/rootguard/oplus_guard_general.c:86:20: error: function declaration isn’t a prototype [-Werror=strict-prototypes]
   86 | static void __exit boot_state_exit()
      |                    ^~~~~~~~~~~~~~~
cc1: some warnings being treated as errors
make[2]: *** [scripts/Makefile.build:338: arch/arm64/kernel/rootguard/oplus_guard_general.o] Error 1
```

归类：厂商 C 函数使用旧式空参数声明，被明确启用的 strict-prototypes 错误检查拒绝。

改动：compat/vendor-guards.patch 将 boot_state_exit() 的声明改为 boot_state_exit(void)，在配套仓库上应用；不改变函数行为。

配置核对：相对设备基线，原已启用项的差异从 108 项降至 15 项；TOUCHPANEL_OPLUS 及多款触屏驱动、MSM 显示、UFS、WLAN、CNSS_UTILS 均恢复。15 项中包含要求关闭的模块校验选项、DEBUG_INFO、编译器能力项，以及未恢复的 DNS_HOOK、STATS_CALC、TOUCHPANEL_ALGORITHM、WAKELOCK_PROFILER。

下一轮：ROUND 15，检查是否通过 rootguard 并继续编译完整 Image。
