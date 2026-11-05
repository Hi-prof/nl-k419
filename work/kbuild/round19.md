# ROUND 19

- run：42061759985（提交 80ffa5a）
- 结果：失败；步骤：编译 Image。相机 CCI 和显示 PLL 头文件错误消失，相机子树完成归档。
- 日志：ci19/kernel-419-image/build.log。

错误原文：

```text
techpack/display/msm/../oplus/oplus_display_panel.h:56:19: error: expected identifier or ‘(’ before ‘:’ token
drivers/input/oplus_fp_drivers/goodix_optical_fp/gf_spi.c:348:13: error: function declaration isn’t a prototype [-Werror=strict-prototypes]
net/oplus_nwpower/oplus_nwpower.c:184:13: error: function declaration isn’t a prototype [-Werror=strict-prototypes]
```

归类：本轮处理 C 代码使用固定底层类型 enum 扩展、被 GCC C 模式拒绝的问题。

改动：将 enum APOLLO_BL_ID : int 改为标准 C 的 enum APOLLO_BL_ID，保留 APOLLO_BL_4096=4096 和 APOLLO_BL_8192=8192。

验证：全部六个厂商/techpack 补丁目标在对应上游文件上实际应用成功，枚举值不变。

下一轮：ROUND 20，确认 enum 错误消失；六处旧式空参数函数声明仍需单独修复。
