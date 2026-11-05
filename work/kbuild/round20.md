# ROUND 20

- run：42062362441（提交 c2a82d7da5ae9d40ce2e63a7fe87e752d94d9da2）
- 结果：失败；步骤：编译 Image。enum 语法错误消失，随后发现两处显示代码旧式原型。
- 日志：ci20/kernel-419-image/build.log。

错误原文：

```text
drivers/input/oplus_fp_drivers/goodix_optical_fp/gf_spi.c:348:13: error: function declaration isn’t a prototype [-Werror=strict-prototypes]
drivers/input/oplus_fp_drivers/goodix_optical_fp/gf_spi.c:355:13: error: function declaration isn’t a prototype [-Werror=strict-prototypes]
techpack/display/msm/../oplus/oplus_display_panel.c:412:19: error: function declaration isn’t a prototype [-Werror=strict-prototypes]
techpack/display/msm/../oplus/oplus_display_panel.c:461:13: error: function declaration isn’t a prototype [-Werror=strict-prototypes]
```

归类：旧式空参数函数原型。

改动：为指纹两处、显示两处，以及 ROUND 18/19 已报告的网络功耗四处函数定义添加 void，保持函数体不变。同类原型错误已连续出现三轮，按交接兜底将 Image 构建改用 make -k 收集其余完整错误，不降低配置或成功标准。

验证：补丁应用于九个对应上游文件；工作流 YAML 解析和 diff 检查（patch 文件通过实际应用验证）。

下一轮：ROUND 21，核对八处原型错误消失，并收集其余构建/链接问题。
