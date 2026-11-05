# ROUND 18

- run：42060854302（提交 cc1f51524a780ccbd91d873c997f669d6e05fa68）
- 结果：失败；步骤：编译 Image。UX I/O trace 和 wakelock 相关原错误消失。
- 日志：ci18/kernel-419-image/build.log。

错误原文：

```text
./techpack/camera/drivers/cam_sensor_module/cam_sensor_io/cam_sensor_i2c.h:12:10: fatal error: cam_cci_dev.h: No such file or directory
./include/trace/define_trace.h:89:42: fatal error: ./pll_trace.h: No such file or directory
techpack/display/msm/../oplus/oplus_display_panel.h:56:19: error: expected identifier or ‘(’ before ‘:’ token
drivers/input/oplus_fp_drivers/goodix_optical_fp/gf_spi.c:348:13: error: function declaration isn’t a prototype [-Werror=strict-prototypes]
net/oplus_nwpower/oplus_nwpower.c:184:13: error: function declaration isn’t a prototype [-Werror=strict-prototypes]
```

归类：本轮先处理实际头文件存在、Makefile 搜索目录缺失的问题。另有独立的固定底层类型 enum 语法和六处空参数原型错误，保留待分轮处理。

改动：相机传感器子树增加 cam_cci 头文件目录；显示 PLL 子目录增加 -I$(src)，满足 trace 头文件再次包含的要求。

验证：所有厂商补丁在对应上游文件上实际应用成功。

下一轮：ROUND 19，确认上述两处头文件错误消失；预计继续暴露已记录的 enum/原型错误。
