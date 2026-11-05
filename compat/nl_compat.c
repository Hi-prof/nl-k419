// SPDX-License-Identifier: GPL-2.0
/*
 * nl_compat.c - 补齐 OPPO 私有树导出的两个 memleak 调试符号
 *
 * 为什么需要
 * ----------
 * 目标模块（work\kbuild\c0\ColorOS-4.19.157.static.ko，name=fuck1337）的 86 个
 * 导入符号里有两个来自 OPPO 私有树：
 *
 *     kmalloc_debug_enable
 *     kmalloc_debug_caches
 *
 * 设备实测（su -c "grep kmalloc_debug /proc/kallsyms"）：
 *
 *     B kmalloc_debug_enable
 *     B kmalloc_debug_caches
 *     r __ksymtab_kmalloc_debug_enable
 *     r __ksymtab_kmalloc_debug_caches
 *
 * 两者都在 vmlinux 主体里（不在任何 .ko 里）。源码树中它们本应来自
 * mm/malloc_track，而公开分支里那是个悬空符号链接：
 *
 *     mm/malloc_track -> ../../../vendor/oplus/kernel/oplus_performance/memleak_detect/malloc_track
 *
 * 拿不到原始实现，于是用等价定义补齐。
 *
 * 类型以头文件为准
 * ----------------
 * include/linux/slab.h:314-320（锁定分支 oppo/sm7250_s_12.1_reno4_5g）：
 *
 *     #if !defined(CONFIG_SLOB)
 *     #if defined(OPLUS_FEATURE_MEMLEAK_DETECT) && defined(CONFIG_KMALLOC_DEBUG)
 *     extern atomic64_t kmalloc_debug_caches[NR_KMALLOC_TYPES][KMALLOC_SHIFT_HIGH + 1];
 *     extern int kmalloc_debug_enable;
 *     #endif
 *
 * 同文件 :554-562 的 kmalloc 内联路径是唯一已知使用者：
 *
 *     if (unlikely(kmalloc_debug_enable)) {
 *             struct kmem_cache *s;
 *             s = (struct kmem_cache *)atomic64_read(&kmalloc_debug_caches[kmalloc_type(flags)][index]);
 *             if (s)
 *                     return kmem_cache_alloc_trace(s, flags, size);
 *     }
 *
 * 与目标模块的反汇编一致：ldr w8,[enable]; cbnz w8 → ldr x0,[caches]（64 位读，
 * 元素是 atomic64_t 而非裸指针）。
 *
 * 语义
 * ----
 * enable 初值 0 = 调试关闭 = 走标准 kmalloc 路径，与设备默认状态一致。
 * 因此不实现 sysfs 读写节点（kmalloc_debug_enable_read/_write/_operations）
 * 也不影响行为——我们不需要在运行时开泄漏跟踪。
 *
 * 注意：__read_mostly 会把这两个对象放进 .data..read_mostly，不是 .bss；
 * 但它们仍是零初始化，初值语义不变。
 */

#include <linux/module.h>
#include <linux/slab.h>

atomic64_t kmalloc_debug_caches[NR_KMALLOC_TYPES][KMALLOC_SHIFT_HIGH + 1]
	__read_mostly;
EXPORT_SYMBOL(kmalloc_debug_caches);

int kmalloc_debug_enable __read_mostly;
EXPORT_SYMBOL(kmalloc_debug_enable);

/*
 * nl_forced.h 需要的两个全局量（原定义在缺失的厂商头/源里）。
 * 取值保持"原厂默认"：串口不静音、直接回收 swappiness 与全局一致(100)。
 */
int printk_disable_uart;
int direct_vm_swappiness = 100;
