/*
 * nl_forced.h —— 强制包含（-include）的补丁头，给"公开源码树不完整"擦屁股。
 *
 * 背景：oppo-source/android_kernel_oppo_sm7250 的公开分支删掉了大量厂商目录
 * （drivers/soc/oplus、include/soc/oplus、kernel/sched_assist …），但 stock 文件里
 * 被厂商改过的代码仍然引用这些头里的符号。prep_source.sh 会把指向缺失文件的
 * #include 注释掉（否则连编译都进不去），副作用就是这些符号变成未声明。
 *
 * 处理原则：只补"声明/常量/默认值"，不补行为。所有桩一律向"不改变原厂行为"的方向取值。
 */

#ifndef _NL_FORCED_H
#define _NL_FORCED_H

/* vmscan.c 的 oplus_healthinfo/swappiness_para 用了 proc_create 却忘了 include */
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/types.h>

/*
 * kernel/printk/printk.c:1799-1802（QCOM boot mode 补丁）
 *   (printk_disable_uart || get_boot_mode() == MSM_BOOT_MODE__FACTORY || ... )
 * 原头 soc/qcom/... 或 linux/msm_boot_mode.h 在公开分支里没有。
 * get_boot_mode() 返回 NORMAL(=0)，等价于"不是产线/RF/WLAN 模式"，串口日志照常输出。
 */
enum {
	MSM_BOOT_MODE__NORMAL = 0,
	MSM_BOOT_MODE__FACTORY,
	MSM_BOOT_MODE__RF,
	MSM_BOOT_MODE__WLAN,
	MSM_BOOT_MODE__POWER,
	MSM_BOOT_MODE__RECOVERY,
	MSM_BOOT_MODE__FASTBOOT,
	MSM_BOOT_MODE__CHARGE,
	MSM_BOOT_MODE__QMMI,
	MSM_BOOT_MODE__FTM,
};

static inline unsigned int get_boot_mode(void)
{
	return MSM_BOOT_MODE__NORMAL;
}

/* 定义在 nl_compat.c 里，避免每个 TU 各有一份 */
extern int printk_disable_uart;
extern int direct_vm_swappiness;

#endif /* _NL_FORCED_H */
